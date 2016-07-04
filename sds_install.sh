#!/bin/bash
#yum -ytq install wget libaio numactl gcc-c++
yum -ytq install wget libaio numactl 
#echo "Installing bonnie++"
#wget http://www.coker.com.au/bonnie++/bonnie++-1.03e.tgz
#tar -zxvf bonnie++-1.03e.tgz
#cd bonnie++-1.03e
#sudo ./configure
#sudo make
#sudo make install
echo "Installing glances"
wget https://bootstrap.pypa.io/get-pip.py
sudo python get-pip.py
wget -O- http://bit.ly/glances | /bin/bash
rpm -i https://scaleio-source.s3.amazonaws.com/1.32/EMC-ScaleIO-sds-1.32-403.2.el7.x86_64.rpm



