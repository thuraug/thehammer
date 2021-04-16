#!/bin/bash

figlet "Config File Creator"

printf "\n\n"

read -p "What Load test would you like to use? (frametest/fio) " LoadType

printf "\n\n"

read -p "Which Storage do you want to test? (gpfs/vast/nexsan/truenas) " StorageType

printf "\n\n"

if [ `echo "${StorageType}" | tr '[:upper:]' '[:lower:]'` == "gpfs" ]
then
	read -p "Which Tier of GPFS do you eant to test? (NVME/NLSAS/SAS) " TierType
	printf "\n\n"
fi

read -p "What Units do you want the results to be in? (mbs/gbs) " UnitType

printf "\n\n"

read -p "Where do you want the results to be stored? " ResultsDirectory

printf "\n\n"

if [ `echo "${LoadType}" | tr '[:upper:]' '[:lower:]'` == "frametest" ]
then
	read -p "What W Parameters for frametest do you want to use? (hit enter for default '2k 4k 90000 125000') " WParameters
	printf "\n\n"
	read -p "What T Parameters for frametest do you want to use? (hit enter for default '4 8 12 16') " TParameters
elif [ `echo "${LoadType}" | tr '[:upper:]' '[:lower:]'` == "fio" ]
then
	read -p "What BS Parameters for fio do you want to use? (hit enter for default '1m 4m 8m') " BSParameters
	printf "\n\n"
	read -p "What IOD Parameters for fio do you want to use? (hit enter for default '4 8 12 16') " IODParameters
	printf "\n\n"
	read -p "What NJ Parameters for fio do you want to use? (hit enter for default '16 32') " NJParameters
fi

printf "\n\n"

cat /dev/null > ./Config_File.txt
echo "Config File for The Hammer: " >> ./Config_File.txt
echo "LOADTYPE=${LoadType}" >> ./Config_File.txt 
echo "STORAGETYPE=${StorageType}" >> ./Config_File.txt
if [ `echo "${StorageType}" | tr '[:upper:]' '[:lower:]'` == "gpfs" ]
then
	echo "TIER=${TierType}" >> ./Config_File.txt
fi
echo "UNITS=${UnitType}" >> ./Config_File.txt
echo "RESULTSDIRECTORY=${ResultsDirectory}" >> ./Config_File.txt
echo "PARAMETERS:" >> ./Config_File.txt
if [ `echo "${LoadType}" | tr '[:upper:]' '[:lower:]'` == "frametest" ]
then
	if [ "${WParameters}" == "" ]
	then
		echo "	W=2k 4k 90000 125000" >> ./Config_File.txt
	else
		echo "	W=${WParameters}" >> ./Config_File.txt
	fi

	if [ "${TParameters}" == "" ]
	then
		echo "	T=4 8 12 16" >> ./Config_File.txt
	else
		echo "	T=${TParameters}" >> ./Config_File.txt
	fi
elif [ `echo "${LoadType}" | tr '[:upper:]' '[:lower:]'` == "fio" ]
then
	if [ "${BSParameters}" == "" ]
	then
		echo "	BS=1m 4m 8m" >> ./Config_File.txt
	else
		echo "	BS=${BSParameters}" >> ./Config_File.txt
	fi

	if [ "${IODParameters}" == "" ]
	then
		echo "	IOD=4 8 12 16" >> ./Config_File.txt
	else
		echo "	IOD=${IODParameters}" >> ./Config_File.txt
	fi

	if [ "${NJParameters}" == "" ]
	then
		echo "	NJ=16 32" >> ./Config_File.txt
	else
		echo "	NJ=${NJParameters}" >> ./Config_File.txt
	fi
fi

cat ./Config_File.txt