#!/usr/bin/env bash

set -x

function install_configure_horizon()
{
	yum -y install openstack-dashboard
	if [[ $? -eq 0 ]]
	then
cat >> /etc/openstack-dashboard/local_settings <<EOF
OPENSTACK_HOST = "${CONTROLLER_NODE_HOSTNAME}"

ALLOWED_HOSTS = ['*', ]

SESSION_ENGINE = 'django.contrib.sessions.backends.cache'

CACHES = {
    'default': {
         'BACKEND': 'django.core.cache.backends.memcached.MemcachedCache',
         'LOCATION': '${CONTROLLER_NODE_HOSTNAME}:11211',
    }
}

OPENSTACK_KEYSTONE_URL = "http://%s:5000/v3" % OPENSTACK_HOST

OPENSTACK_KEYSTONE_MULTIDOMAIN_SUPPORT = True

OPENSTACK_API_VERSIONS = {
    "identity": 3,
    "image": 2,
    "volume": 2,
}

OPENSTACK_KEYSTONE_DEFAULT_DOMAIN = "Default"

OPENSTACK_KEYSTONE_DEFAULT_ROLE = "user"

OPENSTACK_NEUTRON_NETWORK = {
    'enable_router': False,
    'enable_quotas': False,
    'enable_distributed_router': False,
    'enable_ha_router': False,
    'enable_lb': False,
    'enable_firewall': False,
    'enable_vpn': False,
    'enable_fip_topology_check': False,
}

EOF
	else
		echo "Install or configure horizon failed!"
	fi
}

function finalize_installation()
{
	systemctl restart httpd.service memcached.service
}

function set_firewall()
{
	# firewall-cmd --zone=public --add-port=80/tcp --permanen		# for dashboard
	# firewall-cmd --zone=public --add-port=6080/tcp --permanen	# for instance vnc
	# firewall-cmd --reload
	
	systemctl disable firewalld
	systemctl stop firewalld
}

if [[ -f ${TOP_PATH}/scripts/functions.sh ]]
then
        source ${TOP_PATH}/scripts/functions.sh
else
        echo "ERROR: Cann't access ${TOP_PATH}/scripts/functions.sh. Exit..."
        exit 1
fi

install_configure_horizon
finalize_installation
set_firewall

