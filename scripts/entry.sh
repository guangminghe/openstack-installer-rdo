#!/usr/bin/env bash

set -x

# Requirements
# 1. user: execute by root
# 2. OS: CentOS 7 x86_64
# 3. configure file: configure file config.sh must exist

if [[ -f ${TOP_PATH}/scripts/functions.sh ]]
then
	source ${TOP_PATH}/scripts/functions.sh
else
	echo "ERROR: Cann't access ${TOP_PATH}/scripts/functions.sh. Exit..."
	exit 1
fi

TEMP_PATH=${TOP_PATH}/../openstack_installer_temp

if [[ -d ${TEMP_PATH} ]]
then
	echo "${TEMP_PATH} is exist."
else
	mkdir -p ${TEMP_PATH}
fi
mkdir -p ${TEMP_PATH}

echo "NODE_TYPE: ${NODE_TYPE}"

function main()
{
	check_env
	
	case ${NODE_TYPE} in
		allinone)
			install_allinone
			# install_allinone_stepbystep
			;;
		controller)
			install_controller
			;;
		compute)
			install_compute
			;;
		*)
			echo "Usage: $0 NODE_TYPE"
			echo "NODE_TYPE: allinone, controller, compute"
			exit 1
	esac
}

main
