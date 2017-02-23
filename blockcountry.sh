#!/bin/bash
#
# Felipe Ferreira Apr. 2016
#
# Create the ipset list
#
# requires ipset
if which ipset  ; then echo "OK - ipset found" ; else echo "Must install ipset"; fi
 
COUNTRY=$1
if [ -z $1 ]; then
    echo "Must provide country, check list http://www.ipdeny.com/ipblocks/data/countries/"
    echo "Optional to provide a port"
    echo "Usage: $0 <country> <port>"
    echo "Example: $0 cn 22"
    exit 3
fi
 
ipset -N $COUNTRY hash:net
#   ipset -N $COUNTRY hash:net,port # DIDNT WORK FOR ME <img draggable="false" class="emoji" alt="🙁" src="https://s.w.org/images/core/emoji/2.2.1/svg/1f641.svg">
 
PORT=$2
 
FILE=/etc/$COUNTRY.zone
 
echo "Downloading Country IP list..."
wget -P /etc/ http:
//www.ipdeny.com/ipblocks/data/countries/$COUNTRY.zone 
if [ $? -ne 0 ];then
    echo "Country code invalid"
    exit 3
fi
 
# Add each IP address from the downloaded list into the ipset 'china'
if [ ! -f $FILE ]; then
    echo "ERROR - did not download $COUNTRY to $FILE"
    exit 2
fi
echo "Adding list $FILE to ipset $COUNTRY"
for IP in $(cat $FILE);
do
  #Verbose
   echo "$IP "
   ipset -A $COUNTRY $IP
done
 
echo "Prepare iptables list, must have the line"
if [ -z $PORT ]; then
 iptables -A INPUT -p tcp -m set --match-set $COUNTRY src -j DROP
else
 iptables -A INPUT -m set --match-set $COUNTRY src -p TCP --destination-port $PORT -j DROP
fi
 
# Restore iptables
iptables-save > /etc/iptables/block_${COUNTRY}_${PORT}.rules
 
iptables -L -n
 
echo "Done"
exit 0
