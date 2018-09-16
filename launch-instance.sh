#!/usr/bin/env bash

set -x

source config/config.sh
source ../openstack_installer_temp/admin-openrc

START_IP="192.168.1.120"
END_IP="192.168.1.150"
DNS="211.137.130.3"
GATEWAY="192.168.1.1"

openstack network create --share --external --provider-physical-network provider --provider-network-type flat provider

openstack subnet create --network provider --allocation-pool start=${START_IP},end=${END_IP} --dns-nameserver ${DNS} --gateway ${GATEWAY} --subnet-range ${SUBNET} provider

openstack flavor create --id 0 --vcpus 1 --ram 64 --disk 1 m1.nano


source ../openstack_installer_temp/demo-openrc

echo -e "\n" | ssh-keygen -q -N ""
openstack keypair create --public-key ~/.ssh/id_rsa.pub mykey
openstack keypair list

openstack security group rule create --proto icmp default
openstack security group rule create --proto tcp --dst-port 22 default

openstack flavor list
openstack image list
openstack network list
openstack security group list

NET_ID=$(openstack network list | grep provider | cut -d ' ' -f 2)

openstack server create --flavor m1.nano --image cirros --nic net-id=${NET_ID} --security-group default --key-name mykey provider-instance

openstack server list

openstack console url show provider-instance

# ping -c 4 192.168.1.130
# ssh cirros@192.168.1.130



# 删除：
# openstack subnet delete provider
# openstack network delete provider

