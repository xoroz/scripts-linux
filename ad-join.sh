#!/usr/bin/env bash
#
# ad-join.sh
#
# Joins a RHEL 9 host to a Windows Active Directory domain using only
# stock RHEL 9 packages (realmd, sssd, adcli, samba-common-tools,
# krb5-workstation). No third party join agents.
#
# What it does:
#   1. Reads all parameters (domain, join account, OU, groups) from a
#      .cred file instead of command line arguments. If the password is
#      not in the file, it prompts for it interactively (hidden input).
#   2. Installs the required RHEL packages if missing.
#   3. Joins the domain and places the computer object in the OU you gave.
#   4. Sets up two AD-driven account tiers:
#        AD_ADMIN_GROUP -> full sudo (root-equivalent), SSH+RDP login
#        AD_USER_GROUP  -> SSH+RDP login, sudo ONLY for dnf/yum
#                          install/update/upgrade/reinstall
#      Everyone else is denied login entirely.
#
# What it deliberately does NOT do:
#   - It does not install or configure xrdp. It only wires up the sssd
#     access control that xrdp will inherit once it exists on the box,
#     PROVIDED xrdp's PAM service file includes the system stack. See
#     the warning printed at the end of a successful run.
#
# SECURITY NOTE on AD_USER_GROUP: sudo dnf/yum install is effectively
# root-equivalent. RPM %post scriptlets run as root during install, and
# dnf accepts local .rpm file paths, not just repo packages. This is a
# deliberate convenience/security tradeoff, not an oversight. Tighten it
# with a package allowlist wrapper if that is not acceptable for your
# environment.
#
# Usage:
#   sudo ./ad-join.sh [/path/to/ad-join.cred]
#   (defaults to /etc/ad-join.cred if no path is given)
#
# See ad-join.cred.example for the credentials file format.
#
# No password ever touches argv, ps output, or shell history: it is read
# from the cred file (permission-checked) or prompted for, then piped to
# realm/kinit via stdin only, then unset before the script exits.

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
LOG_TAG="ad-join"
CRED_FILE="/etc/ad-join.cred"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

log() {
    # Plain timestamped logger. Never pass anything containing the AD
    # password into this function.
    local msg="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$LOG_TAG] $msg"
    logger -t "$LOG_TAG" "$msg" 2>/dev/null || true
}

die() {
    log "ERROR: $1"
    exit 1
}

usage() {
    cat <<EOF
Usage: sudo $SCRIPT_NAME [/path/to/ad-join.cred]

Default credentials file path: /etc/ad-join.cred
See ad-join.cred.example for the full format.

Required keys:
  AD_DOMAIN           AD domain to join, e.g. ad.example.com
  AD_JOIN_USER        AD account allowed to join computers to the domain

Optional keys:
  AD_JOIN_PASSWORD    Password for AD_JOIN_USER. If omitted, you will be
                       prompted for it (hidden input) at run time.
  AD_OU               Full DN of the target OU for the computer object
  AD_ADMIN_GROUP      AD group: SSH/RDP login + full sudo
  AD_USER_GROUP       AD group: SSH/RDP login + sudo dnf/yum install/update only
  AD_ALLOW_GROUP      AD group: SSH/RDP login only, no sudo (legacy/extra tier)

At least one of AD_ADMIN_GROUP / AD_USER_GROUP / AD_ALLOW_GROUP should be
set, or every AD user in the domain will be able to log in.

The credentials file must be owned by root:root and mode 0600, or this
script refuses to read it.
EOF
}

cleanup_secrets() {
    unset AD_JOIN_PASSWORD 2>/dev/null || true
}

require_root() {
    [ "$(id -u)" -eq 0 ] || die "This script must be run as root (sudo $SCRIPT_NAME)."
}

# ---------------------------------------------------------------------------
# Credentials file handling
# ---------------------------------------------------------------------------

