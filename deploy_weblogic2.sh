#!/bin/bash
#Script di Deploy per Weblogic 12
#questa versione fa il STOP, cleanup,backup,deploy e START 
#Felipe Ferreira 11/2017

D=$(date +%Y%m%d%H%M)
###VARIABLES
TMP_DIR="/tmp/deploy_wl/"
WL_HOST="localhost"
WL_USER="weblogic"
WL_PASS="weblogic1"
WL_APORT="7001"
WL_NMPORT="5556"
WL_DOMAIN="dmnextsvil"


APPSERVERNUMBER=2
SERVER="Server2"

PORT="7004"
APPURL="http://localhost:${PORT}/wamain/"

WLENV="/sbWls/Oracle/wlserver/server/bin/setWLSEnv.sh"
JAVA_BIN="/sbJvm/jdk1.7.0_80/jre/bin/java"
WL_HOME="/doWlsdmnextsvil/dmnextsvil"
WL_BIN="${WL_HOME}/bin/"
WL_JAR="/sbWls/Oracle/wlserver/server/lib/weblogic.jar"
WL_LOG="${WL_HOME}/servers/${SERVER}/logs/${SERVER}.log"
WL_LOGOUT="${WL_HOME}/servers/${SERVER}/logs/${SERVER}.out"
WL_EAR="/doWlsdmnextsvil/ear/app/"
WL_EAR_BKP="${WL_HOME}/servers/${SERVER}/backup_ear_${D}/"
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
stopApp
/bin/cp -fv $WL_EAR_BKP $WL_EAR
startApp 
echo "Done Fallbackup from $WL_EAR_BKP"
}

function cleanup() {
 echo "Starting cleanup of tmp, cache, stage"
 /bin/rm -rf ${WL_HOME}/servers/${SERVER}/tmp
 /bin/rm -rf ${WL_HOME}/servers/${SERVER}/cache
 /bin/rm -rf ${WL_HOME}/servers/${SERVER}/stage
 #? /bin/rm -rf ${WL_HOME}/servers/${SERVER}/data
 echo "Done cleanup"
}

function copyear() {
 echo "Starting copying EAR files from $FILESDEP $WL_EAR"
 if [ ! -d "$FILESDEP"]; then
  echo "ERROR - Could not find the ear folder $FILESDEP"
  exit 2
 fi 
 for FILESDEP in $FILESDEP ; do 
  /bin/cp -fv $FILESDEP  $WL_EAR
 done
 C=$(ls -l $WL_EAR |wc -l)
 echo "Copied $C ear files to $WL_EAR"
}

function createScript() {
 ACT=$1
 echo "Creating script ${TMP_DIR}${ACT}_${SERVER}.py for $ACT Weblogic $SERVER instance"
 if [ "$ACT" == "stop" ]; then
  CMDA="nmKill(\"$SERVER\");"
 elif [ "$ACT" == "start" ]; then
  CMDA="nmStart(\"$SERVER\");"
 else
  echo "ERROR - must pass start or stop to function"
  exit 2
 fi

/bin/cat >${TMP_DIR}${ACT}_${SERVER}.py<<EOF
import time
sleep=time.sleep
while True:
   try: connect("${WL_USER}","${WL_PASS}","t3://${WL_HOST}:${WL_APORT}"); break
   except: sleep(2)
while True:
   try: nmConnect("${WL_USER}","${WL_PASS}","${WL_HOST}","${WL_NMPORT}","${WL_DOMAIN}","${WL_HOME}","plain"); break
   except: sleep(2)
nmServerStatus("$SERVER");
${CMDA}
nmDisconnect();
exit();
EOF

 if [ ! -f ${TMP_DIR}${ACT}_${SERVER}.py ]; then
  echo "ERROR - Could not create ${TMP_DIR}${ACT}_${SERVER}.py"
  exit 2
 else
  echo "OK - ${TMP_DIR}${ACT}_${SERVER}.py created"
 fi
}

function stopApp() {
 echo "Stopping $SERVER"
 ${JAVA_BIN} -cp ${WL_JAR} weblogic.WLST ${TMP_DIR}stop_${SERVER}.py
}

function startApp() {
 echo "Starting $SERVER"
 ${JAVA_BIN} -cp ${WL_JAR} weblogic.WLST ${TMP_DIR}start_${SERVER}.py
}

waitdep() {
T=0
M=40 # max time 
while [ $T -lt $M ]; do
  if [[ $(tail -n 30 $WL_LOGOUT |grep -ic "pms-online-lib") != 0 ]]; then
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
createScript start
createScript stop
backup 
cleanup 
source $WLENV
stopApp
copyear
startApp 

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
