#!/usr/bin/env bash

set -x

TEMP_PATH=${TOP_PATH}/../openstack_installer_temp

function create_database()
{
	db_cmd="mysql --user=root --password=${DB_PASS}"
	echo "CREATE DATABASE nova_api;" | ${db_cmd}
	echo "CREATE DATABASE nova;" | ${db_cmd}
	echo "CREATE DATABASE nova_cell0;" | ${db_cmd}

	echo "GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'localhost' IDENTIFIED BY '${NOVA_DBPASS}';" | ${db_cmd}
	echo "GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'%' IDENTIFIED BY '${NOVA_DBPASS}';" | ${db_cmd}
	echo "GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'localhost' IDENTIFIED BY '${NOVA_DBPASS}';" | ${db_cmd}
	echo "GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%' IDENTIFIED BY '${NOVA_DBPASS}';" | ${db_cmd}
	echo "GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'localhost' IDENTIFIED BY '${NOVA_DBPASS}';" | ${db_cmd}
	echo "GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'%' IDENTIFIED BY '${NOVA_DBPASS}';" | ${db_cmd}

	echo "FLUSH PRIVILEGES;" | ${db_cmd}
	echo "quit" | ${db_cmd}
}

function create_nova_credential()
{
	source ${TEMP_PATH}/admin-openrc

	openstack user create nova --domain default --password ${NOVA_PASS}

	openstack role add --project service --user nova admin

	openstack service create --name nova \
	  --description "OpenStack Compute" compute

	openstack endpoint create --region RegionOne \
	  compute public http://${CONTROLLER_NODE_HOSTNAME}:8774/v2.1

	openstack endpoint create --region RegionOne \
	  compute internal http://${CONTROLLER_NODE_HOSTNAME}:8774/v2.1

	openstack endpoint create --region RegionOne \
	  compute admin http://${CONTROLLER_NODE_HOSTNAME}:8774/v2.1

	openstack user create placement --domain default --password ${PLACEMENT_PASS}

	openstack role add --project service --user placement admin

	openstack service create --name placement --description "Placement API" placement

	openstack endpoint create --region RegionOne placement public http://${CONTROLLER_NODE_HOSTNAME}:8778
	openstack endpoint create --region RegionOne placement internal http://${CONTROLLER_NODE_HOSTNAME}:8778
	openstack endpoint create --region RegionOne placement admin http://${CONTROLLER_NODE_HOSTNAME}:8778
}

function install_configure_nova()
{
	yum -y install openstack-nova-api openstack-nova-conductor \
	  openstack-nova-console openstack-nova-novncproxy \
	  openstack-nova-scheduler openstack-nova-placement-api
	if [[ $? -eq 0 ]]
	then
		crudini --set /etc/nova/nova.conf DEFAULT enabled_apis osapi_compute,metadata

		crudini --set /etc/nova/nova.conf api_database connection mysql+pymysql://nova:${NOVA_DBPASS}@${CONTROLLER_NODE_HOSTNAME}/nova_api

		crudini --set /etc/nova/nova.conf database connection mysql+pymysql://nova:${NOVA_DBPASS}@${CONTROLLER_NODE_HOSTNAME}/nova

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
		crudini --set /etc/nova/nova.conf vnc vncserver_listen '$my_ip'
		crudini --set /etc/nova/nova.conf vnc vncserver_proxyclient_address '$my_ip'

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

cat >> /etc/httpd/conf.d/00-nova-placement-api.conf <<EOF

<Directory /usr/bin>
   <IfVersion >= 2.4>
      Require all granted
   </IfVersion>
   <IfVersion < 2.4>
      Order allow,deny
      Allow from all
   </IfVersion>
</Directory>
EOF

		systemctl restart httpd
		su -s /bin/sh -c "nova-manage api_db sync" nova
		su -s /bin/sh -c "nova-manage cell_v2 map_cell0" nova
		su -s /bin/sh -c "nova-manage cell_v2 create_cell --name=cell1 --verbose" nova
		su -s /bin/sh -c "nova-manage db sync" nova
		nova-manage cell_v2 list_cells

		systemctl enable openstack-nova-api.service \
		  openstack-nova-consoleauth.service openstack-nova-scheduler.service \
		  openstack-nova-conductor.service openstack-nova-novncproxy.service

		systemctl start openstack-nova-api.service \
		  openstack-nova-consoleauth.service openstack-nova-scheduler.service \
		  openstack-nova-conductor.service openstack-nova-novncproxy.service

	else
		echo "Install or configure glance failed!"
	fi
}

function verify_nova()
{
	echo "This is verify_nova()."
}

if [[ -f ${TOP_PATH}/scripts/functions.sh ]]
then
        source ${TOP_PATH}/scripts/functions.sh
else
        echo "ERROR: Cann't access ${TOP_PATH}/scripts/functions.sh. Exit..."
        exit 1
fi

create_database
create_nova_credential
install_configure_nova
verify_nova

