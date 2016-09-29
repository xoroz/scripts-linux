#!/bin/bash
#Script to monitor Money Conversion Rates
#####################################################
# Nagios plugin to monitor currency exchange value  #
#####################################################
#Author Felipe Ferreira Version: 1.0 Date: 16/10/2008
#Melhoras: 
#Allow passing the Conversion Type as Param
#Allow graphing inside Nagios

VERBOSE=0
MINCRIT=0
MINWARN=0
MAXCRIT=99999999
MAXWARN=99999999
VALUE=0
CONVERSION="EURBRL"
#CONVERSION="BRLEUR"

# Test if Arguments are passed to script
outputDebug() {
    if [ $VERBOSE -gt 0 ] ; then
        echo $1
    fi
}
# no args passed, TEMP output string variable
if [ $# -eq 0 ] ; then
    TEMP="-h"
#getpot parses the args
else
    TEMP=`getopt -o vhm -l 'help,verbose,minwarn:,mincrit:,maxwarn:,maxcrit:' -- "$@"`
fi

outputDebug "Processing Args $TEMP"
if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi
eval set -- "$TEMP"

while true ; do
    case "$1" in
        -v|--verbose) VERBOSE=1 ; outputDebug "Verbose Mode ON" ; shift ;;
        -h|--help) echo "Usage: $0 [--minwarn value] [--maxwarn value] [--mincrit value] [--maxcrit value]  [-v|--verbose] " ; exit 0;;
        --minwarn) outputDebug "Option $1 is $2" ; MINWARN=$2 ; shift 2;;
        --maxwarn) outputDebug "Option $1 is $2" ; MAXWARN=$2 ; shift 2;;
        --mincrit) outputDebug "Option $1 is $2" ; MINCRIT=$2 ; shift 2;;
        --maxcrit) outputDebug "Option $1 is $2" ; MAXCRIT=$2 ; shift 2;;
        --maxcrit) outputDebug "Option $1 is $2" ; MAXCRIT=$2 ; shift 2;;
#        --conv) outputDebug "Option $1 is $2" ; CONVERSION=$2 ; shift 2;;
        --) shift ; break ;;
        *) echo "Internal error! - found $1 and $2" ; exit 3 ;;
    esac
done


#echo "CONVERSION is $CONVERSION"


assertSizeOK() {
    outputDebug "  EURO is $1 validating "
    if awk 'BEGIN{if(0+'$1'<'$MINCRIT'+0)exit 0;exit 1}' 
    then
        echo "MONEYX Critical: Min Crit is $MINCRIT and Value of EURO - $VALUE" ;  exit 2
    fi
    if awk 'BEGIN{if(0+'$1'<'$MINWARN'+0)exit 0;exit 1}'   
    then      
       echo "MONEYX Warning: Min Warn is $MINWARN and Value of EURO - $VALUE" ;  exit 1
    fi
    if awk 'BEGIN{if(0+'$1'>'$MAXCRIT'+0)exit 0;exit 1}'    
    then
        echo "MONEYX Critical: Max Cirtical is $MAXCRIT and Value of EURO - $VALUE" ;  exit 2
    fi
    if awk 'BEGIN{if(0+'$1'>'$MAXWARN'+0)exit 0;exit 1}'     
    then
        echo "MONEYX Warning: Max warn $MAXWARN Value of EURO - $VALUE" ;  exit 1
    fi
}

getValue()
{
	cd /tmp
	#Get the info from yahoo
	wget -q -O euro.csv wget "http://download.finance.yahoo.com/d/quotes.csv?s=$CONVERSION=X&f=l1&e=.csv"
        VALUE=`cat euro.csv`	
	#Should remove .
	#cat euro.csv | sed -e "s/./_/" >>euro2.txt
        #cat euro.csv | sed -i e 's/./_/g'>>euro2.txt
	#VALUE=`cat euro2.txt`
	#echo  $VALUE
}

getValue
assertSizeOK $VALUE $1
echo  "MONEYX OK: Value of EURO is - $VALUE"
exit 0


