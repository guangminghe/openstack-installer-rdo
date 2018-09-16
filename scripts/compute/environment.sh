#!/usr/bin/env bash

set -x

function set_host()
{
	hostname ${COMPUTE_NODE_HOSTNAME}
	echo "${COMPUTE_NODE_HOSTNAME}" > /etc/hostname
	sed -i -e "s/HOSTNAME=.*/HOSTNAME=${COMPUTE_NODE_HOSTNAME}/g" /etc/sysconfig/network
	sed -i -e "s/127.0.0.1.*/127.0.0.1  ${COMPUTE_NODE_HOSTNAME}  localhost/g" /etc/hosts

	if [ ! grep -q "${COMPUTE_NODE_IP}	${COMPUTE_NODE_HOSTNAME}"  /etc/hosts ]
	then
		echo "${COMPUTE_NODE_IP}	${COMPUTE_NODE_HOSTNAME}" >> /etc/hosts
	fi
}

if [[ -f ${TOP_PATH}/scripts/functions.sh ]]
then
        source ${TOP_PATH}/scripts/functions.sh
else
        echo "ERROR: Cann't access ${TOP_PATH}/scripts/functions.sh. Exit..."
        exit 1
fi

set_host
install_configure_ntp

install_configure_ntp_except_controller_node
environment_packages

