#!/bin/bash

hostsArray=''


for line in `cat /etc/ansible/hosts | grep Client_`
do
	hostsArray+=${line:1:-1}" "
done

echo $hostsArray

for hostSet in $hostsArray
do
	pathToTestResults="/DIST/LOAD_TEST_RESULTS/${hostSet:0:-5}/${hostSet}/"
	echo $hostSet
	echo $pathToTestResults
	
	echo "RUN ANSIBLE SCRIPTS"
	for num in "1 2 3 4 5"
	do
		ansible-playbook ${pathToAnsible}parallel_hammer.yaml --extra-vars "hosts=${hostSet} pathToScript=${pathToScripts} pathToStorage=${pathToStorage} testType=${loadType} pathToResults=${pathToResults} testNum=${num} systemStorage=${storageSystem} clientSet=${hostSet} pathToLocalResults=${pathToTestResults}"	
	done


	echo "COALATE AND PRESENT RESULTS"

	if [ "${loadType}" == "frametest" ]
	then
		echo "frametest"
	fi
	if [ "${loadType}" == "fio" ]
	then
		echo "fio"
	fi
done
