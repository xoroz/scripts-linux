#!/bin/bash
#Very very simple cache hit ratio for Varnish 4.1
#Felipe Ferreira
# Oct/2017
#Varnish 4.1 Tested

T=$(varnishstat -1 -f MAIN.cache_hit |awk '{ print $2 }')
M=$(varnishstat -1 -f MAIN.cache_miss |awk '{ print $2 }')
UP=$(varnishstat -1 -f MAIN.uptime |awk '{ print $2 }')

UPTIME=$(expr $UP / 60 / 60)

TOT=$(expr $T + $M)
RATIO=$(expr $T \* 100 / $TOT)
echo "HIT $T"
echo "MISS $M"
echo "TOT $TOT"
echo "HIT RATIO ${RATIO}%"
echo "UPTIME $UPTIME hrs"