load_credentials() {
    [ -f "$CRED_FILE" ] || die "Credentials file not found: $CRED_FILE"

    local perms owner
    perms="$(stat -c '%a' "$CRED_FILE")"
    owner="$(stat -c '%U:%G' "$CRED_FILE")"

    [ "$perms" = "600" ] || die "Refusing to read $CRED_FILE: must be mode 600 (found $perms). Run: chmod 600 $CRED_FILE"
    [ "$owner" = "root:root" ] || die "Refusing to read $CRED_FILE: must be owned by root:root (found $owner)."

    # shellcheck disable=SC1090
    source "$CRED_FILE"

    : "${AD_DOMAIN:?AD_DOMAIN missing from $CRED_FILE}"
    : "${AD_JOIN_USER:?AD_JOIN_USER missing from $CRED_FILE}"

    AD_OU="${AD_OU:-}"
    AD_ALLOW_GROUP="${AD_ALLOW_GROUP:-}"
    AD_ADMIN_GROUP="${AD_ADMIN_GROUP:-}"
    AD_USER_GROUP="${AD_USER_GROUP:-}"

    if [ -z "${AD_JOIN_PASSWORD:-}" ]; then
        log "AD_JOIN_PASSWORD not set in $CRED_FILE."
        if [ -t 0 ]; then
            read -r -s -p "Password for ${AD_JOIN_USER}@${AD_DOMAIN}: " AD_JOIN_PASSWORD
            echo
        else
            die "No password in $CRED_FILE and no terminal available to prompt (non-interactive run)."
        fi
        [ -n "$AD_JOIN_PASSWORD" ] || die "No password entered, aborting."
    fi

    if [ -z "$AD_ADMIN_GROUP" ] && [ -z "$AD_USER_GROUP" ] && [ -z "$AD_ALLOW_GROUP" ]; then
        log "WARNING: no AD_ADMIN_GROUP, AD_USER_GROUP or AD_ALLOW_GROUP set. Every AD user will be able to log in once joined."
    fi
}

# ---------------------------------------------------------------------------
# Packages (RHEL 9 BaseOS/AppStream only)
# ---------------------------------------------------------------------------

install_packages() {
    local pkgs=(realmd sssd sssd-ad sssd-tools adcli samba-common-tools oddjob oddjob-mkhomedir krb5-workstation authselect)
    local missing=()

    for p in "${pkgs[@]}"; do
        rpm -q "$p" >/dev/null 2>&1 || missing+=("$p")
    done

    if [ "${#missing[@]}" -gt 0 ]; then
        log "Installing required packages: ${missing[*]}"
        dnf install -y "${missing[@]}" || die "Package install failed. These packages ship in BaseOS/AppStream; check your repo config with 'dnf repolist'."
    else
        log "All required packages already installed."
    fi
}

# ---------------------------------------------------------------------------
# Sanity checks
# ---------------------------------------------------------------------------

check_time_sync() {
    if systemctl is-active --quiet chronyd; then
        log "chronyd is running, clock sync looks OK."
    else
        log "WARNING: chronyd is not active. Kerberos fails hard on clock skew over 5 minutes. Consider: systemctl enable --now chronyd"
    fi
}

already_joined() {
    realm list 2>/dev/null | grep -qi "^domain-name: ${AD_DOMAIN}$"
}

# ---------------------------------------------------------------------------
# Join
# ---------------------------------------------------------------------------

join_domain() {
    if already_joined; then
        log "Already joined to $AD_DOMAIN, skipping realm join."
        return 0
    fi

    log "Discovering domain $AD_DOMAIN..."
    realm discover "$AD_DOMAIN" >/dev/null 2>&1 || die "Could not discover $AD_DOMAIN. Check DNS (SRV records) and network reachability to a DC."

    local join_args=(-v -U "$AD_JOIN_USER")
    if [ -n "$AD_OU" ]; then
        join_args+=(--computer-ou="$AD_OU")
    fi
    join_args+=("$AD_DOMAIN")

    log "Joining $AD_DOMAIN as $AD_JOIN_USER (password piped via stdin, never on argv)..."
    if ! printf '%s' "$AD_JOIN_PASSWORD" | realm join "${join_args[@]}"; then
        die "realm join failed. Check the join account's permissions, the OU path, and DNS/time sync."
    fi

    log "Joined $AD_DOMAIN successfully."
}

# ---------------------------------------------------------------------------
# PAM / authselect
# ---------------------------------------------------------------------------

configure_authselect() {
    log "Making sure authselect profile is sssd with mkhomedir enabled..."
    authselect select sssd with-mkhomedir --force >/dev/null
}

# ---------------------------------------------------------------------------
# Short (non fully-qualified) names, needed for clean %group sudoers rules
# ---------------------------------------------------------------------------

set_short_names() {
    local conf="/etc/sssd/sssd.conf"
    local section="[domain/${AD_DOMAIN}]"

    [ -f "$conf" ] || die "$conf not found, did the join actually run?"

    log "Setting use_fully_qualified_names = False (single AD domain assumption; flip this back if you add a trusted second domain)."

    if grep -q "^use_fully_qualified_names" "$conf"; then
        sed -i "s/^use_fully_qualified_names.*/use_fully_qualified_names = False/" "$conf"
    else
        awk -v section="$section" -v line="use_fully_qualified_names = False" '
            { print }
            $0 == section { print line }
        ' "$conf" > "${conf}.tmp" && mv "${conf}.tmp" "$conf"
    fi
    chown root:root "$conf"
    chmod 600 "$conf"
}

# ---------------------------------------------------------------------------
# Access restriction: only permitted AD groups may log in at all
# ---------------------------------------------------------------------------

