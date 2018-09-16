#!/usr/bin/env bash

set -x

function source_config()
{
	if [[ -f ${TOP_PATH}/config/config.sh ]]
	then
		source ${TOP_PATH}/config/config.sh
	else
		echo "ERROR: Cann't access ${TOP_PATH}/config/config.sh. Exit..."
		exit 1
	fi
}

source_config

# user: execute by root
function check_current_user()
{
	id_current_user=$(id -u)

	if [[ $id_current_user -ne 0 ]]
	then
		echo "ERROR: The current user is not root. Please excute by root."
		exit 1
	fi
}

# OS: CentOS 7 x86_64
function check_os_version()
{
	check_result="false"
	if [ -f /etc/redhat-release ]
	then
		distribution=$(cut -d ' ' -f 1 /etc/redhat-release)
		echo ${distribution}
		version_number=$(cut -d ' ' -f 4 /etc/redhat-release)
		echo ${version_number}
		version_number_major=$(echo $version_number | cut -d '.' -f 1)
		echo ${version_number_major}
		version_number_minor=$(echo $version_number | cut -d '.' -f 2)
		echo ${version_number_minor}
		version=${version_number_major}.${version_number_minor}
		echo ${version}
		if [ ${distribution} = "CentOS" ]
		then
			#if [ ${version} = "7.2" ] || [ ${version} = "7.3" ]
			if [ ${version_number_major} = "7" ]
			then
				check_result="true"
			fi
		fi
	fi

	if [ ${check_result} = "false" ]
	then
		echo "Please use CentOS 7.2 x86_64 or CentOS 7.3 x86_64."
		exit 1
	fi
}

# configure file: configure file config.sh must exist
function check_config_file()
{
	if [ ! -f config/config.sh ]
	then
		echo "Config file config/config.sh is not exist."
		exit -1
	fi
}

# Requirements
# 1. user: execute by root
# 2. OS: CentOS 7 x86_64
# 3. configure file: configure file config.sh must exist
function check_env()
{
	check_current_user
	check_os_version
	check_config_file
}

function install_configure_ntp_except_controller_node()
{
	yum -y install chrony
	if [[ $? -eq 0 ]]
	then
		sed -i '/server/d' /etc/chrony.conf
		echo "server ${CONTROLLER_NODE_HOSTNAME} iburst" >> /etc/chrony.conf
		systemctl enable chronyd.service
		systemctl start chronyd.service
	fi
}

function environment_packages()
{
	yum -y install centos-release-openstack-ocata
	yum -y upgrade
	yum -y install python-openstackclient
	yum -y install openstack-selinux

	yum -y install crudini
}

function add_compute_node_to_cell_database()
{
	source ${TEMP_PATH}/admin-openrc

	openstack hypervisor list

	su -s /bin/sh -c "nova-manage cell_v2 discover_hosts --verbose" nova

	crudini --set /etc/nova/nova.conf scheduler discover_hosts_in_cells_interval 300

}

function set_auto_discover_hosts()
{
	crudini --set /etc/nova/nova.conf scheduler discover_hosts_in_cells_interval 300
}

function verify_nova()
{
	source ${TEMP_PATH}/admin-openrc

	openstack compute service list

	openstack catalog list

	openstack image list

	nova-status upgrade check
}

function verify_neutron()
{
	source ${TEMP_PATH}/admin-openrc

	openstack extension list --network

	openstack network agent list
}

function install_allinone()
{
	${TOP_PATH}/scripts/controller/environment.sh
	
	${TOP_PATH}/scripts/controller/install_keystone.sh
	
	${TOP_PATH}/scripts/controller/install_glance.sh
	
	${TOP_PATH}/scripts/controller/install_nova.sh
	${TOP_PATH}/scripts/allinone/install_nova_compute.sh
	add_compute_node_to_cell_database
	verify_nova
	
	${TOP_PATH}/scripts/controller/install_neutron.sh
	${TOP_PATH}/scripts/allinone/install_neutron_compute.sh
	verify_neutron
	
	${TOP_PATH}/scripts/controller/install_horizon.sh
}

function install_allinone_stepbystep()
{
cat << EOF
========== Please enter your choise: (1~6) ==========
1) Set Install Environment
2) Install Keystone
3) Install Glance
4) Install Nova
5) Install Neutron
6) Install Horizon
0) Exit
EOF
	read -p "Please input a number for install: " number
	case ${number} in
		1)
			${TOP_PATH}/scripts/controller/environment.sh
			install_allinone_stepbystep
		;;
		2)
			${TOP_PATH}/scripts/controller/install_keystone.sh
			install_allinone_stepbystep
		;;
		3)
			${TOP_PATH}/scripts/controller/install_glance.sh
			install_allinone_stepbystep
		;;
		4)
			${TOP_PATH}/scripts/controller/install_nova.sh
			${TOP_PATH}/scripts/allinone/install_nova_compute.sh
			add_compute_node_to_cell_database
			verify_nova
			install_allinone_stepbystep
		;;
		5)
			${TOP_PATH}/scripts/controller/install_neutron.sh
			${TOP_PATH}/scripts/allinone/install_neutron_compute.sh
			verify_neutron
			install_allinone_stepbystep
		;;
		6)
			${TOP_PATH}/scripts/controller/install_horizon.sh
			install_allinone_stepbystep
		;;
		0)
			exit 0
		;;
		*)
			echo "Please input a number between 0 to 6."
			install_allinone_stepbystep
		;;
	esac
}

function install_controller()
{
	${TOP_PATH}/scripts/controller/environment.sh
	${TOP_PATH}/scripts/controller/install_keystone.sh
	${TOP_PATH}/scripts/controller/install_glance.sh
	${TOP_PATH}/scripts/controller/install_nova.sh
	set_auto_discover_hosts
	${TOP_PATH}/scripts/controller/install_neutron.sh
	${TOP_PATH}/scripts/controller/install_horizon.sh
}

function install_compute()
{
	${TOP_PATH}/scripts/compute/environment.sh
	${TOP_PATH}/scripts/compute/install_nova.sh
	${TOP_PATH}/scripts/compute/install_neutron.sh
}

