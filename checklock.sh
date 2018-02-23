#!/bin/bash
#
# Check if any files are locked by either Samba or Vsftpd
# Felipe Ferreira 02/18

# Could also use lsof for CODE: 44uW
RE=0

function checkp() {
 proc=$1
 for p in $(/sbin/pidof $proc);
 do
  R=$(lsof -p $p |egrep '7wW|44uW')
  if [ ! -z "$R" ]; then
   F=$(echo "$R"|awk '{ print $NF }')
   echo $proc " - " $F
   RE=2
  fi
 done
}

checkp vsftpd
checkp smbd

exit $RE
