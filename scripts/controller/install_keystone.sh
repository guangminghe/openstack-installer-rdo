#!/usr/bin/env bash

set -x

TEMP_PATH=${TOP_PATH}/../openstack_installer_temp

function create_database()
{
	db_cmd="mysql --user=root --password=${DB_PASS}"
	echo "CREATE DATABASE keystone;" | ${db_cmd}
	echo "GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY '${KEYSTONE_DBPASS}';" | ${db_cmd}
	echo "GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY '${KEYSTONE_DBPASS}';" | ${db_cmd}
	echo "FLUSH PRIVILEGES;" | ${db_cmd}
	echo "quit" | ${db_cmd}
}

function install_configure_keystone()
{
	yum -y install openstack-keystone httpd mod_wsgi
	if [[ $? -eq 0 ]]
	then
		crudini --set /etc/keystone/keystone.conf database connection "mysql+pymysql://keystone:${KEYSTONE_DBPASS}@${CONTROLLER_NODE_HOSTNAME}/keystone"
		crudini --set /etc/keystone/keystone.conf token provider fernet

		su -s /bin/sh -c "keystone-manage db_sync" keystone

		keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone
		keystone-manage credential_setup --keystone-user keystone --keystone-group keystone

		keystone-manage bootstrap --bootstrap-password ${ADMIN_PASS} \
		  --bootstrap-admin-url http://${CONTROLLER_NODE_HOSTNAME}:35357/v3/ \
		  --bootstrap-internal-url http://${CONTROLLER_NODE_HOSTNAME}:5000/v3/ \
		  --bootstrap-public-url http://${CONTROLLER_NODE_HOSTNAME}:5000/v3/ \
		  --bootstrap-region-id RegionOne

		sed -i -e "s/^#ServerName.*/ServerName ${CONTROLLER_NODE_HOSTNAME}/g" /etc/httpd/conf/httpd.conf
		ln -s /usr/share/keystone/wsgi-keystone.conf /etc/httpd/conf.d/
		systemctl enable httpd.service
		systemctl start httpd.service

		admin_rcfile="admin-openrc-temp"
cat > ${TEMP_PATH}/${admin_rcfile} <<EOF
export OS_USERNAME=admin
export OS_PASSWORD=${ADMIN_PASS}
export OS_PROJECT_NAME=admin
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_DOMAIN_NAME=Default
export OS_AUTH_URL=http://${CONTROLLER_NODE_HOSTNAME}:35357/v3
export OS_IDENTITY_API_VERSION=3
EOF
		source ${TEMP_PATH}/${admin_rcfile}
		# rm -f ${admin_rcfile}
	else
		echo "install or configure keystone failed!"
	fi
}

function create_domain_projects_users_roles()
{
	openstack project create --domain default \
	  --description "Service Project" service

	openstack project create --domain default \
	  --description "Demo Project" demo

	openstack user create demo --domain default \
	  --password ${DEMO_PASS}

	openstack role create user

	openstack role add --project demo --user demo user
}

function keystone_verify()
{
	unset OS_AUTH_URL OS_PASSWORD

	openstack --os-auth-url http://controller:35357/v3 \
	  --os-project-domain-name default --os-user-domain-name default \
	  --os-project-name admin --os-username admin --os-password ${ADMIN_PASS} token issue

	openstack --os-auth-url http://controller:5000/v3 \
	  --os-project-domain-name default --os-user-domain-name default \
	  --os-project-name demo --os-username demo --os-password ${DEMO_PASS} token issue
}

function create_openrc()
{
cat > ${TEMP_PATH}/admin-openrc <<EOF
export OS_USERNAME=admin
export OS_PASSWORD=${ADMIN_PASS}
export OS_PROJECT_NAME=admin
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_DOMAIN_NAME=Default
export OS_AUTH_URL=http://${CONTROLLER_NODE_HOSTNAME}:35357/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
EOF

cat > ${TEMP_PATH}/demo-openrc <<EOF
export OS_USERNAME=demo
export OS_PASSWORD=${DEMO_PASS}
export OS_PROJECT_NAME=demo
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_DOMAIN_NAME=Default
export OS_AUTH_URL=http://${CONTROLLER_NODE_HOSTNAME}:5000/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
EOF
}

function use_scripts()
{
	source ${TEMP_PATH}/demo-openrc
	openstack token issue

	source ${TEMP_PATH}/admin-openrc
	openstack token issue
}

if [[ -f ${TOP_PATH}/scripts/functions.sh ]]
then
        source ${TOP_PATH}/scripts/functions.sh
else
        echo "ERROR: Cann't access ${TOP_PATH}/scripts/functions.sh. Exit..."
        exit 1
fi

create_database
install_configure_keystone
create_domain_projects_users_roles
keystone_verify
create_openrc
use_scripts

