#!/usr/bin/env bash

set -x

TEMP_PATH=${TOP_PATH}/../openstack_installer_temp

function create_database()
{
	db_cmd="mysql --user=root --password=${DB_PASS}"
	echo "CREATE DATABASE neutron;" | ${db_cmd}

	echo "GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'localhost' IDENTIFIED BY '${NEUTRON_DBPASS}';" | ${db_cmd}
	echo "GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'%' IDENTIFIED BY '${NEUTRON_DBPASS}';" | ${db_cmd}

	echo "FLUSH PRIVILEGES;" | ${db_cmd}
	echo "quit" | ${db_cmd}
}

function create_neutron_credential()
{
	source ${TEMP_PATH}/admin-openrc

	openstack user create neutron --domain default --password ${NEUTRON_PASS}
	openstack role add --project service --user neutron admin
	openstack service create --name neutron \
	  --description "OpenStack Networking" network

	openstack endpoint create --region RegionOne \
	  network public http://${CONTROLLER_NODE_HOSTNAME}:9696

	openstack endpoint create --region RegionOne \
	  network internal http://${CONTROLLER_NODE_HOSTNAME}:9696

	openstack endpoint create --region RegionOne \
	  network admin http://${CONTROLLER_NODE_HOSTNAME}:9696
}

function provider_networks()
{
	yum -y install openstack-neutron openstack-neutron-ml2 \
	  openstack-neutron-linuxbridge ebtables

	crudini --set /etc/neutron/neutron.conf database connection mysql+pymysql://neutron:${NEUTRON_DBPASS}@${CONTROLLER_NODE_HOSTNAME}/neutron

	crudini --set /etc/neutron/neutron.conf DEFAULT core_plugin ml2
	crudini --set /etc/neutron/neutron.conf DEFAULT service_plugins ""

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

	crudini --set /etc/neutron/neutron.conf DEFAULT notify_nova_on_port_status_changes true
	crudini --set /etc/neutron/neutron.conf DEFAULT notify_nova_on_port_data_changes true

	crudini --set /etc/neutron/neutron.conf nova auth_url http://${CONTROLLER_NODE_HOSTNAME}:35357
	crudini --set /etc/neutron/neutron.conf nova auth_type password
	crudini --set /etc/neutron/neutron.conf nova project_domain_name default
	crudini --set /etc/neutron/neutron.conf nova user_domain_name default
	crudini --set /etc/neutron/neutron.conf nova region_name RegionOne
	crudini --set /etc/neutron/neutron.conf nova project_name service
	crudini --set /etc/neutron/neutron.conf nova username nova
	crudini --set /etc/neutron/neutron.conf nova password ${NOVA_PASS}

	crudini --set /etc/neutron/neutron.conf oslo_concurrency lock_path /var/lib/neutron/tmp

	crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 type_drivers flat,vlan
	crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 tenant_network_types ""
	crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 mechanism_drivers linuxbridge
	crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 extension_drivers port_security

	crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_flat flat_networks provider

	crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup enable_ipset true

	crudini --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini linux_bridge physical_interface_mappings provider:${PROVIDER_INTERFACE_NAME}
	crudini --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini vxlan enable_vxlan false
	crudini --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini securitygroup enable_security_group true
	crudini --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini securitygroup firewall_driver neutron.agent.linux.iptables_firewall.IptablesFirewallDriver

	crudini --set /etc/neutron/dhcp_agent.ini DEFAULT interface_driver linuxbridge
	crudini --set /etc/neutron/dhcp_agent.ini DEFAULT dhcp_driver neutron.agent.linux.dhcp.Dnsmasq
	crudini --set /etc/neutron/dhcp_agent.ini DEFAULT enable_isolated_metadata true
}

function configure_metadata_aggent()
{
	crudini --set /etc/neutron/metadata_agent.ini DEFAULT nova_metadata_ip ${CONTROLLER_NODE_HOSTNAME}
	crudini --set /etc/neutron/metadata_agent.ini DEFAULT metadata_proxy_shared_secret ${METADATA_SECRET}
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
	crudini --set /etc/nova/nova.conf neutron service_metadata_proxy true
	crudini --set /etc/nova/nova.conf neutron metadata_proxy_shared_secret ${METADATA_SECRET}
}

function finalize_installation()
{
	ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini
	su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf \
	  --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head" neutron

	 systemctl restart openstack-nova-api.service

	 systemctl enable neutron-server.service \
	  neutron-linuxbridge-agent.service neutron-dhcp-agent.service \
	  neutron-metadata-agent.service

	 systemctl start neutron-server.service \
	  neutron-linuxbridge-agent.service neutron-dhcp-agent.service \
	  neutron-metadata-agent.service

	 # systemctl enable neutron-l3-agent.service
	 # systemctl start neutron-l3-agent.service
}

if [[ -f ${TOP_PATH}/scripts/functions.sh ]]
then
        source ${TOP_PATH}/scripts/functions.sh
else
        echo "ERROR: Cann't access ${TOP_PATH}/scripts/functions.sh. Exit..."
        exit 1
fi

create_database
create_neutron_credential
provider_networks
configure_metadata_aggent
configure_compute_service
finalize_installation

