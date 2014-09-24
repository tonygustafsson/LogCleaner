#Description

This LogCleaner can compress and delete aged log files. You can decide which paths to clean, and what to do
with these files. Different settings can be set to different paths.
It uses 7zip because it's able to use compression level, which is set to 1 as a default, which really speed things up.

#Installation

1. Copy all files in this directory to the server you want this LogCleaner on
2. Run deploy_cleaner.bat with admin privileges, follow the instructions.
3. The configuration will popup in notepad, make the changes that is needed.
4. Run the scheduled task that is created, verify that it works by looking at the LogCleaners own log files.

#Configuration variables

```
<config>
	<clean>:						One per of these per clean job
		<path>:						The absolut path to the directory to clean
		<archivePath>:				If empty, the script will store the zip file in the same path as the original file.
									Or you can specify an absolute path, or a relative path to the original file.
		<zipIncludeFilePattern>:	Which files to be zipped. Probably a file suffix, like *.txt, or * for everything. One or multiple instances.
		<zipExcludeFilePattern>:	Which files NOT to be zipped. Probably a file suffix, like *.zip, or left empty. One or multiple instances.
									Excluding is only used if the zipIncludeFilePattern is set to * and you wan't to exclude certain files.
		<deleteIncludeFilePattern>:	Which files to be deleted. Probably a file suffix, like *.txt, or * for everything. One or multiple instances.
		<deleteExcludeFilePattern>:	Which files NOT to be deleted. Probably a file suffix, like *.zip, or left empty. One or multiple instances.
									Excluding is only used if the deleteIncludeFilePattern is set to * and you wan't to exclude certain files.
		<zipByDate>					If true, the zip names will be date.FilePattern.zip. If false, it will be originalFileName.zip.
		<zipFilesOlderThan>			The number of days the file must be before it can be zipped. false to disable zipping.
		<deleteFilesOlderThan>		The number of days the file must be before it can be deleted. false to disable deletion.
		<deleteZippedFiles>			If the script should delete the file after it has been zipped or not.
		<compressionLevel>			The compression level for 7zip. 0=Fast with no comrpession, 1=Kind of fast, with compression. 9=Really slow, highest compression.

	<zipExePath>:					The path to the 7z.exe (7zip binary), used to zip files. Bundeled since Log Cleaner 2.6.

	<logging>
		<turnedOn>					If true, the script will log what it's doing in the script folder.
		<filePattern>				The file suffix for it's own log files, this should also be excluded from zipping and deleting above.
		<filePath>					The path where the logs will be stores. Absolute or relative path to the script.
		<deleteLogsOlderThan>		For how long the script should keep it's own logs, in days.
```	

#Version history

##v2.6 (2013-06-24)
* Settings is set per cleaning path, so you can have different behavour on different paths.
* Sets the same creation time on the zipped files as the original files. Makes it possible for the script to delete files on time, even if the zip file is newer than the original file.
* 7zip is now included with the log cleaner
* Logs deletion errors
* The deploy script now asks if you want to overwrite the current config.xml or not, and you can set scheduled task name

##v2.5 (2012-11-22)
* External XML configuration file, no more editing in the PowerShell script.
* Ability to clean multiple paths at once.
* Ability to set relative archivePath to zip logfiles to /Archive or /old
* Added security, if 7zip fails to compress due to access denied, it reports so and does not delete the original file.
* You can now exclude file types from deletion and zipping, if you want to include ALL files but zip for example.
* The scripts own logs will be stored as .clnlog, and is excluded by default
* Ability to set the logging path to an absolute or relative path
* Better logging, makes difference on Info, Warning and Error for monitoring, including execution time, more info
* Ability to set run time in deploy script.

##v2.2 (2012-05-14)
* Ability to save ZIP files to another area, like a network path
* Checks to see if the ZIP was successfully created before deleting files
* Ignores own log files, won't ZIP them
* Made functions of the deleting and zipping, nicer code
* Made a new log function that echoes and logs to file at the same time
* The number of days in the user settings at the top is now positive instead of negative.

##v2.1 (2012-04-04)
* Capability of zipping files by date, like 2012-05-11.txt.zip.
* Simpler code.
* Deploy script sets Powershell for accepting remotely signed scripts, like this one, automatically.
* Deploy script could not always copy itself to all environments, fixed.

##v2.0 (2012-03-29)
* All new code, using 7zip instead, with faster compression.

##v1.0 (2011-12-08)
* First attempt in PowerShell. using a .NET DLL to ZIP.