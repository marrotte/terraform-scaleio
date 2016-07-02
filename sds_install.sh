#!/bin/bash
yum -ytq install wget libaio numactl
rpm -i https://scaleio-source.s3.amazonaws.com/1.32/EMC-ScaleIO-sds-1.32-403.2.el7.x86_64.rpm
