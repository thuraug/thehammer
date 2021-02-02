#!/bin/bash
# Written by Gabe Thurau, gabe.thurau@allianceitc.com
# This script is meant to run a full loadtest on all systems in a cluster, coalate the results, find the optimal testing parameters then fully test the entire cluster by running multiple hosts at the same time

 
### Variables ###
whoami=`whoami`
storageSystem=
tier=
loadType=
pathToResults="/DIST/LOAD_TEST_RESULTS/"
pathToStorage=''
pathToScripts="/ansible/loadtest/scripts/"
pathToAnsible="/ansible/loadtest/"

### Flat File Config ###
# Create a flat config file checker to ensure that the script is running as it should






### Ask Questions of User ###
# *Not a permanent solution -- only used for testing
Ask_Questions ()
{
	read -p "What type of storage?" storageSystem
	if [ $storageSystem == "gpfs" ]
	then
		read -p "What tier you on?" tier
	fi
	read -p "What load test?" loadType

	echo "Storage System: " $storageSystem
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
		echo "Please provide the lists of hosts you would like to test on in the ${pathToAnsible}Client_Config File"
		exit
	else
		${pathToAnsible}host_sorting.sh	
	fi
	
	echo "####################"
	echo "# HOSTS CONFIGURED #"
	echo "####################"
}

### Create Results Directories ###
# Creates all the necessary directories to store all the results from the actual load testing
Create_Results_Directories ()
{
	[ ! -d /DIST ] && mkdir /DIST
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
 echo "Storage System: " $storageSystem
}

### Run Ansible Single Hammer Script ###
# Runs the single_hammer ansible script with all needed parameters put into it which runs the actual load test on the remote systems
Run_Single_Hammer ()
{
	echo "Storage System: "$storageSystem
	ansible-playbook ${pathToAnsible}single_hammer.yaml --extra-vars "pathToScript=$pathToScript hosts=Clients_All pathToStorage=$pathToStorage testType=$loadType pathToResults=$pathToResults systemStorage=$storageSystem"
}

	

# Step 4: Coalate and Review Results of load tests


