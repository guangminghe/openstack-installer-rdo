#!/usr/bin/env bash

set -x

function install_configure_nova()
{
	yum -y install openstack-nova-compute

	crudini --set /etc/nova/nova.conf DEFAULT enabled_apis osapi_compute,metadata
	crudini --set /etc/nova/nova.conf DEFAULT transport_url rabbit://openstack:${RABBIT_PASS}@${CONTROLLER_NODE_HOSTNAME}

	crudini --set /etc/nova/nova.conf api auth_strategy keystone

	crudini --set /etc/nova/nova.conf keystone_authtoken auth_uri http://${CONTROLLER_NODE_HOSTNAME}:5000
	crudini --set /etc/nova/nova.conf keystone_authtoken auth_url http://${CONTROLLER_NODE_HOSTNAME}:35357
	crudini --set /etc/nova/nova.conf keystone_authtoken memcached_servers ${CONTROLLER_NODE_HOSTNAME}:11211
	crudini --set /etc/nova/nova.conf keystone_authtoken auth_type password
	crudini --set /etc/nova/nova.conf keystone_authtoken project_domain_name default
	crudini --set /etc/nova/nova.conf keystone_authtoken user_domain_name default
	crudini --set /etc/nova/nova.conf keystone_authtoken project_name service
	crudini --set /etc/nova/nova.conf keystone_authtoken username nova
	crudini --set /etc/nova/nova.conf keystone_authtoken password ${NOVA_PASS}

	crudini --set /etc/nova/nova.conf DEFAULT my_ip ${CONTROLLER_NODE_IP}

	crudini --set /etc/nova/nova.conf DEFAULT use_neutron True
	crudini --set /etc/nova/nova.conf DEFAULT firewall_driver nova.virt.firewall.NoopFirewallDriver

	crudini --set /etc/nova/nova.conf vnc enabled True
	crudini --set /etc/nova/nova.conf vnc vncserver_listen 0.0.0.0
	crudini --set /etc/nova/nova.conf vnc vncserver_proxyclient_address '$my_ip'
	# crudini --set /etc/nova/nova.conf vnc novncproxy_base_url http://${CONTROLLER_NODE_HOSTNAME}:6080/vnc_auto.html
	crudini --set /etc/nova/nova.conf vnc novncproxy_base_url http://${CONTROLLER_NODE_IP}:6080/vnc_auto.html

	crudini --set /etc/nova/nova.conf glance api_servers http://${CONTROLLER_NODE_HOSTNAME}:9292

	crudini --set /etc/nova/nova.conf oslo_concurrency lock_path /var/lib/nova/tmp

	crudini --set /etc/nova/nova.conf placement os_region_name RegionOne
	crudini --set /etc/nova/nova.conf placement project_domain_name Default
	crudini --set /etc/nova/nova.conf placement project_name service
	crudini --set /etc/nova/nova.conf placement auth_type password
	crudini --set /etc/nova/nova.conf placement user_domain_name Default
	crudini --set /etc/nova/nova.conf placement auth_url http://${CONTROLLER_NODE_HOSTNAME}:35357/v3
	crudini --set /etc/nova/nova.conf placement username placement
	crudini --set /etc/nova/nova.conf placement password ${PLACEMENT_PASS}

	vmx_svm=$(egrep -c '(vmx|svm)' /proc/cpuinfo)
	if [[ $vmx_svm -eq 0 ]]
	then
		virt_type="qemu"
	else
		virt_type="kvm"
	fi
	crudini --set /etc/nova/nova.conf libvirt virt_type ${virt_type}

	systemctl enable libvirtd.service openstack-nova-compute.service
	systemctl start libvirtd.service openstack-nova-compute.service
}

if [[ -f ${TOP_PATH}/scripts/functions.sh ]]
then
        source ${TOP_PATH}/scripts/functions.sh
else
        echo "ERROR: Cann't access ${TOP_PATH}/scripts/functions.sh. Exit..."
        exit 1
fi

install_configure_nova

