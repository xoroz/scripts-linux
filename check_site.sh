#!/bin/bash
#Felipe Ferreira set 2013
#rev. 08/2016 - add better output and sed to change , to . on timeto
#rev. 03/2017 - adaptaed to be used as an IPS

#PRE-REQ:
#this version requires ipset and precreated iptables rules
#originaly it workes with lighttpd, but can easly be change for apache or nginx

#1) ipset create blacklist hash:ip hashsize 4096
#2) iptables -I INPUT -m set --match-set blacklist src -j DROP

URL=$1
KEY=$2
CRIT=$3

SITE=$(echo "$URL"|awk -F"/" '{ print $3}')

### EDIT HERE ###
EMAILTO="fel@mai.com"
EMAILFROM="felipe@mail.net"
TMPN="/tmp/ntstat.tmp"
MAXCON=6
MAXTIMEOUT=$CRIT
WEBSRV="lighttpd"
LOG="/var/log/${WEBSRV}/check_badguy.log"
#DEBUG=0

### EDIT END ###

if [ -z $CRIT ]; then
   echo "Usage $0 <URL> <KEYWORD> <TIMEOUT>"
   exit 3
fi

function blockip()
{
 IP=$1
 if [[ $(ipset list blacklist |grep -c "$IP") = 0 ]]; then
   ipset add blacklist $IP |tee -a $LOG
   service $WEBSRV stop |tee -a $LOG
   sleep 20
   service $WEBSRV start |tee -a $LOG
 else
   echo "$IP already in the blacklist" |tee -a $LOG
 fi
}

function down() {
  echo -e "\n\n---------------------------------------------------------------------"|tee -a $LOG
  date  |tee -a $LOG
  echo "CRITICAL - Site took to longer then $CRIT to respond, $MSGOK"  |tee -a $LOG
  netstat -nta |grep WAIT |grep ":80"  |grep -v "127.0.0.1" |awk '{ print $5 }' |awk -F":" '{ print $1}' > $TMPN
  echo "NETSTAT RESULT IPs WAIT CONNECTION:"
  cat $TMPN |tee -a $LOG
  CT=$(wc -l $TMPN|awk '{ print $1}')
  echo "WAIT CONNECTIONS: $CT" |tee -a $LOG

  if [ "$CT" -gt "$MAXCON" ]; then
   IP=$(cat $TMPN |sort |uniq -c |sort -rn |head -n 1 |awk '{print $NF}')
  if [ $IP ]; then
   MSG="Blocking IP $IP"
   blockip $IP
  fi
 else
   MSG="Not maxcon $MAXCON only $CT"
 fi
 echo $MSG |tee -a $LOG
 echo -e "SITE DOWN $SITE \n $MSG" |/bin/mail -s "Site $SITE restarted" -a $LOG -r "$EMAILFROM" "$EMAILTO"
 exit 2
}

### MAIN ###

TC=`echo ${URL} | awk -F. '{print \$1}' |awk -F/ '{print \$NF}'`
R=$(echo $((1 + RANDOM % 1000)))
TMP="/tmp/check_http_sh_${R}_${TC}.tmp"
touch $TMP

CMD_TIME="curl -m $MAXTIMEOUT -k --location --no-buffer --silent --output ${TMP} -w %{time_connect}:%{time_starttransfer}:%{time_total} '${URL}'"

#echo $CMD_TIME
TIME=$(eval $CMD_TIME)
#echo "Done CMD"
if [ -f $TMP ]; then
   RESULT=`grep -c $KEY $TMP`
   TIMETOT=`echo $TIME | gawk  -F: '{ print \$3 }' |sed 's/,/./g'`
else
   echo "ERROR - Could not create tmp file $TMP" |tee -a $LOG
   echo $TIME |tee -a $LOG
   down
fi

### DEBUG ONLY ###
if [ ! -z $DEBUG ]; then
 echo "CMD_TIME: $CMD_TIME"
 echo "NUMBER OF $KEY FOUNDS:  $RESULT"
 echo "TIMES: $TIME"
 echo "TIME TOTAL: $TIMETOT"
 echo "TMP: $TMP"
 ls $TMP
fi

rm -f $TMP

SURL=`echo $URL | cut -d "/" -f3-4`

MSGOK="Site $SURL key $KEY time $TIMETOT |'time'=${TIMETOT}s;${CRIT}"
MSGKO="Site $SURL has problems, time $TIMETOT |'time'=${TIMETOT}s;${CRIT}"

#PERFDATA HOWTO 'label'=value[UOM];[warn];[crit];[min];[max]

#CHECK IF KEYWORD IS FOUND
if [[ "$RESULT" -lt "1" ]]; then
 down
fi

#CHECK IF TIME IS OK
if [[ $(echo "$TIMETOT < $CRIT"|bc) = 1 ]]; then
   exit 0
else
 down
fi
