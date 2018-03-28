#!/bin/bash
#
# by Felipe Ferreira 03/2018
#
if [ -z $1 ]; then
# echo "Using default, Warn 80% Crit 90% CPU usage"
 WARN=80
 CRIT=90
else
 WARN=$1
 CRIT=$2
fi

USAGE_CMD="top -b -d1 -n5|grep -i 'Cpu(s)' |tail -n 4|awk '{ sum += \$2; n++ } END { if (n > 0) print sum / n; }' |awk -F'.' '{ print \$1}'"
#echo $USAGE_CMD
USAGE=$(eval $USAGE_CMD)
MSG="CPU usage is at ${USAGE}% |CPU=$USAGE"

if [ "$USAGE" -gt "$CRIT" ]; then
 echo "CRITICAL - $MSG"
 exit 2
elif [ "$USAGE" -gt "$WARN" ]; then
 echo "WARNING - $MSG"
 exit 1
else
 echo "OK - $MSG"
 exit 0
fi
