#!/bin/bash
#Script di Deploy per Weblogic 12
#Felipe Ferreira 11/2017

D=$(date +%Y%m%d%H%M)
###VARIABLES
TMP_DIR="/tmp/deploy_wl/"
HOST_NAME="localhost"
HOST_USER="weblogic"
HOST_PASS="weblogic1"
HOST_PORT="7001"

APPSERVERNUMBER=2
SERVER="Server2"

PORT="7004" 
APPURL="http://localhost:${PORT}/wamain/"

WLENV="/sbWls/Oracle/wlserver/server/bin/setWLSEnv.sh"
WL_HOME="/doWlsdmnextsvil/dmnextsvil"
WL_BIN="${WL_HOME}/bin/"
WL_JAR="/sbWls/Oracle/wlserver/server/lib/weblogic.jar"
WL_LOG="${WL_HOME}/servers/${SERVER}/logs/${SERVER}.log"
WL_LOGOUT="${WL_HOME}/servers/${SERVER}/logs/${SERVER}.out"
WL_EAR="/doWlsdmnextsvil/ear/app/"
WL_EAR_BKP="${WL_HOME}/servers/${SERVER}/backup_ear_${D}/"
JAVA_BIN="/sbJvm/jdk1.7.0_80/jre/bin/java"
PACKAGE="package_wl.zip"
TERRORS=0

######## FUNTIONS #########

function unzipDeployFile() {
#Cleanup tmp dir
 if [ -d $TMP_DIR ]; then
  /bin/rm -rf $TMP_DIR
   mkdir -p $TMP_DIR
 else
   mkdir -p $TMP_DIR
 fi
  cd $TMP_DIR  
 if [ ! -f ${WL_HOME}/${PACKAGE} ]; then
  echo "ERROR - Package ${WL_BIN}${PACKAGE} not found"
  exit 2
 fi
 /bin/cp -fv ${WL_HOME}/${PACKAGE} .
  unzip -q -o $PACKAGE
 #MANUALY DELETE USELESS EAR HERE
  if [ -f "gepe-mtra.ear" ]; then
        /bin/rm -f gepe-mtra.ear
  fi
  if [ -f "gepe-f24.ear" ]; then
        /bin/rm -f gepe-f24.ear
  fi  
#List of ear files to variable
  for F in *.ear; do
   FILESDEP="$FILESDEP $F"
   echo "File -> $F"
  done


}

function backup() {
if [ -d $WL_EAR_BKP ]; then
  mkdir -p $WL_EAR_BKP
fi
C=$(ls -l $WL_EAR |wc -l)
/bin/cp -f ${WL_EAR}*.ear  $WL_EAR_BKP 
echo "Backuped $C ear files to $WL_EAR_BKP"
}

function fallback() {
echo "Starting Fallbackup from $WL_EAR_BKP"
if [ ! -d $WL_EAR_BKP ]; then
 echo "ERROR - Could not find the backup folder $WL_EAR_BKP"
 exit 2
fi 
 source $WLENV
 for FILESDEP in $WL_EAR_BKP ; do
  agentDeployer $FILESDEP
 done

echo "Done Fallbackup from $WL_EAR_BKP"
}



function agentDeployer() {
 DEPLOYEAR=$1
 FILEC=$(echo "$DEPLOYEAR" | sed 's/\.ear//g')
 APPNAME=${FILEC}${APPSERVERNUMBER}
 echo "Deploying AppName -> $APPNAME"

 ${JAVA_BIN} -cp ${WL_JAR} weblogic.Deployer -adminurl t3://${HOST_NAME}:${HOST_PORT} -user ${HOST_USER} -password ${HOST_PASS} -targets ${SERVER} -deploy -upload ${TMP_DIR}${DEPLOYEAR} -name ${APPNAME}
 echo -e "Deploy ${APPNAME} in $SERVER Done\n"
}

waitdep() {
T=0
M=40 # max time 
while [ $T -lt $M ]; do
  if [[ $(tail -n 30 $WL_LOGOUT |grep -ic "pms-online-lib") => 1 ]]; then
        echo -e "Deploy done in $T seconds"
        break
  else
        sleep 1
        echo -ne "."        
        T=$(expr $T + 1)
  fi
done
}

function checklog() {
 F=$1
 TERROR=0
 LINES=800  
 TERROR=$(cat $F | grep -iv warning |grep -ic  ERROR)
 TERRORS=$(expr $TERROR + $TERRORS)
 echo "File : ${F}, checking last $LINES lines, Found $TERROR errors"
 echo -e "-----------------------------------------------------------------------------------------------------------------------------------------" 
 tail -${LINES} ${F}|grep -i error |grep -v -i warning  | sort | uniq -c | sort -n 
 echo -e "-----------------------------------------------------------------------------------------------------------------------------------------\n"
 
 
}
  
function checkapp()   {
 CHK=$(curl -s -L $APPURL |grep -c credenziali)
 echo -e "\n"
 if [ "$CHK" -eq "1" ]; then
  echo  ".Deploy was a success" |tee -a $MSG
  echo ".Found  $TERRORS Total Errors" |tee -a $MSG
 else
  echo ".Deploy failed" |tee -a $MSG
  echo ".Deploy failed, could not open page $APPURL " |tee -a $MSG
  echo ".Found $TERROR Errors" |tee -a $MSG
  fallback
 fi
}




######## MAIN ##########

echo "Deploying $PACKAGE"
unzipDeployFile
backup 
source $WLENV
for FILESDEP in $FILESDEP ; do
 agentDeployer $FILESDEP
done

echo "Deploy Done, checking log file: $WL_LOG"
echo -e "\n-----------------------------------------------------------------------------------------------------------------------------------------\n"
echo "Waiting for deploy to finish..."
waitdep 
echo "Checking log"
echo -e "\n-----------------------------------------------------------------------------------------------------------------------------------------\n"
checklog $WL_LOG
checklog $WL_LOGOUT
echo -e "\n-----------------------------------------------------------------------------------------------------------------------------------------\n"
echo "Checking applicatoin $APPURL "
checkapp
