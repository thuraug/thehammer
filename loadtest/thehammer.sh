#!/bin/bash
# Written by Gabe Thurau, gabe.thurau@allianceitc.com
# This script is meant to run a full loadtest on all systems in a cluster, coalate the results, find the optimal testing parameters then fully test the entire cluster by running multiple hosts at the same time

 
### Variables ###
whoami=`whoami`
storageSystem=''
tier=''
loadType=''
units=''
resultsDirectory=''
pathToResults=''
pathToStorage=''
bs=' '
iod=' '
nj=' '
w=' '
t=' '
pathToScripts="/git_workspace/thehammer/loadtest/scripts/"
pathToAnsible="/git_workspace/thehammer/loadtest/"
runAmount="1 2 3 4 5"
temporaryFile=/tmp/tempFile.txt

### Flat File Config ###
# Create a flat config file checker to ensure that the script is running as it should
Check_Config_File ()
{
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
				exit
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
				exit
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
		elif [ "${line:0:5}" == "UNITS" ]
		then
			if [[ `echo "${line:6}" | tr '[:upper:]' '[:lower:]'` == "gbs" || `echo "${line:6}" | tr '[:upper:]' '[:lower:]'` == "mbs" ]]
			then
				units=`echo "${line:6}" | tr '[:upper:]' '[:lower:]'`
				echo $units
			else
				figlet 'ERROR'
				echo 'UNITS does not have a correct option. Please correct with either "gbs" or "mbs"'
				echo "Error is on line ${i} here: ${line}"
				exit
			fi
		fi

		if [ "$loadType" == "fio" ]
		then
			if [ ${line:0:3} == "BS" ]
			then
				bs="${line:4}"
				echo $bs
			elif [ ${line:0:4} == "IOD" ]
			then
				iod="${line:5}"
				echo $iod
			elif [ ${line:0:3} == "NJ" ]
			then
				nj="${line:4}"
				echo $nj
			fi	
		elif [ "$loadType" == "frametest" ]
		then
			if [ ${line:0:2} == "W" ]
			then
				w="${line:3}"
				echo $w
			elif [ ${line:0:2} == "T" ]
			then
				t="${line:3}"
				echo $t
			fi
		fi
	done
}

Check_Old_Results ()
{
	if [ -f ${pathToAnsible}Total_Results.txt ]
	then

		touch $temporaryFile

		ls -l ${pathToAnsible} | grep "Total_Results" > $temporaryFile 

		holder=`cat $temporaryFile`
		pathToOldResults=''

		if [ "${holder:34:1}" == " " ]
		then
			mkdir /DIST/${holder:30:3}0${holder:35:1}_HammerResults
			pathToOldResults=$resultsDirectory${holder:30:3}0${holder:35:1}_HammerResults/
		else
			mkdir $resultsDirectory${holder:30:3}${holder:34:2}_HammerResults
			pathToOldResults=$resultsDirectory${holder:30:3}${holder:34:2}_HammerResults/
		fi

		mv ${pathToAnsible}${holder:43} ${pathToOldResults}
		echo ${pathToOldResults}
		echo ${pathToAnsible}${holder:43}
	
		ls -l ${pathToAnsible} | grep "Client_" > $temporaryFile
	
		for ((i=1; i<=`wc -l < $temporaryFile`; i++))
		do
			holder=`sed -n ${i}p $temporaryFile`
			mv ${pathToAnsible}${holder:43} ${pathToOldResults}

		done


		[ -d  $pathToResults ] && mv $pathToResults ${pathToOldResults}

		for script in `ls ${pathToScripts} | grep _`
		do
			mv ${pathToScripts}${script} ${pathToOldResults}
		done

		echo $pathToResults

		echo "#####################################################"
		echo "# OLD RESULTS LOCATED IN ${pathToOldResults} #"
		echo "#####################################################"
	fi
}

### Configure Path to Storage ###
# Checks the current user inputted questions and sets the variable pathToStorage
Configure_Path_To_Storage ()
{
	if [[ $storageSystem == "gpfs" ]]
	then
		pathToStorage="/mmfs1/${tier}/${loadType}/"
	else
		pathToStorage="/vast"
	fi
}

