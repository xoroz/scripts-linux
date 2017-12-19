#!/bin/bash
#
# Searchs elastic search graylog

#
F="/tmp/.out.log"

curl -s -o $F -XPOST '<ELASTICSEARCHSERVER>:9200/_search?routing=kimchy&pretty' -H 'Content-Type: application/json' -d'
{
    "query": {
        "bool" : {
            "must" : {
                "query_string" : {
                    "query" : "WAF"
                }
            },
            "filter" : {
                "term" : { "act" : "deny" }
            }
        }
    }
}'

if [ -f $F ]; then
DT=$(cat $F |grep -c requestMethod)
DRT=$(cat $F |grep requestMethod |egrep -v "PROPFIND|HEAD")

M="Found $DT total requests Deny"
 if [ $DRT ] ; then
  echo "CRITICAL - Found $DRT total requests with Real Deny, check WAF"
  rm -f $F
  exit 2
 else
  echo "OK - found not real Deny on WAF, only $DT deny requests with unusuall HTTP method"
  rm -f $F
  exit 0
 fi
else
 echo "WARNING - could not find the file $F"
 exit 3
fi
