#!/bin/bash
#
# ## Plugin for Nagios to monitor directory size
# ## Written by Gerd Stammwitz (http://www.enbiz.de/)
# ##
# ## - 20040727 coded and tested for Solaris and Linux
# ## - 20041216 published on NagiosExchange
# ## - 20070710 modified by Jose Vicente Mondejar to add perfdata option
# ## - 20130707 modified by Felipe Ferreira to count number of files in directory
#
#
# ## You are free to use this script under the terms of the Gnu Public License.
# ## No guarantee - use at your own risc.
#
#
# Usage: ./check_dirsize -d <path> -w <warn> -c <crit>
#
# ## Description:
#
# This plugin determines the number of files inside a a directory (including sub dirs)
# and compares it with the supplied thresholds.

#PATH=""

LS="/bin/ls"
CUT="/usr/bin/cut"
WC="/usr/bin/wc"
GREP="/bin/grep"
FIND="/usr/bin/find"

PROGNAME=$0
PROGPATH=$(echo $0 | /bin/sed -e 's,[\\/][^\\/][^\\/]*$,,')
REVISION="Revision 1.1"
AUTHOR="(c) 2004,2007 Gerd Stammwitz (http://www.enbiz.de/) - Edited by Felipe Ferreira(2013)"

# Exit codes
STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3
STATE_DEPENDENT=4

print_revision() {
    echo "$REVISION $AUTHOR"
}

print_usage() {
    echo "Usage: $PROGNAME -d|--dirname <path> [-w|--warning <warn>] [-c|--critical <crit>] [-f|--perfdata]"
    echo "Usage: $PROGNAME -h|--help"
    echo "Usage: $PROGNAME -V|--version"
    echo ""
    echo "<warn> and <crit> must be expressed in KB"
}

print_help() {
    print_revision $PROGNAME $REVISION
    echo ""
    echo "Directory size monitor plugin for Nagios"
    echo ""
    print_usage
    echo ""
}

# Make sure the correct number of command line
# arguments have been supplied

if [ $# -lt 1 ]; then
    print_usage
    exit $STATE_UNKNOWN
fi

# Grab the command line arguments

thresh_warn=""
thresh_crit=""
perfdata=0
exitstatus=$STATE_WARNING #default
while test -n "$1"; do
    case "$1" in
        --help)
            print_help
            exit $STATE_OK
            ;;
        -h)
            print_help
            exit $STATE_OK
            ;;
        --version)
            print_revision $PROGNAME $VERSION
            exit $STATE_OK
            ;;
        -V)
            print_revision $PROGNAME $VERSION
            exit $STATE_OK
            ;;
        --dirname)
            dirpath=$2
            shift
            ;;
        -d)
            dirpath=$2
            shift
            ;;
        --warning)
            thresh_warn=$2
            shift
            ;;
        -w)
            thresh_warn=$2
            shift
            ;;
        --critical)
            thresh_crit=$2
            shift
            ;;
        -c)
            thresh_crit=$2
            shift
            ;;
        -f)
            perfdata=1
            ;;
        -perfdata)
            perfdata=1
            ;;
        *)
            echo "Unknown argument: $1"
            print_usage
            exit $STATE_UNKNOWN
            ;;
    esac
    shift
done

##### Get size of specified directory

# Path exists? 
if [ ! -d $dirpath ]; then
    echo "Directory '$dirpath' does not exist!"
    exit $STATE_CRITICAL
fi

# Should generally be run as root to avoid "Permission denied" errors.
# Nagios is not able to see the error messages whether std is redirected or not as wc is catching the output.
# Helping the user diagnose the problem in Nagios itself is done below on checking the return code.
# stderr is redirected here to not get duplicate output when manually running the script.
dirsize=$($FIND $dirpath -type f 2>&1 | $WC -l ; exit "${PIPESTATUS[0]}")
returnCode=$?

if [ $returnCode != 0 ]; then
	# For the user to be able to see the error message in Nagios, this needs to be printed out
	# on stdout (which is piped to wc before). Therefore, we repeat find here (without wc) to hopefully
	# get the same error as before. stdout is ignored, afterwards stderr is redirected to stdout, so
	# only the error messages are printed out.
	error=$($FIND $dirpath -type f 2>&1 >/dev/null)
	echo "Error: find failed with \"$error\""
	exit $STATE_UNKNOWN
fi

result="OK"
exitstatus=$STATE_OK

##### Compare with thresholds

if [ "$thresh_warn" != "" ]; then
    if [ $dirsize -ge $thresh_warn ]; then
        result="WARNING"
        exitstatus=$STATE_WARNING
    fi
fi
if [ "$thresh_crit" != "" ]; then
    if [ $dirsize -ge $thresh_crit ]; then
        result="CRITICAL"
        exitstatus=$STATE_CRITICAL
    fi
fi
if [ $perfdata -eq 1 ]; then
    result="$result - There are $dirsize files in dir $dirpath|'size'=${dirsize};${thresh_warn};${thresh_crit}"
    echo $result
    exit $exitstatus
fi

echo "$result - There are $dirsize files in dir $dirpath"
exit $exitstatus
