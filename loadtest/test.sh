#!/bin/bash



# Create a full Results file for each Client Subset
	# Add in the IP addresses, Client Host Names?, Parameters of each Client

# add up the total bandwith in each test file and add it to averaging array
	# Add info about each test to a Client Subset file
# average all the values present in the averaging array
# Create Client Subset Results file
# Add this result to the Total_Results File
# Add in the following info as well:
	# All IP addresses
	# Path to Client Subset file 
# Show results of each client (cat the results file)


#Inside of the actual hostSet


numAverage=''
arrayOfValues=''
resultsFile="${pathToAnsible}${hostSet}_Results.txt"

touch ${resultsFile}


for test in `ls $pathToTestResults`
do
	pathToTestNum="${pathToTestResults}${test}/"
	totalBandwith=''
	bandwithArray=''
	ipAddresses='' #put the ip addresses into here (192.168.10.35 && 192.168.11.207)
	tempFile=/tmp/temp.txt

	for file in `ls $pathToTestNum`
	do
		if [[ $loadType == "frametest" ]]
		then
			h=`sed -n 9p "${pathToTestNum}${file}"`
			bandwithArray+=${h:10:-8}" "

			#Also add h and other information to the Client Subset Result file
				#Include Test number and individualized bandwith and the corresponding IP Address


		elif [[ $loadType == "fio" ]]
		then
			h=`tail -1 "${pathToTestNum}${file}"`
			bandwithArray+=${h:23:4}" "

			#Also add h and other information to the Client Subset Result file
				#Include Test number and individualized bandwith

		fi
	done

	for value in ${bandwithArray}
	do
		totalBandwith=$[ $totalBandwith + $value ]
	done

	# Add the totalBandwith for this test number into the Client Subset Results file
	arrayOfValues+=${totalBandwith}
done

Average_Results

#Add the averaged combined bandwith to the Client Subset Results file 









	 	
