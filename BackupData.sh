#!/bin/bash

# Set the needed variables
backupDrive="/Volumes/.Backup"
backupURL="//username:password@server/share"
computerName="$(scutil --get ComputerName)"
lastUser="$(last | head -1 | cut -d\  -f1)"
serialNumber="$(system_profiler SPHardwareDataType | awk '/Serial/ {print $4}')"
sourceFolder="/Users/$lastUser"
internalIP="$(ifconfig | grep "inet " | grep -v 127.0.0.1 | cut -d\  -f2 | tr '\n' ',')"
inventoryStatus=$(curl -s "https://inventory.domain.com/admin/api.asp?Type=Backup&Serial=$serialNumber") >/dev/null 2>&1
todaysDate="$(date "+%Y%m%d")"

# Figure out what subfolder to put the data.
if [[ ${computerName:0:2} == "20" ]]; then
	backupFolder="$backupDrive/${computerName:0:4}/$lastUser/$computerName"
elif [[ ${computerName:0:2} == "HS" ]] || [[ ${computerName:0:2} == "hs" ]]; then
	backupFolder="$backupDrive/High School/$lastUser/$computerName"
elif [[ ${computerName:0:2} == "ES" ]] || [[ ${computerName:0:2} == "es" ]]; then
	backupFolder="$backupDrive/Elementary/$lastUser/$computerName"
else
	backupFolder="$backupDrive/$lastUser/$computerName"
fi

CheckBackupAuthorized()
{

	# This can be used to restrict what computers are backed up.  Set validComputer to true to backup everything.
	validComputer=false

	if [[ $computerName == "ComputerName" ]]; then
		validComputer=true
	fi

	# Check and see if the computer is authorized by the inventory system
	if [[ $inventoryStatus == "Backup" ]]; then
		validComputer=true
	fi

	if !($validComputer); then
		echo "Computer not authorized for backup..."
		exit 1
	fi

	# Use this section if you want to skip a backup on a computer for some someone.
	skipComputer=false

	if [[ $computerName == "AnotherComputerName" ]]; then
		skipComputer=true
	fi

	# Check and see if the computer is authorized by the inventory system
	if [[ $inventoryStatus == "NoBackup" ]]; then
		skipComputer=true
	fi

	if $skipComputer; then
		echo "Computer not authorized for backup..."
		exit 1
	fi

	# Use this section to prevent it from backing up a single user's data.
	skipUser=false

	if [[ $lastUser == "admin" ]]; then
		skipUser=true
	fi
	if [[ $lastUser == "Admin" ]]; then
		skipUser=true
	fi
	if [[ $lastUser == "reboot" ]]; then
		skipUser=true
	fi
	if [[ $lastUser == "_mbsetupuser" ]]; then
		skipUser=true
	fi
	if [[ $lastUser == "" ]]; then
		skipUser=true
	fi
	if $skipUser; then
		echo "User not authorized for backup..."
		exit 1
	fi

}

CheckFileIntegrity()
{

	# This will verify that the integrity files exist and are correct.
	filesGood=true

	if (test -e "$sourceFolder/Documents/zIgnoreWord.docx" ); then
		integrityTest=$(file "$sourceFolder/Documents/zIgnoreWord.docx")
		if !( [[ $integrityTest == "$sourceFolder/Documents/zIgnoreWord.docx: Microsoft Word 2007+" ]] ); then
			filesGood=false
		fi
	elif [[ $(ls "$sourceFolder/Documents/zIgnoreWord."* | wc -l) ==  *"1" ]] >/dev/null 2>&1; then
		filesGood=false
	fi

	if (test -e "$sourceFolder/Documents/zIgnoreExcel.xlsx" ); then
		integrityTest=$(file "$sourceFolder/Documents/zIgnoreExcel.xlsx")
		if !( [[ $integrityTest == "$sourceFolder/Documents/zIgnoreExcel.xlsx: Microsoft Excel 2007+" ]] ); then
			filesGood=false
		fi
	elif [[ $(ls "$sourceFolder/Documents/zIgnoreExcel."* | wc -l) ==  *"1" ]] >/dev/null 2>&1; then
		filesGood=false
	fi
	
	if (test -e "$sourceFolder/Documents/zIgnoreImage.png" ); then
		integrityTest=$(file "$sourceFolder/Documents/zIgnoreImage.png")
		if !( [[ $integrityTest == "$sourceFolder/Documents/zIgnoreImage.png: PNG image data, 1464 x 902, 8-bit/color RGBA, non-interlaced" ]] ); then
			filesGood=false
		fi
	elif [[ $(ls "$sourceFolder/Documents/zIgnoreImage."* | wc -l) ==  *"1" ]] >/dev/null 2>&1; then
		filesGood=false
	fi	

	if !($filesGood); then
		curl -s "https://inventory.domain.com/admin/api.asp?Type=AlertInfected&Serial=$serialNumber"
		echo "Computer failed integrity check..."
		exit 1
	fi

}

