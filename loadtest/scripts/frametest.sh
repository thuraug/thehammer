#!/bin/bash

pathToStorage=$1
pathToResults=$2
pathToScripts=$3

ipAddress=`ip route get 1.2.3.4 | awk '{print $7}'`
octet=${ipAddress:11:3}
if [[ `echo -n $octet | wc -c` < 3 ]]
then
	octet="0"$octet
fi

wParameters="2k 4k 90000 125000"
tParameters="4 8 12 16"

for wValue in $wParameters
do
	for tValue in $tParameters
	do 
		/etc/ansible/scripts/frametest -w ${wValue} -t ${tValue} -x ${pathToResults}/${octet}_w${wValue}t${tValue}.csv $pathToStorage
		rm -rf $pathToStorage/frame*
	done
done
