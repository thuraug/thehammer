#!/bin/bash

Parrallel_Run_Tests ()
{
	hostsArray=''

	for line in `cat /etc/ansible/hosts | grep Client_`
	do
		hostsArray+=${line:1:-1}" "
	done

	for hostSet in $hostsarray
	do
		pathToTestResults="${pathToResults}${hostSet:0:-5}/${hostSet}/"
		Run_Parrallel_Hammer
		#Coalate_Results
	done
}

Run_Parrallel_Hammer ()
{
	for num in "1 2 3 4 5"
	do
		ansible-playbook ${pathToAnsible}parallel_hammer.yaml --extra-vars "hosts=${hostSet} pathToScript=${pathToScripts} pathToStorage=${pathToStorage} testType=${loadType} pathToResults=${pathToResults} testNum=${num} systemStorage=${storageSystem} clientSet=${hostSet} pathToLocalResults=${pathToTestResults}"
	done
}

Coalate_Results ()
{
	if [ "${loadType}" == "frametest" ]
	then
		echo "frametest"
	fi
	if [ "${loadType}" == "fio" ]
	then
		echo "fio"
	fi
}



	 	
