#!/bin/bash

loadType=''

for ((i=1; i<=`wc -l < Config_File.txt`; i++))
do
	line=`sed -n ${i}p Config_File.txt`
	
	case $line in
		"${line:0:8}" == "LOADTYPE")
			echo ${line:9}
			;;
		loadType=${line:9}
		"${line:0:11}" == "STORAGETYPE")
			echo ${line:12}
			;;
		"${line:0:4}" == "TIER")
			echo ${line:5}
			;;
		"${line:0:16}" == "RESULTSDIRECTORY")
			echo ${line:17}
			;;
	esac

	
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


	 	
