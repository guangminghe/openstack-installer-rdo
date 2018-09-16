#!/usr/bin/env bash

set -x

function set_host()
{
	hostname ${CONTROLLER_NODE_HOSTNAME}
	echo "${CONTROLLER_NODE_HOSTNAME}" > /etc/hostname
	sed -i -e "s/HOSTNAME=.*/HOSTNAME=${CONTROLLER_NODE_HOSTNAME}/g" /etc/sysconfig/network
	sed -i -e "s/127.0.0.1.*/127.0.0.1  ${CONTROLLER_NODE_HOSTNAME}  localhost/g" /etc/hosts

	if [ ! $(grep -q "${CONTROLLER_NODE_IP}	${CONTROLLER_NODE_HOSTNAME}"  /etc/hosts) ]
	then
		echo "${CONTROLLER_NODE_IP}	${CONTROLLER_NODE_HOSTNAME}" >> /etc/hosts
	fi
}

function install_configure_ntp()
{
	yum -y install chrony
	if [[ $? -eq 0 ]]
	then
		sed -i '/server/d' /etc/chrony.conf
		for ntp_server in ${NTP_SERVERS}
		do
			echo "server ${ntp_server} iburst" >> /etc/chrony.conf
		done
		# sed -i '/allow/d' /etc/chrony.conf
		echo "allow ${SUBNET} iburst" >> /etc/chrony.conf
		systemctl enable chronyd.service
		systemctl start chronyd.service
	else
		echo "install chrony failed!"
	fi
}

function install_configure_db()
{
	yum -y install mariadb mariadb-server python2-PyMySQL
	if [[ $? -eq 0 ]]
	then
		# echo "CONTROLLER_NODE_IP: ${CONTROLLER_NODE_IP}"	
cat > /etc/my.cnf.d/openstack.cnf <<EOF
[mysqld]
bind-address = ${CONTROLLER_NODE_IP}

default-storage-engine = innodb
innodb_file_per_table = on
max_connections = 4096
collation-server = utf8_general_ci
character-set-server = utf8
EOF
		systemctl enable mariadb.service
		systemctl start mariadb.service
		echo "DB_PASS: ${DB_PASS}"	
        echo -e "\nY\n${DB_PASS}\n${DB_PASS}\nY\nn\nY\nY\n" | mysql_secure_installation
	else
		echo "install db failed!"
	fi
}

function install_configure_mq()
{
	yum -y install rabbitmq-server
	if [[ $? -eq 0 ]]
	then
		systemctl enable rabbitmq-server.service
		systemctl start rabbitmq-server.service
		rabbitmqctl add_user openstack ${RABBIT_PASS} -n rabbit@${CONTROLLER_NODE_HOSTNAME}
		rabbitmqctl set_permissions openstack ".*" ".*" ".*" -n rabbit@${CONTROLLER_NODE_HOSTNAME}
		echo "install or configure mq successful!"
	else
		echo "install or configure mq failed!"
	fi
}

function install_configure_memcached()
{
	yum -y install memcached python-memcached
	if [[ $? -eq 0 ]]
	then
        crudini --set /etc/sysconfig/memcached DEFAULT OPTIONS "-l 127.0.0.1,::1,${CONTROLLER_NODE_HOSTNAME}"
	systemctl enable memcached.service
	systemctl start memcached.service
	else
		echo "install or configure memcached failed!"
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

environment_packages

install_configure_db
install_configure_mq

install_configure_memcached

