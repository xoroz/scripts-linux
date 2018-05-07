#!/bin/bash

# Script to autoget a reporting as an CSV and send out via email
# By Felipe Ferreira
# 02/2017

# REQ: (curl)
# 1. Have an auto login authenticated URL
# centreon>Configuration>User>Centreon Authentication> Autologin Key (GENERATE)
# login with the user and right click and save link ,  on the OpenLock (top right)
# copy and paste to the variable AUTOLOGINURL

# 2. Know the ID of your Service Group or Host Group you want the report for, you can get by doing
#centreon -u admin -p PASSW -o SG -a show
#edit the ID variable


####### EDIT HERE ########
D=5
ID=49
IDNAME=$(/usr/bin/centreon -u reporting -p autoreport -o SG -a show |grep $ID|awk -F";" '{ print $NF}')
AUTOLOGINURL="https://centreon/centreon/index.php?p=30704&autologin=1&useralias=reporting&token=Awhb12312gFwUo"


MAILTO="felipe.ferreira@de.it"
###### DONE EDIT #########

CSVFILE="/tmp/report_${IDNAME}.csv"
COOKIE="/tmp/.cookie-jar.txt"

NOW=$(date +"%b %d")
CMDTE="date -d \"$NOW - 1 days \" +%s"
CMDTS="date -d \"$NOW - $D days\" +%s"
DSTART=$(eval $CMDTS)
DEND=$(eval $CMDTE)

D1=$(date -d@${DSTART})
D2=$(date -d@${DEND})
echo "START: $DSTART: $D1 END: $DEND : $D2"

#GET PHP COOKIE SESSIONID
curl -s --cookie-jar $COOKIE "$AUTOLOGINURL" > /dev/null
SESSIONID=$(tail -n1 $COOKIE  |awk '{ print $NF}')

URL="https://centreon/centreon/include/reporting/dashboard/csvExport/csv_ServiceGroupLogs.php?servicegroup=${ID}&start=${DSTART}&end=${DEND}"

######## DEBUG
#echo "SESSIONID $SESSIONID"
#echo "URL: $URL"
#echo "CSVFILE $CSVFILE"
#echo "COOKIEJAR $COOKIE"

if [ ! -z $SESSIONID ]; then
 #TEMP FIX FOR UNDETERMINED PROBLEM
#su -l centreon -c "/usr/share/centreon/cron/dashboardBuilder -r –config=/etc/centreon/conf.pm"
curl -s "$URL"  -H "Host: centreon.datamanagement.it" -H "User-Agent: Reporting" -H "Accept: text/html,application/xhtml+xml" -H "Accept-Language: en,it-IT" --compressed -H "Referer: https://centreon.datamanagement.it/centreon/main.php?p=30704" -H "Cookie: PHPSESSID=$SESSIONID" -H "DNT: 1" -H "Connection: keep-alive" -H "Upgrade-Insecure-Requests: 1" > $CSVFILE
else
 echo "ERROR - Could not get the SESSIONID $SESSIONID, check your $AUTOLOGINURL"
 exit 2
fi

if [ -f "$CSVFILE" ]; then
 SUBJ="Centreon Report $IDNAME last $D days"
 MSG="Centreon Report $IDNAME from $D1 to $D2 for ServiceGroup ID $ID and Download URL: $URL"
 echo "$MSG" | mail -a $CSVFILE -s "$SUBJ" "$EMAILTO"
 rm -f $COOKIE $CSVFILE
 echo -e "OK - REPORT FOR $IDNAME FOR LAST $D DAYS\nEMAIL SENT TO $EMAILTO Ref: http://wiki/doku.php?id=cliente:mix:infra:gepe-suite-web"
 echo DONE
 exit 0
else
 echo "ERROR - Could not find $CSVFILE"
 exit 2
fi
