#!/bin/bash
#
# Script to monitor and block IPs spaming in varios ways my WPress and SQUID installation

# Felipe Ferreira
# Update 07/2016
# tested on Centos/RedHat/LinuxAMI and lighttpd/squid with iptables

#PREREQ
# ipset
# iptables


DEBUG=0                             # 1 for verbose, 0 for quite
CRIT=20                             #Number of entries before it adds to iptables DENY rule
CRIT_SQUID=4                        #Same As Above
RST=0                               #RESTART webserver = 1 or not = 0
WHITELIST="/usr/bin/whitelist.txt"  #IPs to never add into blacklist/block


dia=$(date +%d)
mesd=$(date +%m)
ano=$(date +%Y)
hora=$(date +%H)

tday="$ano-$mesd-$dia $hora"


####################################### FUNCTION #################
function pt()
{
 if [ "$DEBUG" -eq "1" ]; then
  echo "$1"
 fi
}

function blockip()
{
 IP=$1

#check if ipset list blacklist exists or not, if not present creates it and add to iptables
 if [[ $(/usr/sbin/ipset list -n |grep -c blacklist) = 0 ]]; then
  pt "ERRO - ipset blacklist not found"
  if [ -f /etc/ipset.conf ]; then
   /usr/sbin/ipset restore < /etc/ipset.conf
  fi
  /usr/sbin/ipset create blacklist hash:ip hashsize 4096
  if [[ $(grep -c blacklist /etc/sysconfig/iptables) = 0 ]]; then
   /sbin/iptables -I INPUT -m set --match-set blacklist src -j DROP
   /sbin/iptables-save > /etc/sysconfig/iptables
  fi
 fi

 if [[ $(grep -c "$IP" "$WHITELIST") = 0 ]] && [[ $(/usr/sbin/ipset list blacklist |grep -c "$IP") = 0 ]]; then
   echo "----------------------------------------------------------"
   date
   echo "OK - $IP has been blocked"
   /usr/sbin/ipset add blacklist $IP
   /usr/sbin/ipset save > /etc/ipset.conf
  if [ "$RST" -eq "1" ]; then
   service $WEBSRV stop
   sleep 20
   service $WEBSRV start
  fi
 else
  echo "UNKOWN - $IP already in the blacklist or in whitelist: $WHITELIST"
 fi
}

function checkfile() {
 if [ ! -f $1 ]; then
  return 1
 elif [[ $(/usr/bin/du -k $1| cut -f 1) < 2 ]]; then
  return 1
 else
  return 0
 fi
}

function check_lighttpd_error()
{
#Must have lighttpd and mod_evasive enabled it will then log to error.log
 L=$1
 if checkfile $L ; then L=$1; else pt "$L has no data or not found" && return 0; fi

 IPS=$(grep "$tday" $L |grep "Too many connections" |awk -F")" '{ print $NF}' |awk '{ print $1 }' |sort -rn |uniq  |head -n 5)
 if [ -z "$IPS" ]; then
  return
 fi
 for IP in $IPS;
 do
#Check how many times it happened
   CI=$(grep "$tday" $L |grep "Too many connections"|grep -c "$IP")
  if [ "$CI" -gt "$CRIT" ]; then
   echo "$L - Found $CI many connections, Blocking IP: $IP more then $CRIT found on $tday"
   blockip $IP
  fi
 done
}

function check_lighttpd_access()
{
 L=$1
 if checkfile $L ; then L=$1; else pt "$L has no data or not found" && return 0; fi

 IP=$( tail -n 1000 $L |grep "/wp-login.php" |grep POST |grep "wp-login.php " |awk '{ print $1 }' |sort -rn |uniq -c  |sort -rn |head -n 1)
 if [ ! -z "$IP" ]; then
  IPT=$(pt "$IP" |awk '{ print $1 }')
  IPA=$(pt "$IP" |awk '{ print $NF }')
 else
  return
 fi

 if [ "$IPT" -gt "$CRIT" ]; then
  echo "$L - Tried $IPA $IPT ( $CRIT ) Blocking $IPA"
  blockip $IPA
 fi
}

function check_squid()
{
 L=$1
 if checkfile $L ; then L=$1; else pt "$L has no data or not found" && return 0; fi
 IPS=$(egrep 'NONE\/400|TCP_DENIED\/407' $L |awk '{ print $3 }' |sort -rn |uniq -c |sort -rn |head -n 5 | awk '{ print $NF }')
 for IP in $IPS;
 do
  IPC=$(egrep 'NONE\/400|TCP_DENIED\/407' $L|grep -c $IP )
  if [ "$IPC" -gt "$CRIT_SQUID" ]; then
   echo "$L - $IP found $IPC  more then $CRIT_SQUID "
   blockip $IP
  else
    pt "$L - Not blocking $IP found only: $IPC"
  fi
 done
}


################################################################## MAIN

check_squid /var/log/squid/access.log
check_lighttpd_error /var/log/lighttpd/error.log
check_lighttpd_access /var/log/lighttpd/felipeferreira_access.log
exit 0
