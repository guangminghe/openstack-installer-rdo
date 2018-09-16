#!/usr/bin/env bash

set -x

# check argument
# echo $#
if [ $# != 1 ] 
then
	echo "Usage: $0 NODE_TYPE"
	echo "NODE_TYPE: allinone, controller, compute"
	exit 1
fi  

NODE_TYPE=$1
export NODE_TYPE


# Keep track of the script path
TOP_PATH=$(cd $(dirname "$0") && pwd)

export TOP_PATH
echo $TOP_PATH

${TOP_PATH}/scripts/entry.sh 2>&1 | tee /var/log/openstack_installer.log
