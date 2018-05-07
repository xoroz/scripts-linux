#!/bin/bash
#
# Felipe Ferreira Jan 2017
#utenti e gruppi definiti nel sudoers
#getid
#lastlogin
#can be used to get from all computers in the network with autoconnect

#TODO:
#clean up output

#BUG
#1- Missing cmd last YEAR information
## Possible fix: 1-check /var/log/secure

#echo "HOST ; USER ; ID ; TIPO ; LASTLOGIN"
HOST=$(hostname |awk -F"." '{ print $1 }')
LAST=""
L=""
ITEM=""
ID=""
TIPO=""

########
DEBUG=0
TMPD="/tmp/logsecure/"
TMPF=${TMPD}tmpfile.log
#######

################################ FUNCTIONS #######################
function pt() {
if [ $DEBUG -eq 1 ]; then
 echo "$1"
fi
}

function getloginsshfiles() {
#Get last login based on /var/log/secure
[[ ! -d  $TMPD ]] && mkdir -p $TMPD
for FILE in /var/log/secure*; do
 pt "FILE $FILE"
 FILEN=$(echo "$FILE" | awk -F"/" '{ print $NF}')
 /bin/cp -f $FILE $TMPD
 /bin/rm -f $TMPF

 if [[ $( echo $FILEN|grep -c -i ".gz") = 1 ]]; then
  cd $TMPD && gunzip -fqd $FILEN
  FILEN=$(echo $FILEN|awk -F"." '{ print $1}')
 fi
done
#JOIN ALL FILES INTO ONE
cat ${TMPD}secure* >> $TMPF
}

function getloginssh() {
 ITEM=$1
 if [ -f $TMPF ]; then
 L=$(grep $ITEM $TMPF |grep "session opened" |tail -n1 |awk '{ print $1,$2,$3}')
 if [[ ! -z $L ]]; then
#RECHECK IF THERE IS VALIDE DATE
  L=$(date -d"$L" +"%d/%m %H:%M")
   pt "LOGINSSH: $ITEM $L"
 fi
 else
  L=""
 fi
}

function getlastlogin() {
 LAST=""
 ITEM=$1
 if [[ ! -z $ITEM ]]; then
 LAST=$(last -n 1 $ITEM |head -n1 |awk '{print $4,$5,$6,$7}' )
#when last has more info it changes
  if [[ $(echo "$LAST" | grep -c ' ') = 1 ]]; then
  # LAST=$(last -n 1 $ITEM |head -n1 |awk -F"   " '{print $4}' )
   LAST=$(last -n 1 $ITEM |head -n1 |awk '{print $4,$5,$6,$7}' )
#"sgobbi   pts/0        msfs01.idc.datam Tue Nov  3 12:04 - 12:04  (00:00)
  fi
#CHECK AGAIN IF THERE IS NUMBER IN DATE
  if [[ $(echo "$LAST" |grep -c -E [0-9]) = 0 ]]; then
   pt "LAST-0 No valida date found on .${LAST}."
   LAST=""
   return
  fi
  pt "LAST-1 .${LAST}."
  if [[ ! -z $LAST ]]; then
   if [[ $(echo "$LAST" | grep -i -c "still ") = 0 ]]; then
 #CLEANUP SOME ENTRIES SHOW LOGIN - LOGOU TIME
    pt "LAST-2 $LAST"
    LAST=$(echo "$LAST"|awk '{ print $1, $2, $3, $4 }')
    pt "LAST-3 $LAST"
    LAST=$(date -d"$LAST" +"%d/%m %H:%M")
   else
    LAST=""
   fi
  else
   LAST=""
  fi
 fi #empty
}

function getlocalid() {
 ITEM=$1
 if [[ $(echo "$ITEM" |grep -c -i '\\') = 0 ]]; then
   ID=$(/usr/bin/id $ITEM |awk -F"(" '{print $1}' |sed 's/uid\=//g' )
#COULD GET DOMAIN
 else
   ID="Domain"
 fi
}
function printline() {
 eval PHOST="$1"
 eval PITEM="$2"
 eval PID="$3"
 eval PTIPO="$4"
 eval PLAST="$5"
 eval PL="$6"

##PRINT ONLY OF THE DATES
 if [[ ( ! -z "$PLAST" && ! -z "$PL" ) ]]; then
   DATELL="$PL"
 elif [[ ( -z "$PLAST" && ! -z "$PL" ) ]]; then
   DATELL="$PL"
 else
   DATELL="$PLAST"
 fi

 pt "PLAST .${PLAST}. PL: .${PL}."
 pt "DATE: $DATELL"

 echo "$PHOST ,  $PITEM , $PID , $PTIPO , $DATELL"

#if [[ ( ! -z "$PID" && $PID -gt 999 ) ]]; then
# echo "$PHOST ,  $PITEM , $PID , $PTIPO , $DATELL"
#elif [[ $(echo "$PTIPO" | grep -c -i domain) != 0 ]]; then
# echo "$PHOST ,  $PITEM , $PID , $PTIPO , $DATELL"
#else
# pt "DEBUG OUTPUT(FILTRATO): $PHOST ,  $PITEM , $PID , $PTIPO , $DATELL"
#fi


 PHOST=""
 PITEM=""
 PID=""
 PTIPO=""
 PLAST=""
 PL=""
}





############################### MAIN ################################


#get /var/log/secure files
getloginsshfiles

##GET LIST OF ALL USERS ON SUDO THAT CAN BECOME ROOT without ASKING FOR PASSWORD!


LIST=$(cat /etc/sudoers |grep -v "^#" |grep -v "^$" |grep -i -v nrpe |grep -v LC_ |grep ALL |sed -e 's/ALL//g' -e 's/NOPASSWD\://g' -e 's/\=()//g'|grep -v root|grep -v wheel|grep -v POWER)
for ITEM in $LIST; do
 LAST=""
 TIPO="SUDOER"
 pt "SUDOERS: $ITEM"
 getlocalid $ITEM
 getlastlogin $ITEM
 getloginssh $ITEM
 printline "\${HOST}" "\${ITEM}" "\${ID}" "\${TIPO}" "\${LAST}" "\${L}"
done


#GET LIST OF ALL USERS FROM /ETC/PASSWD

for ITEM in $(cut -d: -f1 /etc/passwd|grep -v nfsnobody|grep -v root); do
#check if not already on sudoers
# pt "ITEM-1 $ITEM"
 LAST=""
 L=""
 if [[ $(grep -i -c $ITEM /etc/sudoers) = 0 ]] ; then

  getlocalid $ITEM
#ONLY CHECK NON SYSTEM ACCOUNTS
  if [ $ID -gt 999 ]; then
   getlastlogin $ITEM
   getloginssh $ITEM

#check if it is SSH defined
   if [[ $(grep -i -c $ITEM /etc/ssh/sshd_config) != 0 ]]; then
    TIPO="SFTP"
   else
    TIPO=""
   fi

   pt "LAST: $LAST L: $L"

   printline "\${HOST}" "\${ITEM}" "\${ID}" "\${TIPO}" "\${LAST}" "\${L}"
  fi
 fi
done

#CLEANUP
/bin/rm -rf ${TMPD}*
echo "DONE"

exit 0
