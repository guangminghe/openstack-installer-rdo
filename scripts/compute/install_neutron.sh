#!/usr/bin/env bash

set -x

function install_configure_neutron()
{
	yum -y install openstack-neutron-linuxbridge ebtables ipset
	if [[ $? -eq 0 ]]
	then
		crudini --set /etc/neutron/neutron.conf DEFAULT transport_url rabbit://openstack:${RABBIT_PASS}@${CONTROLLER_NODE_HOSTNAME}
		crudini --set /etc/neutron/neutron.conf DEFAULT auth_strategy keystone

		crudini --set /etc/neutron/neutron.conf keystone_authtoken auth_uri http://${CONTROLLER_NODE_HOSTNAME}:5000
		crudini --set /etc/neutron/neutron.conf keystone_authtoken auth_url http://${CONTROLLER_NODE_HOSTNAME}:35357
		crudini --set /etc/neutron/neutron.conf keystone_authtoken memcached_servers ${CONTROLLER_NODE_HOSTNAME}:11211
		crudini --set /etc/neutron/neutron.conf keystone_authtoken auth_type password
		crudini --set /etc/neutron/neutron.conf keystone_authtoken project_domain_name default
		crudini --set /etc/neutron/neutron.conf keystone_authtoken user_domain_name default
		crudini --set /etc/neutron/neutron.conf keystone_authtoken project_name service
		crudini --set /etc/neutron/neutron.conf keystone_authtoken username neutron
		crudini --set /etc/neutron/neutron.conf keystone_authtoken password ${NEUTRON_PASS}

		crudini --set /etc/neutron/neutron.conf oslo_concurrency lock_path /var/lib/neutron/tmp
	else
		echo "install openstack-neutron-linuxbridge ebtables ipset failed!"
	fi
}

function provider_networks()
{
	crudini --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini linux_bridge physical_interface_mappings provider:${PROVIDER_INTERFACE_NAME}
	crudini --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini vxlan enable_vxlan false
	crudini --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini securitygroup enable_security_group true
	crudini --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini securitygroup firewall_driver neutron.agent.linux.iptables_firewall.IptablesFirewallDriver
}

function configure_compute_service()
{
	crudini --set /etc/nova/nova.conf neutron url http://${CONTROLLER_NODE_HOSTNAME}:9696
	crudini --set /etc/nova/nova.conf neutron auth_url http://${CONTROLLER_NODE_HOSTNAME}:35357
	crudini --set /etc/nova/nova.conf neutron auth_type password
	crudini --set /etc/nova/nova.conf neutron project_domain_name default
	crudini --set /etc/nova/nova.conf neutron user_domain_name default
	crudini --set /etc/nova/nova.conf neutron region_name RegionOne
	crudini --set /etc/nova/nova.conf neutron project_name service
	crudini --set /etc/nova/nova.conf neutron username neutron
	crudini --set /etc/nova/nova.conf neutron password ${NEUTRON_PASS}
}

function finalize_installation()
{
	systemctl restart openstack-nova-compute.service

	systemctl enable neutron-linuxbridge-agent.service
	systemctl start neutron-linuxbridge-agent.service
}

if [[ -f ${TOP_PATH}/scripts/functions.sh ]]
then
        source ${TOP_PATH}/scripts/functions.sh
else
        echo "ERROR: Cann't access ${TOP_PATH}/scripts/functions.sh. Exit..."
        exit 1
fi

install_configure_neutron
provider_networks
configure_compute_service
finalize_installation

