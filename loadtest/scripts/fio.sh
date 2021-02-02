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

bsParameters="1m 4m 8m"
iodepthParameters="8 16 32"
numjobsParameters="16 32 64"

for bsValue in $bsParameters
do
	for iodepthValue in $iodepthParameters
	do
		for numjobsValue in $numjobsParameters
		do
			fio --name=`hostname` --directory=${pathToStorage} --size=100G --direct=0 --rw=write --ioengine=libaio --bs=${bsValue} --iodepth=${iodepthValue} --numjobs=${numjobsValue} --fallocate=none > ${pathToResults}${octet}_bs${bsValue}iod${iodepthValue}nj${numjobsValue}.txt
			killall fio
			rm -rf $pathToStorage`hostname`*
		done
	done
done
