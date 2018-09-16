# openstack-installer-rdo
支持在双网卡机器上安装OpenStack的Ocata版本。

执行以下步骤：
1.安装CentOS 7.2 x86_64或者CentOS 7.3 x86_64，安装过程中选择“Web Server”组件。
2.配置网络。
	2.1 将管理网口配置成固定IP；
	2.2 配置另一个网口作为provider interface。修改网口对应的配置文件。假设网口名为INTERFACE_NAME，则修改文件/etc/sysconfig/network-scripts/ifcfg-INTERFACE_NAME，保持HWADDR和UUID不变，确认以下字段修改成对应的值：
		DEVICE=INTERFACE_NAME
		TYPE=Ethernet
		ONBOOT="yes"
		BOOTPROTO="none"
	2.3 重启网络或者重启机器
4.根据需要修改config/config.sh。
5.执行脚本：
	./main.sh allinone

