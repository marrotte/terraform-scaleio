
#!/bin/bash
echo "Installing Requirements"
sudo yum -ytq install wget libaio numactl gcc-c++

echo "Installing bonnie++"
wget http://www.coker.com.au/bonnie++/bonnie++-1.03e.tgz
tar -zxvf bonnie++-1.03e.tgz
cd bonnie++-1.03e
sudo ./configure
sudo make
sudo make install

echo "Installing glances"
wget https://bootstrap.pypa.io/get-pip.py
sudo python get-pip.py
wget -O- http://bit.ly/glances | /bin/bash

echo "Installing MDM"
sudo rpm -i https://scaleio-source.s3.amazonaws.com/1.32/EMC-ScaleIO-mdm-1.32-403.2.el7.x86_64.rpm

echo "Waiting for SDS list"
while [ ! -f  /tmp/all_sds ];
do
    echo "SDS File Not yet Found - Sleeping before continuining"
    sleep 1 
done
echo "SDS list found"

echo "Creating install file"
cat <<'EOF' > /tmp/install.sh
#!/bin/bash -i

echo "Getting Private IP"
MDM=`curl http://169.254.169.254/latest/meta-data/local-ipv4`

echo "Accepting License"
scli --mdm --add_primary_mdm --primary_mdm_ip $MDM --accept_license
sleep 5
echo "Setting Up Password to be password123!"
scli --login --mdm_ip $MDM --username admin --password admin
scli --mdm_ip $MDM --set_password --old_password admin --new_password password123!
scli --login --mdm_ip $MDM --username admin --password password123!
scli --add_protection_domain --mdm_ip $MDM --protection_domain_name pdomain
scli --add_storage_pool --mdm_ip $MDM --protection_domain_name pdomain --storage_pool_name pool1
sleep 5

for sds_ip in `cat /tmp/all_sds`; do
  scli --add_sds --mdm_ip $MDM --sds_ip $sds_ip --device_path /dev/xvdb --sds_name $sds_ip --protection_domain_name pdomain --storage_pool_name pool1
done

for sds_ip in `cat /tmp/all_sds`; do
  ssh -o StrictHostKeyChecking=no -i .ssh/scaleio -t ec2-user@$sds_ip 'sudo MDM_IP='$MDM' rpm -i https://scaleio-source.s3.amazonaws.com/1.32/EMC-ScaleIO-sdc-1.32-403.2.el7.x86_64.rpm'
  sleep 5;
  scli --protection_domain_name pdomain --add_volume --storage_pool_name pool1 --size_gb 10 --volume_name vol-$sds_ip
  sleep 5;
  scli --map_volume_to_sdc --volume_name vol-$sds_ip --sdc_ip $sds_ip
  sleep 5;
  ssh -i .ssh/scaleio -t ec2-user@$sds_ip 'sudo parted -a optimal -- /dev/scinia mklabel gpt mkpart P1 ext4 "1" "-1"'
  ssh -i .ssh/scaleio -t ec2-user@$sds_ip 'sudo mkfs.ext4 /dev/scinia'
  ssh -i .ssh/scaleio -t ec2-user@$sds_ip 'sudo mkdir /mnt_scinia'
  ssh -i .ssh/scaleio -t ec2-user@$sds_ip 'sudo mount /dev/scinia /mnt_scinia'
done

echo "Installing SDC on MDM"
MDM_IP=$MDM rpm -i https://scaleio-source.s3.amazonaws.com/1.32/EMC-ScaleIO-sdc-1.32-403.2.el7.x86_64.rpm

sleep 5;

echo "Creating volume vol01"
scli --protection_domain_name pdomain --add_volume --storage_pool_name pool1 --size_gb 100 --volume_name vol01

echo "Mapping vol01 to MDM"
scli --map_volume_to_sdc --volume_name vol01 --sdc_ip $MDM

sleep 5;

echo "Creating partition on vol01"
sudo parted -a optimal -- /dev/scinia mklabel gpt mkpart P1 ext4 "1" "-1"

echo "Creating file system on volo1"
sudo mkfs.ext4 /dev/scinia

echo "Mounting file system"
sudo mkdir /mnt_scinia
sudo mount /dev/scinia /mnt_scinia

echo "Running a bonnie++ test against the new SDS"
sudo nohup /usr/local/sbin/bonnie++ -d /mnt_scinia -s 8G -n 0 -m ScaleIO -u root:root &

echo "Starting glances"
nohup glances -s &
 
echo "Done."

sleep 5

EOF
