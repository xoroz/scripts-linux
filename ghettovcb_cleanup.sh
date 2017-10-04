#!/bin/sh
# script to clean up after backup ghetto, kill process and remove any snapshots leftover
#Felipe Ferreira 10/2017

echo ".Killing script left over processes"
for i in $(ps -c |grep ghettoVCB.sh |grep -v grep |awk '{ print $1 }'); do kill -9 $i ; done
#remove temp
rm -rfv  /tmp/ghettoVCB.work

C=$(find /vmfs/volumes/ -iname "*delta.vmdk"|wc -l)
echo ".Found $C snapshots"
if [ $C -ne 0 ]; then
 IDS=$(for i in $(find /vmfs/volumes/ -iname "*delta.vmdk" |awk -F"/" '{ print $NF }' |awk -F"-" '{ print $1 }'); do vim-cmd vmsvc/getallvms |grep $i |awk '{ print $1 }' ; done)
 echo $IDS
 if [ -z "$IDS" ]; then
  echo ".Removing left over snapshots"

  for ID in $IDS; do
   vim-cmd vmsvc/snapshot.removeall $ID
  done
 fi
fi
