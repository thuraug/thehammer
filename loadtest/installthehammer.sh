#!/bin/bash

currentDirectory=`pwd`/
installAnsible="y"

# Check if ansible is installed
if [ -x "$(command -v ansible)" ]
then
	echo "Ansible is installed and all set"
else
	echo "Ansible is not installed"
	read -p "Do you want to install ansible? (y/n) " installAnsible
fi

if [[ -x "$(command -v ansible)" && "${installAnsible}" == "y" ]]
then
	yum install Ansible
else
	printf "\n"
	echo "Ansible must be installed to run The Hammer. Please install it before continuing"
	echo "Run:"
	echo "		sudo yum install ansible"
	exit 1
fi

[ -d "/etc/thehammer" ] || mkdir /etc/thehammer
printf "\n\n"
echo "thehammer and all subsequent files will exist in /etc/thehammer/"

mv ${currentDirectory}* /etc/thehammer/

if [ -f "/usr/local/bin/thehammer" ]
then
	rm -rf /usr/local/bin/thehammer
	printf "\n\n"
	echo "Removed older thehammer script"
fi

ln -s /etc/thehammer/thehammer.sh /usr/local/bin/thehammer

chmod 755 /etc/thehammer/Create_Config_File.sh
chmod 755 /etc/thehammer/host_sorting.sh
chmod 755 ${currentDirectory}scripts/frametest

printf "\n\n"
cat /etc/thehammer/README.txt