### Configure Hosts from Sorting Algorithm ###
# Organizes the clients currently in the file Clients_Config based on the script host_sorting.sh
# *THIS IS A VERY IMPORTANT PART --> DO NOT CHANGE THE host_sorting.sh SCRIPT FOR ANY REASON (the sorting algorithm inside works to sort the hosts into all possible combinations for a base R value)
# ** There must be an /etc/ansible/hosts file on whatever system is actually running this script --> ansible must be installed as well
Configure_Hosts ()
{
	if [ `wc -l < ${pathToAnsible}Clients_Config` == 0 ]
	then
		figlet 'ERROR'
		echo "Please provide the lists of hosts you would like to test on in the ${pathToAnsible}Client_Config File"
		exit
	else
		${pathToAnsible}host_sorting.sh ${pathToAnsible}Clients_Config
	fi
	
	echo "####################"
	echo "# HOSTS CONFIGURED #"
	echo "####################"
}

### Create Results Directories ###
# Creates all the necessary directories to store all the results from the actual load testing
Create_Results_Directories ()
{
	[ ! -d ${pathToResults} ] && mkdir ${pathToResults}
	
	for (( i=1; i<=`wc -l < ${pathToAnsible}Clients_Config`; i++ ))
	do
		directory="Client_${i}"
		[ ! -d ${pathToResults}${directory} ] && mkdir ${pathToResults}${directory}
	done
	
	sed -n '/Client_/p' /etc/ansible/hosts > ${pathToAnsible}client_groups.txt

	for(( i=1; i<=`wc -l < ${pathToAnsible}client_groups.txt`; i++))
	do
		line=`sed -n ${i}p ${pathToAnsible}client_groups.txt`
		[ ! -d  "${pathToResults}${line:1:8}/${line:1:-1}" ] && mkdir "${pathToResults}${line:1:8}/${line:1:-1}"
	done 
}

### Run Ansible Host Config ###
# Runs the host_config ansible script with all needed parameters put into it to make sure that the clients are configured and set up as needed
# *For more info on the host_config script see inside that script itself 
Run_Host_Config ()
{
	ansible-playbook ${pathToAnsible}host_config.yaml --extra-vars "hosts=Clients_All pathToStorage=$pathToStorage pathToResults=$pathToResults storageSystem=$storageSystem loadType=$loadType pathToScripts=$pathToScripts"
}

### Run Ansible Single Hammer Script ###
# Runs the single_hammer ansible script with all needed parameters put into it which runs the actual load test on the remote systems
Run_Single_Hammer ()
{
	ansible-playbook ${pathToAnsible}single_hammer.yaml --extra-vars "pathToScript=$pathToScript hosts=Clients_All pathToStorage=$pathToStorage testType=$loadType pathToResults=$pathToResults systemStorage=$storageSystem w='${w}' t='${t}' bs='${bs}' iod='${iod}' nj='${nj}'"
}