CheckInternalNetwork()
{
	# Do a check to see if they're on the local network, if not then exit the script.
	onLocalNetwork=false
	
	# HS Wired
	if [[ $internalIP == *"10.10."[89]* ]]; then
		onLocalNetwork=true
	fi
	if [[ $internalIP == *"10.10.1"[01]* ]]; then
		onLocalNetwork=true
	fi

	if !($onLocalNetwork); then
		echo "Unable to backup, not on local network..."
		exit 1
	fi

}

MountBackupDrive()
{

	# This will mount the backup drive.  If it fails exit the script.

	if !(test -e "$backupDrive"); then
		
		mkdir "$backupDrive"
		mount -t smbfs "$backupURL" "$backupDrive" >/dev/null 2>&1
		result=$?

		if [ "$result" -ne 0 ]; then
			rmdir "$backupDrive"
			echo "Unable to mount the backup drive..."
			exit 1
		fi
	fi

}

CreateBackupFolder()
{

	# A folder is needed for each user with a sub folder for each comptuer, if it doesn't exist it will create it.

	if !(test -e "$backupFolder"); then
		mkdir -p "$backupFolder"
	fi

}

RebuildFileIntegrity()
{

	# This will copy the files used for the file integrety check to the local users' documents folder

	cp "$backupDrive/zIgnoreWord.docx" "$sourceFolder/Documents/"
	chown $lastUser "$sourceFolder/Documents/zIgnoreWord.docx" 
	chmod 644 "$sourceFolder/Documents/zIgnoreWord.docx"
	cp "$backupDrive/zIgnoreExcel.xlsx" "$sourceFolder/Documents/"
	chown $lastUser "$sourceFolder/Documents/zIgnoreExcel.xlsx"
	chmod 644 "$sourceFolder/Documents/zIgnoreExcel.xlsx"
	cp "$backupDrive/zIgnoreImage.png" "$sourceFolder/Documents/"
	chown $lastUser "$sourceFolder/Documents/zIgnoreImage.png"
	chmod 644 "$sourceFolder/Documents/zIgnoreImage.png"

}

CheckLastBackup()
{
	
	# This will look at the date stored in LastBackup.txt to see if they've already backed up today.
	
	if (test -e "$backupFolder/LastBackup.txt"); then
		lastBackupDate="$(cat "$backupFolder/LastBackup.txt")"
		if [ "$lastBackupDate" == "$todaysDate" ]; then
			echo "Data already backed up today..."
			UnmountBackupDrive
			exit 1
		fi
	fi

}

BackupData()
{

	# This performs the backup and logs the status

	echo "Backing up $sourceFolder..."
	rsync --exclude '.DS_Store' --exclude 'Application Support/Google/Chrome' --exclude 'Library/Caches' --recursive --owner --group --times --progress "$sourceFolder/" "$backupFolder" >/dev/null 2>&1
	echo "$sourceFolder folder backed up..."
	echo "$(date) - $sourceFolder backed up to $backupFolder" >> "$backupFolder/Log.txt"
	echo $todaysDate > "$backupFolder/LastBackup.txt"

}

UnmountBackupDrive()
{

	# When we're done we want to unmount the drive.

	if (test -e "$backupDrive"); then
		umount "$backupDrive" >/dev/null 2>&1
	fi

}

CheckBackupAuthorized
CheckFileIntegrity
CheckInternalNetwork
MountBackupDrive
CreateBackupFolder
RebuildFileIntegrity
CheckLastBackup
BackupData
UnmountBackupDrive

exit 1