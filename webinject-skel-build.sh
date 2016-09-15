#!/bin/bash
# by Felipe Ferreira
#
#skel to build a webinject config file

FILEIN=$1
FILEURL=$2
FILEOUT=$3
if [ -z $3 ]; then
        echo "ERROR - PLEASE Pass filein and fileout args"
        echo "buildskel SKELFILE URLFILE FILEOUTPUT"
        exit 3
fi

i=0

readarray URLS < $FILEURL

#START OUTFILE
echo "<testcases repeat='1'>" > $FILEOUT

for word in ${URLS[@]}
do
 if [ ! -z "$word" ]; then
  i=$(expr $i + 1)
#GO THRU THE SKEL FILE AND SUBSTITUE $i  AND $word
  while read line; do
   echo $line | sed -e "s/NUMERO/$i/" -e "s#URLD#${word}#g" >> $FILEOUT
  done <$FILEIN
 fi
done


#END FILEOUT
echo "</testcases>" >> $FILEOUT
echo "DONE, check $FILEOUT"

#cat $FILEOUT
exit 0
