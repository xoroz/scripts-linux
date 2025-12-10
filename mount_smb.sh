#!/bin/bash

# ===============================================
# MOUNT ISILON SHARE SCRIPT
# ===============================================
#
# DESCRIPTION:
# This script securely mounts an Isilon SMB share using CIFS mounting.
# It uses GPG encryption to store credentials locally and supports both
# Centrify (dzdo) and standard sudo for privilege escalation.
#
# PREREQUISITES:
# - gpg (for credential encryption/decryption)
# - cifs-utils (for CIFS mounting)
# - bindfs (for GVFS fallback mounting)
# - Centrify (optional - uses sudo if not available)
# - adinfo (optional - for automatic domain detection)
#
# USAGE:
# Run the script interactively. It will prompt for domain (if not detected),
# share name, and credentials (first time only). Credentials are encrypted
# with GPG and stored in ~/.cred.gpg.asc.
#
# SECURITY NOTES:
# - Credentials are encrypted with user's GPG key
# - Temporary files are securely shredded after use
# - Supports both direct CIFS and GVFS fallback mounting
#
# ===============================================

# ===============================================
# PRIVILEGE ESCALATION CHECK
# ===============================================

# Determine privilege escalation command (Centrify dzdo or sudo)
if command -v dzdo &> /dev/null; then
    PRIV_CMD="dzdo"
    echo "Using Centrify dzdo for privilege escalation."
else
    PRIV_CMD="sudo"
    echo "Centrify not found. Using sudo for privilege escalation."
fi

# ===============================================
# CONFIGURATION & DISCOVERY
# ===============================================

REMOTE_SHARE_SERVER="isilon"

# 1. Retrieve Domain dynamically using adinfo (if available)
if command -v adinfo &> /dev/null; then
    DOMAIN_NAME=$(adinfo | grep -i "Joined to domain" | awk '{print $NF}')
else
    echo "adinfo not found. This script works best with Centrify, but can proceed manually."
fi

if [ -z "$DOMAIN_NAME" ]; then
    read -p "Enter your domain name (e.g., SCINET.CMRE.NATO.INT): " DOMAIN_NAME
    if [ -z "$DOMAIN_NAME" ]; then
        echo "Error: Domain name is required."
        exit 1
    fi
fi

# 2. Construct GPG Recipient (User@Domain)
CURRENT_USER=$(whoami)
GPG_RECIPIENT="${CURRENT_USER}@${DOMAIN_NAME}"

# 3. Credential File Path
CRED_FILE_ENC="$HOME/.cred.gpg.asc"

# ===============================================
# GPG KEY CHECK (Fixes WKD Error)
# ===============================================

# Check if we already have a public key for this user locally
if ! gpg --list-keys "$GPG_RECIPIENT" > /dev/null 2>&1; then
    echo "----------------------------------------"
    echo "No local GPG key found for $GPG_RECIPIENT."
    echo "This will create a new keyring that will be reused for future mounts."
    echo "Generating new key locally to avoid WKD Network Errors..."
    echo "----------------------------------------"
    echo "NOTE: You will be prompted (GUI or Shell) to set a passphrase for this new key."
    read -p "Do you want to proceed with creating a new GPG key? (y/n): " answer
    if [[ ! $answer =~ ^[Yy]$ ]]; then
        echo "Exiting without creating key."
        exit 1
    fi

    # Generate key non-interactively but trigger Pinentry for password
    # Arguments: User-ID, Algo, Usage, Expire
    gpg --batch --quick-gen-key "$GPG_RECIPIENT" default default never

    if [ $? -ne 0 ]; then
        echo "Error: Key generation failed."
        exit 1
    fi
    echo "Key generated successfully."
fi

# ===============================================
# USER INPUT & ENCRYPTION
# ===============================================

echo "Domain:  $DOMAIN_NAME"
echo "GPG ID:  $GPG_RECIPIENT"
echo "----------------------------------------"

# Ask ONLY for the share name
read -p "Enter Share Name (e.g., myshare): " SHARE_NAME

# Construct paths
REMOTE_PATH="//${REMOTE_SHARE_SERVER}/${SHARE_NAME}"
MOUNT_POINT="$HOME/${REMOTE_SHARE_SERVER}-mnt/${SHARE_NAME}"

