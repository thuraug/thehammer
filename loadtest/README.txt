THE HAMMER DOCUMENTATION

Written by Gabe Thurau, gabe.thurau@allianceitc.com
Last Updated April 19th, 2021



This program is a distributed loadtesting program. It will run load from a set group of client machines onto a specified storage system. 



DEPENDENCIES:
1) Share keys with all client machines (ssh-copy-id)
2) Share client keys with the master machine (ssh-copy-id)
3) Update the Config_File with any the settings needed 
4) Update Clients_Config with the IPs of all clients


RUN Create_Config_File.sh TO CREATE THE FLAT CONFIG FILE


Config_File:
The Config_File should contain this information:
	LOADTYPE= (Frametest or Fio - parameters for each listed below)
	STORAGETYPE= (gpfs nexsan, truenas, or vast)
	TIER= (NVME, NLSAS, or SAS - only for gpfs storagetype)
	UNITS= (mbs or gbs)
	RESULTSDIRECTORY= (any path to store results in - /DIST/)
	PARAMETERS:
		W= (Frametest)
		T= (Frametest)
		BS= (Fio)
		IOD= (Fio)
		NJ= (Fio)