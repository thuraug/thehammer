#!/bin/bash

# I WANT TO DIE 

### variables ###
whoami=`whoami`
storageSystem=
tier=
loadType=
pathToResults="/DIST/LOAD_TEST_RESULTS/"
pathToStorage=''
pathToScripts="/ansible/loadtest/scripts/"
pathToAnsible="/ansible/loadtest/"

usage ()
{
	echo
	echo "This script is used to test a list of systems as specified in /etc/ansible/loadtest/Clients_Config"
	echo "There is a choice to use either fio or frametest on either GPFS or Vast storage"
	echo " Usage: echo `basename $0` [-h|-help]"
		echo " -h | show the help menu"
		echo " -G | GPFS Storage"
		echo " -V | Vast Storage"
		echo "-Nv | NVME Tier -- this flag must be used with the '-G' flag"
		echo "-Nl | NLSAS Tier -- this flag must be used with the '-G' flag" 
		echo " -S | SAS Tier -- this flag must be used with the '-G' flag" 
		echo "-Fr | frametest load testing"
		echo "-Fi | fio load testing"
}

### Check Flags ###
#if [ $# -gt 0 ]
#then
#	{
#		case "{$1}" in
#			-[h] )
#				usage
#				;;
#			-[G] )
#				storageSystem="gpfs"
#				;;
#			-[V] )
#				storageSystem="vast"
#				;;
#			* )
#				usage
#				;;
#		esac
#		case "{$2}" in
#			-[Nv] )
#				tier="NVME"
#				;;
#			-[Nl] )
#				tier="NLSAS"
#				;;
#
#			-[S] )
#				tier="SAS"
#				;;
#			* )
#				usage
#				;;
#		esac
#		case "{$3}" in
#			-[Fr] )
#				loadType="frametest"
#				;;
#			-[Fi] )
#				loadType="fio"
#				;;
#			* )
#				usage
#				;;
#		esac
#	}
#fi

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


# Step 0: Check requirements
	### MAKE THESE FLAGS ###
	# what type of storage --> for GPFS also ask for tiers
	# what type of test

Configure_Path_To_Storage ()
{
	if [[ $storageSystem == "gpfs" ]]
	then
		pathToStorage="/mmfs1/${tier}/${loadType}/"
	else
		pathToStorage="/vast"
	fi
	
}

# Step 1: Configure the Host List in /etc/ansible hosts

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

# Step 2: Configure LocalHost directories
	#/DIST/LOAD_TEST_RESULTS/Client_2/Client_2_set1

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

# Step 3: Configure Remote Systems for testing
	# Check to make sure storage is mounted
	# Check to make sure folder for loadtest is made /mmfs1/NVME/frametest/$HOSTNAME
	# Prepare Results directory
	# Send scripts over to remote hosts
	# Make sure frametest and fio are on remote systems


Run_Host_Config ()
{
	ansible-playbook ${pathToAnsible}host_config.yaml --extra-vars "hosts=Clients_All pathToStorage=$pathToStorage pathToResults=$pathToResults storageSystem=$storageSystem loadType=$loadType pathToScripts=$pathToScripts"
 echo "Storage System: " $storageSystem
}




# Step 3: execute load script
	### MAKE SURE LOADTEST SCRIPTS ARE MADE ###
	# Execute load shell script
	# send results back to localhost

Run_Single_Hammer ()
{
	echo "Storage System: "$storageSystem
	ansible-playbook ${pathToAnsible}single_hammer.yaml --extra-vars "pathToScript=$pathToScript hosts=Clients_All pathToStorage=$pathToStorage testType=$loadType pathToResults=$pathToResults systemStorage=$storageSystem"
}

	

# Step 4: Coalate and Review Results of load tests

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





# Step 6: Re-run the load test using optimal versions to make sure that they are the best version
	# (+/-) 5% difference

Run_Single_Hammer_Again ()
{
	for ((i=1; i<=5; i++))
	do
		ansible-playbook ${pathToAnsible}rerun_single_hammer.yaml --extra-vars "hosts=Clients_All pathToScript=${pathToScripts} pathToStorage=$pathToStorage testType=$loadType pathToResults=${pathToResults} testNum=$i systemStorage=$storageSystem"
		echo "Storage System: "$storageSystem
	done
}


# Step 7: if it is good then load that as the "ultimate optimal version to be used for all other tests (with +/- the parameters )

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

# Step 8: remove all hosts from /etc/ansible/hosts

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


























































	
