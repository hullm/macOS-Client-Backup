# macOS Client Backup

### Summary
BackupDate.sh is designed to backup data to a network share.  This can be run on either a single computer, or run remotely using Munki to backup a bunch of computers.

Before it backs up your data it will run through a few checks.  The first thing it will do is verify the computer is authorized to be backed up.  After that it will make sure the data you're backing up is not encrypted, or infected with Ransomware.  Then it will make sure you're on the local network.  

Once everything checks out it will mount the network share, and create the backup folder if needed.  Once it has access to the backup folder it will copy some known good files to the computers Documents folder.  These documents are used to verify data integrity on the next run.  Then it will check to see when the last back up was performed.  If the backup was performed on a previous day it will proceed with the backup.  Once complete it will log the status and unmount the drive.

---
### CheckBackupAuthorized()
You can choose what computers are authorized in the CheckBackupAuthorized section.  If you want all devices to be backed up you can comment out this section at the bottom of the script.  The first part lets you specify specific computers by name.  You can use wildcards in the section, for example, if you want all computers that start with "HS-" you can use the following code.

``` Bash
	if [[ $computerName == "HS-"* ]]; then
		validComputer=true
	fi
```

Or if you want to skip the backup on all the library computers you can use the following:

``` Bash
	if [[ $computerName == *"Library"* ]]; then
		validComputer=true
	fi
```

You can also skip computers based on their name using the same method.  After that you can skip backup for selected users.  So if you have a generic account you can skip the backup for that user.

---
### CheckFileIntegrity()
Next it will run the CheckFileIntegrity section.  This will look to see if the header on some known files has been modified.  If it has then something is wrong.  We don't know what's wrong, but to be safe we cancel the backup.  This is to make sure we don't copy bad data over good data.  The next thing it will do is if the file is missing it will see if another file with the same name, but different extension exists.  If this is the case then something has renamed the file.  This is the behavior of RansomeWare so we cancel the backup.  

---
### CheckInternalNetwork()
After the integrity check is complete it will make sure you're on the local network.  You specify the IP addresses that are unique in you're local environment.  If you have multiple ranges you can specify then in separate if statements.

``` Bash
# HS Wired
	if [[ $internalIP == *"10.10."[89]* ]]; then
		onLocalNetwork=true
	fi

# ES Wired
    if [[ $internalIP == *"10.10."10[89]* ]]; then
		onLocalNetwork=true
	fi
```

---
### MountBackupDrive()
If all checks out then mount the network drive.  If that fails then exit the script.

---
### CreateBackupFolder()
Now that we're connected we're going to make the destination folder if it doesn't already exist.  Earlier in the code we tried to figure out what subfolder to place the data.  Tweak it to your own needs.  In our case we use the computer name to sort into folders.

``` Bash
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
```
---
### RebuildFileIntegrity()
This will copy files from your network to the users Documents folder.  You can use the files included here or use your own.  If you use your own you'll need to update CheckFileIntegrity.

---
### CheckLastBackup()
When the backup finishes it will create a text file with the current date in it.  We use that file to see if a backup has already run today.  If a backup has already successfully run then we exit the script and try again another day.

---
### BackupData()
This does the work.  It run an rsync against the users profile.  It will skip some unneeded data.  Once done it will update the last run text document with the current date.

---
### UnmountBackupDrive()
When all is done we dismount form the share.  The share is designed to be hidden, and if this deployed with Munki it will be mounted as an admin so the user can't access it.