restrict_access() {
    local groups=()
    [ -n "$AD_ADMIN_GROUP" ] && groups+=("$AD_ADMIN_GROUP")
    [ -n "$AD_USER_GROUP" ] && groups+=("$AD_USER_GROUP")
    [ -n "$AD_ALLOW_GROUP" ] && groups+=("$AD_ALLOW_GROUP")

    if [ "${#groups[@]}" -eq 0 ]; then
        log "No login groups configured, leaving default AD login policy in place (every AD user can log in)."
        return 0
    fi

    log "Restricting interactive login (SSH/RDP/console/su) to AD groups: ${groups[*]}"
    realm permit -g "${groups[@]}" || die "realm permit failed. Do these groups exist in AD: ${groups[*]}?"
}

# ---------------------------------------------------------------------------
# sudo tiers
# ---------------------------------------------------------------------------

write_sudoers_dropin() {
    local path="$1" content="$2" tmp
    tmp="$(mktemp)"
    printf '%s\n' "$content" > "$tmp"
    chmod 440 "$tmp"
    if ! visudo -cf "$tmp" >/dev/null; then
        rm -f "$tmp"
        die "Generated sudoers rule failed validation, aborting before touching $path. Rule was: $content"
    fi
    install -m 440 -o root -g root "$tmp" "$path"
    rm -f "$tmp"
}

sudoers_escape_group() {
    # sudoers group names cannot be double-quoted (tested against real
    # visudo: %"Group Name" is rejected as "empty group"). Spaces must be
    # backslash-escaped instead: %Group\ Name
    local name="$1"
    printf '%s' "${name// /\\ }"
}

configure_admin_sudo() {
    if [ -z "$AD_ADMIN_GROUP" ]; then
        log "No AD_ADMIN_GROUP set, skipping full-sudo tier."
        return 0
    fi
    log "Granting full sudo to AD group: $AD_ADMIN_GROUP"
    local escaped
    escaped="$(sudoers_escape_group "$AD_ADMIN_GROUP")"
    write_sudoers_dropin "/etc/sudoers.d/ad-admins" "%${escaped} ALL=(ALL) ALL"
}

configure_user_sudo() {
    if [ -z "$AD_USER_GROUP" ]; then
        log "No AD_USER_GROUP set, skipping package-management sudo tier."
        return 0
    fi
    log "Granting dnf/yum install-update-only sudo to AD group: $AD_USER_GROUP"
    local escaped rule
    escaped="$(sudoers_escape_group "$AD_USER_GROUP")"
    rule="%${escaped} ALL=(root) /usr/bin/dnf install *, /usr/bin/dnf update *, /usr/bin/dnf upgrade *, /usr/bin/dnf reinstall *, /usr/bin/yum install *, /usr/bin/yum update *, /usr/bin/yum upgrade *, /usr/bin/yum reinstall *"
    write_sudoers_dropin "/etc/sudoers.d/ad-users" "$rule"
}

# ---------------------------------------------------------------------------
# Wrap up
# ---------------------------------------------------------------------------

finalize() {
    log "Restarting sssd to apply configuration..."
    systemctl restart sssd

    log "Enabling sssd and realmd on boot..."
    systemctl enable sssd realmd >/dev/null 2>&1 || true

    log "Current realm status:"
    realm list
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main() {
    require_root
    load_credentials
    install_packages
    check_time_sync
    join_domain
    configure_authselect
    set_short_names
    restrict_access
    finalize
    configure_admin_sudo
    configure_user_sudo

    log "Done."
    [ -n "$AD_ADMIN_GROUP" ] && log "Tier: $AD_ADMIN_GROUP -> full sudo (root-equivalent)."
    [ -n "$AD_USER_GROUP" ] && log "Tier: $AD_USER_GROUP -> sudo dnf/yum install/update/upgrade/reinstall only. Note: this is soft-root, see header comment."
    [ -n "$AD_ALLOW_GROUP" ] && log "Tier: $AD_ALLOW_GROUP -> login only, no sudo."
    log "Local Unix accounts (root, service accounts, etc.) are unaffected by any of the above, this only gates AD identities."
    log "IMPORTANT: if you run xrdp on this box, check /etc/pam.d/xrdp-sesman actually includes the system-auth/postlogin stack. Some xrdp packages ship a minimal PAM file that bypasses sssd's access check entirely."
    log "If a fresh sudo group rule does not seem to apply right away, try: sss_cache -g <group name>"
    log "Test with: id someuser (no @domain needed now) and a real SSH login as a member of each tier."
}

case "${1:-}" in
    -h|--help)
        usage
        exit 0
        ;;
    "")
        ;;
    *)
        CRED_FILE="$1"
        ;;
esac

trap cleanup_secrets EXIT

main
