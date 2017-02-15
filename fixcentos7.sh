#!/bin/bash
#Fix centos 7 instalation
#Felipe Ferreira, Feb 2017

SVCS="wpa_supplicant alsa-state cups abrt-xorg abrt-oops avahi-daemon atd abrtd irqbalance packagekit getty@tty1 libstoragemgmt NetworkManager"

function disablesvc()
{
# echo "Stoping/Disablingservice $SVC"
 if systemctl -t service |grep runn |grep $SVC; then systemctl stop $SVC ;  fi
 if systemctl list-unit-files --type service |grep enabled |grep $SVC; then systemctl disable $SVC; fi
}


#REMOVE IPV6 FROM CENTOS 7
function rmipv6()
{
 if [[ $(ip addr |grep -c inet6) > 0 ]]; then
  echo "IPV6 IP found"
 #GET network interface configuration file
  if [[ $(find /etc/sysconfig/network-scripts/ -name 'ifcfg-eno*' -exec grep -c 'IPV6_DEFROUTE="yes"' {} \;) = 1 ]]; then
   echo "IPV6 e ativato"
   FILE=$(find /etc/sysconfig/network-scripts/ -name 'ifcfg-eno*' |tail -n1 )
   sed -e '/IPV6_PEERDNS="yes"/d' -e '/IPV6_PEERROUTES="yes"/d'  -e '/IPV6_PRIVACY="no"/d' -e '/IPV6_DEFROUTE="yes"/d' -e '/IPV6_AUTOCONF="yes"/d'  -e '/IPV6_FAILURE_FATAL/d' -e '/IPV6INIT/c\IPV6INIT="no"' -i $FILE
cat <<EOF>>/etc/sysctl.conf
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF
   sysctl -p  >/dev/null
   sed -i '/::1/d' /etc/hosts
   echo "IPV6 disabled, please restart network service"
  fi
 fi
}



rmipv6

for SVC in $SVCS
do
 disablesvc $SVC
done

#echo "Run systemctl restart network"
echo -e "\nDONE"