# Create encrypted credentials if they don't exist
if [ ! -f "$CRED_FILE_ENC" ]; then
    echo "----------------------------------------"
    echo "Credential file not found. Setup required."
    echo "Please enter SMB/AD Password for $CURRENT_USER:"

    # Read password
    read -s SMB_PASS
    echo ""

    # Create a secure temp file for formatting
    TEMP_CRED_SETUP=$(mktemp)
    chmod 600 "$TEMP_CRED_SETUP"

    # Write cifs-utils format
    echo "username=$CURRENT_USER" >> "$TEMP_CRED_SETUP"
    echo "password=$SMB_PASS"     >> "$TEMP_CRED_SETUP"
    echo "domain=$DOMAIN_NAME"    >> "$TEMP_CRED_SETUP"

    # Encrypt
    # We use --trust-model always to force trust of the key we just generated
    echo "Encrypting credentials..."
    if gpg --batch --yes --trust-model always --encrypt --recipient "$GPG_RECIPIENT" --armor --output "$CRED_FILE_ENC" "$TEMP_CRED_SETUP"; then
        echo "Credentials encrypted and saved to $CRED_FILE_ENC"
    else
        echo "Error: GPG encryption failed."
        rm -f "$TEMP_CRED_SETUP"
        exit 1
    fi

    shred -u "$TEMP_CRED_SETUP"
fi

# ===============================================
# MOUNT PROCESS
# ===============================================

if [ ! -d "$MOUNT_POINT" ]; then
    mkdir -p "$MOUNT_POINT"
fi

DECRYPTED_CRED=$(mktemp)
chmod 600 "$DECRYPTED_CRED"
trap 'rm -f "$DECRYPTED_CRED"' EXIT

echo "Decrypting credentials..."
# This will trigger the GNOME prompt or Shell prompt to unlock the key
if ! gpg --quiet --batch --decrypt "$CRED_FILE_ENC" > "$DECRYPTED_CRED" 2>/dev/null; then
    echo "Error: Failed to decrypt credentials. Did you type the wrong GPG passphrase?"
    exit 1
fi

PERF_OPTS="vers=3.1.1,cache=loose,rsize=1048576,wsize=1048576,noatime,actimeo=60"
UID_GID="uid=$(id -u),gid=$(id -g)"

echo "Mounting $REMOTE_PATH..."

if dzdo mount -t cifs "$REMOTE_PATH" "$MOUNT_POINT" -o "rw,$PERF_OPTS,$UID_GID,credentials=$DECRYPTED_CRED"; then
    echo "Success! Mounted at: $MOUNT_POINT"
else
    echo "CIFS mount failed. Attempting GVFS fallback..."
    echo "=========================================="
    echo "WARNING: GVFS FALLBACK - EXPECT SLOW PERFORMANCE!"
    echo "This method is significantly slower than direct CIFS mounting."
    echo "Consider troubleshooting the primary CIFS mount for better performance."
    echo "=========================================="
    if mount_gvfs "$SHARE_NAME"; then
        echo "GVFS fallback successful! Mounted at: $MOUNT_POINT"
    else
        echo "All mount methods failed."
        exit 1
    fi
fi

# ===============================================
# GVFS FALLBACK FUNCTION
# ===============================================

mount_gvfs() {
    local share="$1"
    local gvfs_path="/run/user/$(id -u)/gvfs/smb-share:server=${REMOTE_SHARE_SERVER},share=${share}"

    if ! command -v gio &>/dev/null; then
        echo "Error: gio not found"
        return 1
    fi

    if ! command -v bindfs &>/dev/null; then
        echo "Error: bindfs not found"
        return 1
    fi

    # GVFS mount will prompt for password
    if gio mount "smb://${REMOTE_SHARE_SERVER}/${share}"; then
        sleep 2
        if [[ -d "$gvfs_path" ]]; then
            # Bind mount using bindfs
            if bindfs -n "$gvfs_path" "$MOUNT_POINT"; then
                # Validate mount
                local file_count
                file_count=$(ls -1 "$MOUNT_POINT" 2>/dev/null | wc -l)
                if [ "$file_count" -gt 0 ]; then
                    return 0
                else
                    fusermount -u "$MOUNT_POINT" 2>/dev/null || true
                    echo "GVFS mount appears empty"
                    return 1
                fi
            fi
        fi
    fi

    echo "GVFS mount failed"
    return 1
}
