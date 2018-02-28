#!/bin/bash
#
# Felipe Ferreira 02/2018
# check if mount bind for chroot SFTP is configured correctly
#
#this can be used along with my chroot technique of using mount bind 
#its is not very generic but may help someone someday :) cheers

#MOUNT_COUNT=12  # total mounts to expect

MOUNT_COUNT=$(ls -l /sftp/ |wc -l)
MOUNT_COUNT=$(expr $MOUNT_COUNT - 1 )

FILES_COUNT=$(find /sftp/ -type f  |wc -l)

MOUNTED=$(mount -l |grep sftp |awk '{print $3}' |sort  |uniq )
MOUNTED_COUNT=$(echo "$MOUNTED" | wc -l)

#make sure each directory has at least some folder in it

for DIR in $MOUNTED;
do
 DIR_COUNT=$(ls -laht $DIR |wc -l)
# echo "DEBUG: $DIR $DIR_COUNT"
 if [ $DIR_COUNT -lt 5 ]; then
    MSG="CRITICAL - mountpoint $DIR has only $DIR_COUNT folders."
# SHOULD REMOUNT ONLY THE BAD ONE HERE
    umount -f $DIR
    /bin/setMountBind.sh
    RC=3
    break
 fi
done

if [ "$MOUNTED_COUNT" -ne "$MOUNT_COUNT" ]; then
    MSG="CRITICAL - missing a mountpoint, running script to remount."
    /bin/setMountBind.sh
    RC=3
  else
    MSG="OK - all (${MOUNTED_COUNT}/${MOUNT_COUNT})  are mounted and $FILES_COUNT files founded | files_found=$FILES_COUNT"
    RC=0
fi

echo $MSG
exit $RC