### Create the Optimal Frametest Script ###
# Creates the optimal frametest script using the original frametest script and the best parameters 
Create_Frametest_Optimal ()
{
	wParameter=''
	tParameter=''
	wValue1=''
	wValue2=''
	tValue1=''
	tValue2=''
	
	cp "${pathToScripts}frametest.sh" "${pathToScripts}frametest_${ipAddress}_optimal.sh"
	
	echo $highFile
	
			
	for wi in $(seq 1 ${#highFile})
	do
	
		if [ "${highFile:$wi:1}" == "w" ]
		then
			wValue1=$[ $wi + 1]
		elif [ "${highFile:$wi:1}" == "t" ]
		then
			wValue2=$wi
			wParameter="${highFile:$wValue1:$[ wValue2 - wValue1 ]}"
		fi
	done	
	
	for ti in $(seq 1 ${#highFile})
	do
		if [ "${highFile:$ti:1}" == "t" ]
		then
			tValue1=$[ $ti + 1]
		elif [ "${highFile:$ti:1}" == "." ]
		then
			tValue2=$ti
			tParameter="${highFile:$tValue1:$[ tValue2 - tValue1 ]}"
		fi
	done
	
	sed -i '/wParameters=$w/c\wParameters='${wParameter}'' ${pathToScripts}frametest_${ipAddress}_optimal.sh
	sed -i '/tParameters=$t/c\tParameters='${tParameter}'' ${pathToScripts}frametest_${ipAddress}_optimal.sh
}

### Create the Optimal Fio Script ###
# Creates the optimal fio script using the original fio script and the best parameters
Create_Fio_Optimal ()
{
	bsParameter=''
	iodParameter=''
	njParamter=''
	bsValue1=''
	bsValue2=''
	iodValue1=''
	iodValue2=''
	njValue1=''
	njValue2=''

	cp "${pathToScripts}fio.sh" "${pathToScripts}fio_${ipAddress}_optimal.sh"

	for bsi in $(seq 1 ${#highFile})
	do
		if [ "${highFile:$bsi:2}" == "bs" ]
		then
			bsValue1=$[ $bsi + 2 ]
		elif [ "${highFile:$bsi:1}" == "i" ]
		then
			bsValue2=$bsi
			bsParameter="${highFile:$bsValue1:$[ $bsValue2 - bsValue1 ]}"
		fi
	done
	echo $bsParameter
	for iodi in $(seq 1 ${#highFile})
	do
		if [ "${highFile:$iodi:3}" == "iod" ]
		then
			iodValue1=$[ $iodi + 3 ]
		elif [ "${highFile:$iodi:1}" == "n" ] 
		then
			iodValue2=$iodi
			iodParameter="${highFile:$iodValue1:$[ iodValue2 - iodValue1 ]}"
		fi
	done
	echo $iodParameter
	for nji in $(seq 1 ${#highFile})
	do
		if [ "${highFile:$nji:2}" == "nj" ]
		then
			njValue1=$[ $nji + 2 ]
		elif [ "${highFile:$nji:1}" == "." ]
		then
			njValue2=$nji
			njParameter="${highFile:$njValue1:$[ njValue2 - njValue1 ]}"
		fi
	done
	echo $njParameter
	
	sed -i '/bsParameters=$bs/c\bsParameters='${bsParameter}'' ${pathToScripts}fio_${ipAddress}_optimal.sh
	sed -i '/iodepthParameters=$iod/c\iodepthParameters='${iodParameter}'' ${pathToScripts}fio_${ipAddress}_optimal.sh
	sed -i '/numjobsParameters=$nj/c\numjobsParameters='${njParameter}'' ${pathToScripts}fio_${ipAddress}_optimal.sh
}

### Coalate, Review, and Create Optimal ###
# Based on the loadtest that was run, the results will be coalated and reviewed so that an optimal parameter can be found based on the best bandwith found
Compare_Single_Results ()
{
	for client in `ls ${pathToResults}Client_1`
	do
		ipAddress="$client"
		fullPathToResults=${pathToResults}Client_1/${ipAddress}/
		tempFile=/tmp/temp.txt
		highNum=
		highFile=
		arrayOfValues=''
		array=''
	
		ls ${pathToResults}Client_1/$client/ > $tempFile

		for (( i=1; i<=`wc -l < ${tempFile}`; i++))
		do
			file1=`sed -n ${i}p $tempFile`

			if [ $loadType == "frametest" ]
			then
				firstNum=`sed -n 9p ${pathToResults}Client_1/${ipAddress}/${file1}`
				arrayOfValues+=${firstNum:10:-8}" " 
				array+=${firstNum:10:-8}"-${file1} "
			elif [ $loadType == "fio" ]
			then
				firstNum=`tail -1 ${fullPathToResults}${file1}`
				arrayOfValues+=${firstNum:23:4}" "
				array+=${firstNum:23:4}"-${file1} "	
			fi
		done
		
		highNum=`echo $arrayOfValues | head -n1 | awk '{print $1}'`
			
		for i in ${arrayOfValues}
		do
			if [[ "${i}" -gt "${highNum}" ]]
			then
				highNum=$i
			fi
		done
			
		length=`echo -n $highNum | wc -c`
			
		for i in $array
		do
			if [[ $highNum == ${i:0:$length} ]]
			then
				highFile=$i
				break
			fi
	
		done
	
		echo $highNum
	
		if [ $loadType == "frametest" ]
		then
			Create_Frametest_Optimal
		elif [ $loadType == "fio" ]
		then
			Create_Fio_Optimal
		fi
	done
}

### Run Optimal Test on All Systems ###
# Runs the rerun_single_hammer ansible script with all needed parameters put into it to re-run the optimal parameters test
# Still running on one system at a time, the optimal test is run 5 more times so that an average bandwith can be found for each system
Run_Single_Hammer_Again ()
{
	for ((i=1; i<=5; i++))
	do
		ansible-playbook ${pathToAnsible}rerun_single_hammer.yaml --extra-vars "hosts=Clients_All pathToScript=${pathToScripts} pathToStorage=$pathToStorage testType=$loadType pathToResults=${pathToResults} testNum=$i systemStorage=$storageSystem"
	done
}
#
### Average Results ###
# Averages the results from the optimal tests 
Average_Results ()
{
	numTotal=0
	num=0
			
	for i in $arrayOfValues
	do
		numTotal=$( echo $numTotal + $i | bc)
		num=$[ $num + 1 ]
	done
		
	numAverage=$( echo $numTotal / $num | bc)
}

### Determines the Percent Difference ###
# Determines the percent difference between the average results and the original results
Percent_Difference ()
{
	j=1
	check=$(echo "$numAverage < $originalNum" | bc -q)
	if [ $check == 1 ]
	then
		j=-1
	fi
		
	var1=$( echo "$numAverage - $originalNum" | bc )
	var2=$( echo "$numAverage + $originalNum  / 2"  | bc )
			
	percentDiff=`echo "scale=2 ; ($var1/$var2*100*$j)" | bc`
	echo "Percent Difference: "$percentDiff		
}

### Adding the Results to Flat File ###
# Adds the averaged results from the optimal tests to the flat results file 
Add_To_Results_File ()
{
	printf "\n\n\n\n######################################################\n" >> ${resultsFile}
	figlet "${ipAddress}" >> ${resultsFile}
	printf "######################################################\n" >> ${resultsFile}
	printf "\n\n" >> ${resultsFile}
	echo "The optimal setting for ${ipAddress} are: ${fileName:4:-4}" >> ${resultsFile}
	echo "The Averaged bandwith is: "$numAverage" MB/s" >> ${resultsFile}
	
}

### Check Optimal Results ###
# Checks the results from the 5 optimal parameters tests that were run
# Averages the results of the 5 tests then determines the percent difference between the original number and the average number, if less than 10% then the IP, results, and parameters are put into the Total_Results.txt file
# *WILL ADD ON THE EXCEPTION TO RERUN THE ORIGINAL AND OPTIMAL TESTS AND DETERMINE BEST BANDWITH AGAIN IF THE PERCENT DIFFERENCE IS LESS THAN 10% --> if fails a second time then the client will be removed from the continued testing and will be noted in Total_Results.txt
Check_Results ()
{
	maxPercentDifference=5

	resultsFile=/${pathToAnsible}Total_Results.txt
	touch ${pathToAnsible}Total_Results.txt

	cat /dev/null > ${pathToAnsible}Total_Results.txt

	printf "\n" >> ${resultsFile}
	figlet "RESULTS" >> ${resultsFile}
	
	for client in `ls ${pathToResults}Client_1`
	do
		percentDiff=''
		numAverage=''
		ipAddress=$client
		fullPathToResults=${pathToResults}Client_1/$ipAddress/
		tempFile=/tmp/temp.txt
		arrayOfValues=''
		originalNum=''

		touch /tmp/temp.txt

		ls ${fullPathToResults}1 > /tmp/temp.txt
		fileName=`sed -n 1p /tmp/temp.txt`
			
		for i in $runAmount
		do
			## Frametest specific
			if [ $loadType == "frametest" ]
			then
				h=`sed -n 9p "${fullPathToResults}${i}/${fileName}"`
				arrayOfValues+=${h:10:-8}" "
			elif [ $loadType == "fio" ]
			then
				## Fio Specific
				h=`tail -1 "${fullPathToResults}${i}/${fileName}"`
				arrayOfValues+=${h:23:4}" "
			fi
		done

		# Averaging the Results here
		Average_Results
	
		printf "\n\n"
		echo "Averaged Number: "$numAverage
		
		## Frametest specific
		if [ $loadType == "frametest" ]
		then
			var=`sed -n 9p "${fullPathToResults}/$fileName"`
			originalNum=${var:10:-8}
		elif [ $loadType == "fio" ]
		then
			var=`tail -1 "${fullPathToResults}/$fileName"`
			originalNum=${var:23:4}
		fi
		
		echo "Original Number: "$originalNum 
		
		# Finding the percent difference
		Percent_Difference	
	
		if [ `echo -n "${percentDiff}" | wc -c` -lt ${maxPercentDifference} ]
		then
			Add_To_Results_File
		fi
	done

	cat $resultsFile
}


###################
# TESTING SECTION #
###################



Parrallel_Run_Tests ()
{
	hostsArray=''

	for line in `cat -A /etc/ansible/hosts | grep Client_`
	do
		echo $line
		hostsArray+="${line:1:-2} "
	done

	for hostSet in $hostsArray
	do
		pathToTestResults="${pathToResults}${hostSet:0:-5}/${hostSet}/"
		echo $pathToTestResults
		#Run_Parrallel_Hammer
		Coalate_Results
	done
}

Run_Parrallel_Hammer ()
{
	for num in $runAmount
	do
		ansible-playbook ${pathToAnsible}parallel_hammer.yaml --extra-vars "hosts=${hostSet} pathToScript=${pathToScripts} pathToStorage=${pathToStorage} testType=${loadType} pathToResults=${pathToResults} testNum=${num} systemStorage=${storageSystem} clientSet=${hostSet} pathToLocalResults=${pathToTestResults}"
	done
}

Coalate_Results ()
{
	numAverage=''
	arrayOfValues=''
	resultsFile="${pathToAnsible}${hostSet}_Results.txt"
	totalResultsFile="${pathToAnsible}Total_Results.txt"
	bClientHosts=0
	numOfClients="${hostSet:8:1}"

	touch ${resultsFile}
	figlet 'RESULTS' >> $resultsFile
	


	for test in `ls $pathToTestResults`
	do
		pathToTestNum="${pathToTestResults}${test}/"
		totalBandwith=0
		bandwithArray=''
		hostnames=''
		ipAddresses='' #put the ip addresses into here (192.168.10.35 && 192.168.11.207)
		tempFile=/tmp/temp.txt
	
		printf "\n\n" >> $resultsFile
		figlet "Test Number ${test}" >> $resultsFile

		for file in `ls $pathToTestNum`
		do
			name=''
			parameters=''
			if [[ $loadType == "frametest" ]]
			then
				if [ "${bClientHosts}" != "${numOfClients}" ]
				then
					name=`sed -n 5p ${pathToTestNum}${file}`
					parameters=`sed -n 7p ${pathToTestNum}${file}`		

					hostnames+="${name:9} && "
					bClientHosts=$[ ${bClientHosts} + 1 ]
				fi

				h=`sed -n 9p "${pathToTestNum}${file}"`
				bandwithArray+=${h:10:-8}" "

				#Also add h and other information to the Client Subset Result file
					#Include Test number and individualized bandwith and the corresponding IP Address
				printf "\n" >> $resultsFile
				echo "Hostname: ${name:9}" >> $resultsFile
				echo "Individual Bandwith: ${h:10:-8} MB/s" >> $resultsFile
				echo "Parameters: ${parameters:12:-1}" >> $resultsFile

			elif [[ $loadType == "fio" ]]
			then
				if [ "${bClientHosts}" != "${numOfClients}" ]
				then
					name=`sed -n 1p ${pathToTestNum}${file}`
					parameters=`sed -n 1p ${pathToTestNum}${file}`		

					j=0
					for ((i=1; i<30; i++))
					do
						if [ "${name:$i:1}" == ":" ]
						then
							j=$i
							break
						fi
					done


					hostnames+="${name:0:$j} && "
					bClientHosts=$[ ${bClientHosts} + 1 ]
				fi
				
				h=`tail -1 "${pathToTestNum}${file}"`
				bandwithArray+=${h:23:4}" "
				

				printf "\n" >> $resultsFile
				echo "Hostname: ${name:0:$j}" >> $resultsFile
				echo "Individual Bandwith: ${h:23:4} GB/s" >> $resultsFile
				echo "Parameters: ${parameters:12}" >> $resultsFile

				#Also add h and other information to the Client Subset Result file
					#Include Test number and individualized bandwith
	
			fi
		done
	
		for value in ${bandwithArray}
		do

			# CHECK WHAT THE OVERALL UNITS WANTED??????

			if [[ "${value:2:1}" != "." || "${value:1:1}" != "." || "${value:3:1}" == "" ]] &&  [ "$units" == "gbs" ]
			then
				value=${value:0:1}.${value:1:2}
			fi

			totalBandwith=$(( echo $totalBandwith + $value  | bc ))
		done

		printf "\n\n" >> $resultsFile
		echo "Combined Bandwith for ${hostnames:0:-3}" >> $resultsFile
		echo "Combined Bandwith: $totalBandwith" >> $resultsFile
	
		# Add the totalBandwith for this test number into the Client Subset Results file
		arrayOfValues+="${totalBandwith} "
	done

	Average_Results
	

	printf "\n\n\n" >> $resultsFile
	figlet "Average Bandwith" >> $resultsFile
	echo "Averaged Bandwith: $numAverage" >> $resultsFile

	printf "\n\n" >> $totalResultsFile
	figlet "$hostSet" >> $totalResultsFile
	echo "Clients: ${hostnames:0:-3}" >> $totalResultsFile

	if [ "$loadType" == "frametest" ]
	then
		echo "Average Bandwith: ${numAverage} MB/s" >> $totalResultsFile
	elif [ "$loadType" == "fio" ]
	then
		echo "Average Bandwith: ${numAverage} GB/s" >> $totalResultsFile
	fi
}




### Remove Hosts ###
# Removes all the hosts that were added onto the /etc/ansible/hosts file to make sure everything is cleaned up as much as possible
Delete_Hosts ()
{
	startNum=''
	endNum=`wc -l < /etc/ansible/hosts`	

	for ((i=1; i<=`wc -l < /etc/ansible/hosts`; i++))
	do
		hold=`sed -n ${i}p /etc/ansible/hosts`
		if [[ ${hold} == "[Clients_All]" ]]
		then
			startNum=$i
		fi
	done

	sed -i ${startNum},${endNum}d /etc/ansible/hosts
}

### Main Executing Subroutine ### 
# This determines what functions are executed and in what order they will be executed in
Main ()
{
	Check_Config_File
#	Check_Old_Results
	Configure_Path_To_Storage
	Configure_Hosts
#	Create_Results_Directories
#	Run_Host_Config
#	Run_Single_Hammer
#	Compare_Single_Results
#	Run_Single_Hammer_Again	
	Check_Results
	Parrallel_Run_Tests

	Delete_Hosts
}

### RUN MAIN SUBROUTINE ###
Main




###################
# START OF PART 2 #
###################


# As long as the optimal tests succeeded then continue on to here
# step one is to create an array full of the the different ansible hosts that need to be run
	# this will also denote the file path that we will need to go into
	






# Create the continuous re-run ansible test each one running at the exact same time
#	How many times to run and average total results --> keep track of all this information in overall text file
# 	Put them in a folder named the same as the host set
# 	Store results in file oct_parameters_test#

# Coalate the results into one test file
#	name the text file with oct.oct.paramters
# 	inside the text file add up the bandwith results along with marking all the results individually
#	mark the parameters as well


























































	
