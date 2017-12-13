#!/usr/bin/bash
#Prepare a Ubuntu 16.04 for Mining (tested on ec2 g2x instance)
#by Felipe Ferreira Dec. 2017


#should check if I am root
ME=$(whoami)
if [ "$ME" == "root" ]; then
 echo "OK - we are root"
else
 echo "ERROR - please login as root"
 exit 2
fi


mkdir ~/mining

echo "UPDATING BUT NOT UPGRADING DIST"
apt-get -y update
echo "INSTALLING REQURIREMENTS"
apt-get -y install gcc g++ build-essential libssl-dev automake linux-headers-$(uname -r) git gawk libcurl4-openssl-dev libjansson-dev xorg libc++-dev libgmp-dev python-dev

cd ~/mining
echo "GETTING NVIDIA LINUX DRIVERS (12/13/2017)"
echo ".version: 384.98"
echo "For newer versions always check: http://www.nvidia.com/object/unix.html"
wget "http://us.download.nvidia.com/XFree86/Linux-x86_64/384.98/NVIDIA-Linux-x86_64-384.98.run"
chmod +x NVIDIA-Linux-x86_64-384.98.run
./NVIDIA-Linux-x86_64-384.98.run -accept-license --no-questions --disable-nouveau --no-install-compat32-libs
apt-cache search nvidia | grep -P '^nvidia-[0-9]+\s'
nvidia-smi -q |grep "Driver Version"
echo "---------------------------------------------------"
echo "| Reboot machine and continue with next step      |"
echo "---------------------------------------------------"
exit 0



--------------------------------------
#!/usr/bin/bash
#Prepare a Ubuntu 16.04 for Mining (tested on ec2 g2x instance) 
# SCRIPT 1/2 
#by Felipe Ferreira Dec. 2017

#should check if I am root
ME=$(whoami)
if [ "$ME" == "root" ]; then
 echo "OK - we are root"
else
 echo "ERROR - please login as root"
 exit 2
fi


cd ~/mining


echo "GETTING NVIDIA CUDA (12/13/2017)"
echo ".version: 9.1.85 Ubuntu 16.04"
echo "For newer versions always check: https://developer.nvidia.com/cuda-downloads"

wget "http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1604/x86_64/cuda-repo-ubuntu1604_9.1.85-1_amd64.deb"
dpkg -i cuda-repo-ubuntu1604_9.1.85-1_amd64.deb
apt-key adv --fetch-keys http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1604/x86_64/7fa2af80.pub
apt-get -y install cuda
apt -y  install cuda-command-line-tools-9-1

#usermod -a -G video $(whoami)
echo "" >> ~/.bashrc
echo "export PATH=/usr/local/cuda-9.1/bin:$PATH" >> ~/.bashrc
echo "export LD_LIBRARY_PATH=/usr/local/cuda-9-1/lib64:$LD_LIBRARY_PATH" >> ~/.bashrc
source  ~/.bashrc
nvcc -V
echo "| Reboot machine and continue with next step  |"