### Coalate, Review, and Create Optimal ###
# Based on the loadtest that was run, the results will be coalated and reviewed so that an optimal parameter can be found based on the best bandwith found
Compare_Single_Results ()
{
	if [ $loadType == "frametest" ]
	then
	 	for client in `ls ${pathToResults}Client_1`
		do
			ipAddress="$client"
			fullPathToResults=${pathToResults}Client_1/${ipAddress}/
			tempFile=/tmp/temp.txt
			highNum=
			highFile=
			comparingArray=''
			array=''
	
			ls ${pathToResults}Client_1/$client/ > $tempFile
			
			for (( i=1; i<=`wc -l < ${tempFile}`; i++))
			do
				file1=`sed -n ${i}p $tempFile`
				firstNum=`sed -n 9p ${pathToResults}Client_1/${ipAddress}/${file1}`
				echo $firstNum
				comparingArray+=${firstNum:10:-8}" " 
				array+=${firstNum:10:-8}"-${file1} "
			done
		
			highNum=`echo $comparingArray | head -n1 | awk '{print $1}'`
			
			for i in ${comparingArray}
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
				fi
	
			done
	
		echo $highNum
	
		wParameter=''
		tParameter=''
		wValue1=''
		wValue2=''
		tValue1=''
		tValue2=''
	
		cp "${pathToScripts}frametest.sh" "${pathToScripts}frametest_${ipAddress}_optimal.sh"
	
		echo $highFile
	
		for w in $(seq 1 ${#highFile})
		do
	
			if [ "${highFile:$w:1}" == "w" ]
			then
				wValue1=$[ $w + 1]
			fi
			if [ "${highFile:$w:1}" == "t" ]
			then
				wValue2=$w
				wParameter="${highFile:$wValue1:$[ wValue2 - wValue1 ]}"
			fi
		done	
	
		for t in $(seq 1 ${#highFile})
		do
			if [ "${highFile:$t:1}" == "t" ]
			then
				tValue1=$[ $t + 1]
			fi
			if [ "${highFile:$t:1}" == "." ]
			then
				tValue2=$t
				tParameter="${highFile:$tValue1:$[ tValue2 - tValue1 ]}"
			fi
		done
	
		sed -i '/wParameters="2k 4k 90000 125000"/c\wParameters='${wParameter}'' ${pathToScripts}frametest_${ipAddress}_optimal.sh
		sed -i '/tParameters="4 8 12 16"/c\tParameters='${tParameter}'' ${pathToScripts}frametest_${ipAddress}_optimal.sh


		done
	fi

	if [ $loadType == "fio" ]
	then
		
		for client in `ls ${pathToResults}Client_1`
		do
			ipAddress=$client
			fullPathToResults=${pathToResults}Client_1/$ipAddress/
			tempFile=/tmp/temp.txt
			arrayOfValues=''
			highNum=
			highFile=
			array=''
	
			touch /tmp/temp.txt

			ls ${fullPathToResults} > $tempFile

			for (( i=1; i<=`wc -l < ${tempFile}`; i++))
			do
				file1=`sed -n ${i}p ${tempFile}`
				firstNum=`tail -1 ${fullPathToResults}${file1}`

				arrayOfValues+=${firstNum:23:4}" "
				array+=${firstNum:23:4}"-${file1} "	
			done

			highNum=`echo $arrayOfValues | head -n1 | awk '{print $1}'`

			for i in ${arrayOfValues}
			do
				if (( $(echo "$i" > "$highNum" | bc  ) ))
				then
					highNum=$i
				fi
			done
		
			echo $highNum
			length=`echo -n $highNum | wc -c`
	
			for i in $array
			do
				if [[ $highNum == ${i:0:$length} ]]
				then
					highFile=$i
					break
				fi
			done
	
			echo $highFile

			bsParameter=''
			iodParameter=''
			njParamter=''
			bsValue1=''
			bsValue2=''
			iodValue1=''
			iodValue2=''
			njValue1=''
			njValue2=''

			cp /ansible/loadtest/scripts/fio.sh /ansible/loadtest/scripts/fio_${ipAddress}_optimal.sh

			for bs in $(seq 1 ${#highFile})
			do
				if [ "${highFile:$bs:2}" == "bs" ]
				then
					bsValue1=$[ $bs + 2 ]
				fi
				if [ "${highFile:$bs:1}" == "i" ]
				then
					bsValue2=$bs
					bsParameter="${highFile:$bsValue1:$[ $bsValue2 - bsValue1 ]}"
				fi
			done
			echo $bsParameter
			for iod in $(seq 1 ${#highFile})
			do
				if [ "${highFile:$iod:3}" == "iod" ]
				then
					iodValue1=$[ $iod + 3 ]
				fi
				if [ "${highFile:$iod:1}" == "n" ] 
				then
					iodValue2=$iod
					iodParameter="${highFile:$iodValue1:$[ iodValue2 - iodValue1 ]}"
				fi
			done
			echo $iodParameter
			for nj in $(seq 1 ${#highFile})
			do
				if [ "${highFile:$nj:2}" == "nj" ]
				then
					njValue1=$[ $nj + 2 ]
				fi
				if [ "${highFile:$nj:1}" == "." ]
					then
				njValue2=$nj
						njParameter="${highFile:$njValue1:$[ njValue2 - njValue1 ]}"
				fi
			done
			echo $njParameter
	
	
			sed -i '/bsParameters="1m"/c\bsParameters='${bsParameter}'' /ansible/loadtest/scripts/fio_${ipAddress}_optimal.sh
			sed -i '/iodepthParameters="8 16 32"/c\iodepthParameters='${iodParameter}'' /ansible/loadtest/scripts/fio_${ipAddress}_optimal.sh
			sed -i '/numjobsParameters="16 32 64"/c\numjobsParameters='${njParameter}'' /ansible/loadtest/scripts/fio_${ipAddress}_optimal.sh
	
		done	
	fi
}

### Run Optimal Test on All Systems ###
# Runs the rerun_single_hammer ansible script with all needed parameters put into it to re-run the optimal parameters test
# Still running on one system at a time, the optimal test is run 5 more times so that an average bandwith can be found for each system
Run_Single_Hammer_Again ()
{
	for ((i=1; i<=5; i++))
	do
		ansible-playbook ${pathToAnsible}rerun_single_hammer.yaml --extra-vars "hosts=Clients_All pathToScript=${pathToScripts} pathToStorage=$pathToStorage testType=$loadType pathToResults=${pathToResults} testNum=$i systemStorage=$storageSystem"
		echo "Storage System: "$storageSystem
	done
}

### Check Optimal Results ###
# Checks the results from the 5 optimal parameters tests that were run
# Averages the results of the 5 tests then determines the percent difference between the original number and the average number, if less than 10% then the IP, results, and parameters are put into the Total_Results.txt file
# *WILL ADD ON THE EXCEPTION TO RERUN THE ORIGINAL AND OPTIMAL TESTS AND DETERMINE BEST BANDWITH AGAIN IF THE PERCENT DIFFERENCE IS LESS THAN 10% --> if fails a second time then the client will be removed from the continued testing and will be noted in Total_Results.txt
Check_Results ()
{
	resultsFile=/${pathToAnsible}Total_Results.txt

	touch ${pathToAnsible}Total_Results.txt

	cat /dev/null > ${pathToAnsible}Total_Results.txt	

	printf "\n" >> ${resultsFile}
	figlet "RESULTS" >> ${resultsFile}
	
	if [ $loadType == "frametest" ]
	then	
		for client in `ls ${pathToResults}Client_1`
		do
			ipAddress=$client
			fullPathToResults=${pathToResults}Client_1/$ipAddress/
			tempFile=/tmp/temp.txt
			arrayOfValues=''
			
			touch /tmp/temp.txt
		
			ls ${fullPathToResults}1 > /tmp/temp.txt
			fileName=`sed -n 1p /tmp/temp.txt`
			
			listOfNums='1 2 3 4 5'

			
			for i in $listOfNums
			do
				h=`sed -n 9p "${fullPathToResults}${i}/${fileName}"`
				
				arrayOfValues+=${h:10:-8}" "
				
			done
			
			numTotal=0
			num=0
			
			for i in $arrayOfValues
			do
				numTotal=$[ $numTotal + $i ]
				num=$[ $num + 1 ]
			done
		
			numAverage=$[ $numTotal / $num ]
			
			printf "\n\n"
			echo "Averaged Number: "$numAverage
			
			var=`sed -n 9p "${fullPathToResults}/$fileName"`
			originalNum=${var:10:-8}
		
			echo "Original Number: "$originalNum 
		
			j=1
			if [ "$numAverage" -lt "$originalNum" ]
			then
				j=-1
			fi
		
			var1=$[ $[ $numAverage - $originalNum ] ]
			var2=$[ $[ $numAverage + $originalNum ] / 2 ]
			
			percentDiff=`echo "scale=2 ; ($var1/$var2*100*$j)" | bc`
			echo "Percent Difference: "$percentDiff		
		
			if [ `echo -n "${percentDiff}" | wc -c` -lt 5 ]
			then
				
				printf "\n\n\n\n######################################################\n" >> ${resultsFile}
				figlet "${ipAddress}" >> ${resultsFile}
				printf "######################################################\n" >> ${resultsFile}
				printf "\n\n" >> ${resultsFile}
				echo "The optimal setting for ${ipAddress} are: ${fileName:4:-4}" >> ${resultsFile}
				echo "The Averaged bandwith is: "$numAverage" MB/s" >> ${resultsFile}
			fi
		done
	fi
	if [ $loadType == "fio" ]
	then
	
		for client in `ls ${pathToResults}Client_1`
		do
			ipAddress=$client
			fullPathToResults=${pathToResults}Client_1/$ipAddress/
			tempFile=/tmp/temp.txt
			arrayOfValues=''

			touch $tempFile

			ls ${fullPathToResults}1 > ${tempFile}
			filename=`sed -n 1p $tempFile`

			listOfNums='1 2 3 4 5'
	
			for i in $listOfNums
			do
				h=`tail -1 "${fullPathToResults}${i}/${filename}"`
				arrayOfValues+=${h:23:4}" "
			done

			numTotal=0
			num=0

			for i in $arrayOfValues
			do
				numTotal=$( echo $numTotal + $i | bc )
				num=$[ $num + 1 ]
			done

			numAverage=$( echo $numTotal / $num | bc )

			printf "\n\n"
			echo "Average Number: "$numAverage

			var=`tail -1 ${fullPathToResults}$filename`
			originalNum=${var:23:4}
	
			echo "Original Number: "$originalNum

			j=1
			if (( $(echo "$numAverage" < "$originalNum" | bc ) ))
			then
				j=-1
			fi
	
			var1=$(echo  "$numAverage" - "$originalNum" | bc )
			var2=$( echo $( echo "$numAverage" + "$originalNum" | bc ) / 2 | bc)

			percentDiff=`echo "($var1 / $var2 * 100 * $j)" | bc `
			echo $percentDiff

			percent="5.0"

			if [ `echo -n "${percentDiff}" | wc -c` -lt 5 ]
			then
				printf "\n\n\n\n##########################################\n" >> ${resultsFile}
				figlet "${ipAddress}" >> ${resultsFile}
				printf "##########################################\n" >> ${resultsFile}
				printf "\n\n" >> ${resultsFile}
				echo "The optimal setting for ${ipAddress} are: ${filename:4:-4}" >> ${resultsFile}
				echo "The average bandwith is: "$numAverage" GB/s" >> ${resultsFile}
			fi
		done
	fi

	cat $resultsFile
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
	Ask_Questions
	Configure_Path_To_Storage
	Configure_Hosts
	Create_Results_Directories
	Run_Host_Config
	Run_Single_Hammer
	Compare_Single_Results
	Run_Single_Hammer_Again	
	Check_Results

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


























































	
