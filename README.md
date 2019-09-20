# macOS-Client-Backup

You can use this to back up your data to a network share.  When set up it will download a Word doc, an Excel doc, and an image to your documents folder.  It will use those files to verify the data is good before it backs up the data.  If the files are encrypted it will not back up the data.  If the extention of the files change it will not back up the data.  This is to help protect from backing up data encrypted with ransomware.  

A plist is included that can be used with Munki to automate the task of backing up your computers.

If you're running the Inventory system you can also integrate it with that to be alerted if a computer is considered infected.
