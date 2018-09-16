#!/usr/bin/env bash

set -x

TEMP_PATH=${TOP_PATH}/../openstack_installer_temp

function create_database()
{
	db_cmd="mysql --user=root --password=${DB_PASS}"
	echo "CREATE DATABASE glance;" | ${db_cmd}
	echo "GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost' IDENTIFIED BY '${GLANCE_DBPASS}';" | ${db_cmd}
	echo "GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' IDENTIFIED BY '${GLANCE_DBPASS}';" | ${db_cmd}
	echo "FLUSH PRIVILEGES;" | ${db_cmd}
	echo "quit" | ${db_cmd}
}

function create_glance_credential()
{
	source ${TEMP_PATH}/admin-openrc

	openstack user create glance --domain default --password ${GLANCE_PASS}

	openstack role add --project service --user glance admin

	openstack service create --name glance \
	  --description "OpenStack Image" image

	openstack endpoint create --region RegionOne \
	  image public http://${CONTROLLER_NODE_HOSTNAME}:9292

	openstack endpoint create --region RegionOne \
	  image internal http://${CONTROLLER_NODE_HOSTNAME}:9292

	openstack endpoint create --region RegionOne \
	  image admin http://${CONTROLLER_NODE_HOSTNAME}:9292
}

function install_configure_glance()
{
	yum -y install openstack-glance
	if [[ $? -eq 0 ]]
	then
		crudini --set /etc/glance/glance-api.conf database connection mysql+pymysql://glance:${GLANCE_DBPASS}@${CONTROLLER_NODE_HOSTNAME}/glance
		crudini --set /etc/glance/glance-api.conf keystone_authtoken auth_uri http://${CONTROLLER_NODE_HOSTNAME}:5000
		crudini --set /etc/glance/glance-api.conf keystone_authtoken auth_url http://${CONTROLLER_NODE_HOSTNAME}:35357
		crudini --set /etc/glance/glance-api.conf keystone_authtoken memcached_servers ${CONTROLLER_NODE_HOSTNAME}:11211
		crudini --set /etc/glance/glance-api.conf keystone_authtoken auth_type password
		crudini --set /etc/glance/glance-api.conf keystone_authtoken project_domain_name default
		crudini --set /etc/glance/glance-api.conf keystone_authtoken user_domain_name default
		crudini --set /etc/glance/glance-api.conf keystone_authtoken project_name service
		crudini --set /etc/glance/glance-api.conf keystone_authtoken username glance
		crudini --set /etc/glance/glance-api.conf keystone_authtoken password ${GLANCE_PASS}


		crudini --set /etc/glance/glance-api.conf paste_deploy flavor keystone

		crudini --set /etc/glance/glance-api.conf glance_store stores file,http
		crudini --set /etc/glance/glance-api.conf glance_store default_store file
		crudini --set /etc/glance/glance-api.conf glance_store filesystem_store_datadir /var/lib/glance/images/

		crudini --set /etc/glance/glance-registry.conf database connection mysql+pymysql://glance:${GLANCE_DBPASS}@${CONTROLLER_NODE_HOSTNAME}/glance
		crudini --set /etc/glance/glance-registry.conf keystone_authtoken auth_uri http://${CONTROLLER_NODE_HOSTNAME}:5000
		crudini --set /etc/glance/glance-registry.conf keystone_authtoken auth_url http://${CONTROLLER_NODE_HOSTNAME}:35357
		crudini --set /etc/glance/glance-registry.conf keystone_authtoken memcached_servers ${CONTROLLER_NODE_HOSTNAME}:11211
		crudini --set /etc/glance/glance-registry.conf keystone_authtoken auth_type password
		crudini --set /etc/glance/glance-registry.conf keystone_authtoken project_domain_name default
		crudini --set /etc/glance/glance-registry.conf keystone_authtoken user_domain_name default
		crudini --set /etc/glance/glance-registry.conf keystone_authtoken project_name service
		crudini --set /etc/glance/glance-registry.conf keystone_authtoken username glance
		crudini --set /etc/glance/glance-registry.conf keystone_authtoken password ${GLANCE_PASS}

		crudini --set /etc/glance/glance-registry.conf paste_deploy flavor keystone

		su -s /bin/sh -c "glance-manage db_sync" glance

		systemctl enable openstack-glance-api.service \
		  openstack-glance-registry.service

		systemctl start openstack-glance-api.service \
		  openstack-glance-registry.service
	else
		echo "Install or configure glance failed!"
	fi
}

function verify_glance()
{
	source ${TEMP_PATH}/admin-openrc

	wget -P ${TOP_PATH} http://download.cirros-cloud.net/0.3.5/cirros-0.3.5-x86_64-disk.img

	openstack image create "cirros" \
	  --file ${TOP_PATH}/cirros-0.3.5-x86_64-disk.img \
	  --disk-format qcow2 --container-format bare \
	  --public
	if [[ $? -ne 0 ]]
	then
		echo "sleep 5 ..."
		sleep 5
		openstack image create "cirros" \
		  --file ${TOP_PATH}/cirros-0.3.5-x86_64-disk.img \
		  --disk-format qcow2 --container-format bare \
		  --public
	fi

	openstack image list
}

if [[ -f ${TOP_PATH}/scripts/functions.sh ]]
then
        source ${TOP_PATH}/scripts/functions.sh
else
        echo "ERROR: Cann't access ${TOP_PATH}/scripts/functions.sh. Exit..."
        exit 1
fi

create_database
create_glance_credential
install_configure_glance
verify_glance

