#!/bin/bash
# Felipe Ferreira 07/2016
#
# Update local repository with cmd reposync
#
# To add new ones be sure to add repo conf in /repo/conf/

# 22/08 - update centos-5 epel-5 pbis remi to usa SHA checksum (for centos/redhat 5 compatibility)

http_proxy="http://172.27.1.1:8080"
https_proxy="http://172.27.1.1:8080"


repos=( pbis pbis-i386 epel-6 epel-5 remi remi-safe centos-6-i386 centos-7 centos-6 centos-5 centos-5-i386 packetfence  epel-7 epel-5-i386 epel-6-i386  oraclelinux-6 centos-6-updates apache24-64 spacewalk-6-x64)

repos=( spacewalk-6-x64 spacewalk-6-i386 spacewalk-5-x64 spacewalk-5-i386)

function sync() {
 echo -e "\n\n"
 echo "Syncing repository $1"
 reposync --gpgcheck -l -n -c /repo/conf/yum.conf --repoid=$1 --download_path=/repo/ |tee -a /repo/log/$1.log
 cd /repo/$1
 date |tee -a /repo/log/$1.log
 if [ "$1" == "pbis" ] || [ "$1" == "epel-5" ] || [ "$1" == "centos-5" ]; then
  echo "Using checksum SHA for $1"
  rm -rf repodata/
  createrepo  -d -s sha . |tee -a /repo/log/$1.log
  chown apache.apache -R repodata/
  chown apache.apache repodata
 else
  createrepo --update . |tee -a /repo/log/$1.log
 fi
 echo "OK - logs on /repo/log/$1.log"
}

echo -e "\n----------------------------------------------------------------"
echo -e "\n Starting to sync all repositories..."
echo $(date)

for repo in ${repos[@]}
do
 sync $repo
done

find /repo/ -type d |xargs du -sh  $1 |grep G
echo "DONE"
chown apache.apache -R /repo
/usr/lib/nagios/plugins/check_yumrepo
