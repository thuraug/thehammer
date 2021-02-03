#!/bin/bash

loadType=''
storageSystem=''
tier=''
pathToResults=''
resultsDirectory=''
bs=''
iod=''
nj=''
w=''
t=''

for ((i=1; i<=`wc -l < Config_File.txt`; i++))
do
	line=`sed -n ${i}p Config_File.txt`
	
	if [ "${line:0:8}" == "LOADTYPE" ]
	then
		if [[ `echo "${line:9}" | tr '[:upper:]' '[:lower:]'` == "frametest" || `echo "${line:9}" | tr '[:upper:]' '[:lower:]'` == "fio" ]]
		then
			loadType=`echo ${line:9} | tr '[:upper:]' '[:lower:]'`
			echo $loadType
		else
			figlet 'ERROR'
			echo 'LOADTYPE does not have a correct option. Please correct with either "frametest" or "fio"'
			echo "Error is on line ${i} here: ${line}"
			exit
		fi
	elif [ "${line:0:11}" == "STORAGETYPE" ]
	then
		if [[ `echo "${line:12}" | tr '[:upper:]' '[:lower:]'` == "gpfs" || `echo "${line:12}" | tr '[:upper:]' '[:lower:]'` == "vast" ]]
		then
			storageSystem=`echo "${line:12}" | tr '[:upper:]' '[:lower:]'`
			echo $storageSystem
		else
			figlet 'ERROR'
			echo 'STORAGETYPE does not have a correct option. Please correct with either "gpfs" or "vast"'
			echo "Error is on line ${i} here: ${line}"
		fi
	elif [ "${line:0:4}" == "TIER" ]
	then
		if [[ `echo "${line:5}" | tr '[:lower:]' '[:upper:]'` == "NVME" || `echo "${line:5}" | tr '[:lower:]' '[:upper:]'` == "NLSAS" || `echo "${line:5}" | tr '[:lower:]' '[:upper:]'` == "SAS" ]]
		then
			tier=`echo "${line:5}" | tr '[:lower:]' '[:upper:]'`
			echo $tier
		else
			figlet 'ERROR'
			echo 'TIER does not have a correct option. Please correct with either "NVME", "NLSAS" or "SAS"'
			echo "Error is on line ${i} here: ${line}"
		fi
	elif [ "${line:0:16}" == "RESULTSDIRECTORY" ]
	then
		[ ! -d ${line:17} ] && mkdir ${line:17}

		if [ "${line: (-1)}" == "/" ]
		then
			resultsDirectory="${line:17}"
		else
			resultsDirectory="${line:17}/"
		fi

		pathToResults=${resultsDirectory}LOAD_TEST_RESULTS/
		
		echo $pathToResults
	fi

	
	if [ "$loadType" == "fio" ]
	then
		if [ ${line:0:3} == "BS" ]
		then
			bs=${line:4}
			echo $bs
		elif [ ${line:0:4} == "IOD" ]
		then
			iod=${line:5}
			echo $iod
		elif [ ${line:0:3} == "NJ" ]
		then
			nj=${line:4}
			echo $nj
		fi	
	elif [ "$loadType" == "frametest" ]
	then
		if [ ${line:0:2} == "W" ]
		then
			w=${line:3}
			echo $w
		elif [ ${line:0:2} == "T" ]
		then
			t=${line:3}
			echo $t
		fi
	fi
done 


	 	
