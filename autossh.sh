#!/bin/bash
#by Felipe Ferreira Sep/2011
#updated Mar/2014
 
server=$1
 
# This is when the password is composed of parts of the hostname
#get first char os a string
  first=`echo $server | sed 's/\(^.\).*/\1/'`
#get last char of a string  
  last=`echo $server | sed 's/^.*\(.\)$/\1/'`
#echo $first -- $last
   
case "$server" in
 server* )
      echo "Server"
      passwr="BLABLA${last}BLA${first}_BLABLA"
      /bin/expect/ex1.exp $server "$passwr"
      ;;
 *esx*|*lx* )
      echo "ESX server"
      passwr="BLUBLU${last}BLUBLU"
      /bin/expect/ex2.exp $server "$passwr"
      ;;
    
   * )
      echo "Generic server"
      passwr="IAIA${last}IOIO${first}"
      ;;
esac
# LOGIN INTO SERVER
#echo "login to $server with $passwr"
/bin/expect/auto.exp $server "$passwr"
