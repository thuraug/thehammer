#!/bin/bash

loadType=''

for ((i=1; i<=`wc -l < Config_File.txt`; i++))
do
	line=`sed -n ${i}p Config_File.txt`
	
	if [ "${line:0:8}" == "LOADTYPE" ]
	then
		echo ${line:9}
		if [[ `echo "${line:9}" | tr '[:upper:]' '[:lower:]'` == "frametest" || `echo "${line:9}" | tr '[:upper:]' '[:lower:]'` == "fio" ]]
		then
			loadType=${line:9}
		fi
	elif [ "${line:0:11}" == "STORAGETYPE" ]
	then
		echo ${line:12}
	elif [ "${line:0:4}" == "TIER" ]
	then
		echo ${line:5}
	elif [ "${line:0:16}" == "RESULTSDIRECTORY" ]
	then
		echo ${line:17}
	fi

	
	if [ "$loadType" == "fio" ]
	then
		if [ ${line:0:3} == "BS" ]
		then
			echo ${line:4}
		elif [ ${line:0:4} == "IOD" ]
		then
			echo ${line:5}
		elif [ ${line:0:3} == "NJ" ]
		then
			echo ${line:4}
		fi	
	elif [ "$loadType" == "frametest" ]
	then
		echo no
	fi
done 


	 	
