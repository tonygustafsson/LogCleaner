# Created by Tony Gustafsson
# Version 2.6
# Release date 2013-06-24

#Start measuring time
$stopWatch = [Diagnostics.Stopwatch]::StartNew(); #Start measuring time

#Get the directory were the script is put
$scriptDir = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent; #The path of the script, no matter where we execute from

#Get configuration from XML file
$configFile = "$scriptDir\config.xml";
[xml]$XMLConfig = Get-Content $configFile;
$config = $XMLConfig.config;

#User defined settings from XML
$cleanJobs					= [array]$config.clean;															#The paths that the script will handle, format as @("C:\dir1","C:\dir2");
$loggingTurnedOn			= [System.Convert]::ToBoolean($config.logging.turnedOn);						#Log compressed and deleted files.
$deleteLogsOlderThan		= [int]$config.logging.deleteLogsOlderThan;										#The number of days the logging should be saved or $false to disable
$logName					= "LogCleaner_" + $(Get-Date -format d) + [string]$config.logging.fileSuffix;	#The name of the current log file, to append data to. A date variable.

if ([string]$config.zipExePath -match '^[A-z]\:\\')
{
	#Absolute path for 7zip
	$zipExePath = [string]$config.zipExePath;
}
else
{
	#Relative path for 7zip
	$zipExePath = "$scriptDir\" + [string]$config.zipExePath;
}

if ([string]$config.logging.filePath -match '^[A-z]\:\\')
{
	#Absolute path for logging
	$logPath = [string]$config.logging.filePath;
}
else
{
	#Relative path for logging
	$logPath = "$scriptDir\" + [string]$config.logging.filePath;
}

#Create the log dir if it's not exists
if ($loggingTurnedOn -and !(Test-Path $logPath))
{
	New-Item $logPath -type Directory;
}

function log()
{
	#A function for writing to the log file
	Param(
        [String] $message
	)
	Process
	{
		$message = $(Get-Date -format T) + ": " + $message;
		Write-Host $message;

		if ($loggingTurnedOn)
		{
			$logFile = $logPath + "\" + $logName;
			$message >> $logFile;
		}
	}
}

function deleteOldFiles()
{
	#Function for deleting old files that should not be zipped.
	Param(
        [String] $cleanPath,
        [Array] $deleteIncludeFilePatterns,
		[Int] $deleteFilesOlderThan
	)
	Process
	{
		#Create an array of files to remove, with the right creation time and type. Also exclude it's own log path
		log -message "Info: Start deleting: Get-ChildItem -Path $cleanPath -recurse -include $deleteIncludeFilePatterns -exclude $deleteExcludeFilePatterns | WHERE { $_.CreationTime -lt ($(Get-Date).AddDays($deleteFilesOlderThan * -1)) -and $_.Attributes -ne 'Directory' }";
		$filesToDelete = Get-ChildItem -Path $cleanPath -recurse -include $deleteIncludeFilePatterns -exclude $deleteExcludeFilePatterns | WHERE { $_.CreationTime -lt ($(Get-Date).AddDays($deleteFilesOlderThan * -1)) -and $_.Attributes -ne 'Directory' }

		if ($filesToDelete)
		{
			foreach ($thisFile in $filesToDelete)
			{
				#Delete all files that is too old
				[int]$fileAge = ($(Get-Date) - $thisFile.CreationTime).TotalDays; #The age of the file in days
				log -message "Deleting: $thisFile ($fileAge days old)";
				
				try
				{
					Remove-Item $thisFile -ErrorAction Stop;
				}
				catch
				{
					log -message "Error: Could not delete $thisFile";
				}
			}
		}
	}
}

function zipOldFiles()
{
	#Function for zipping old files.
	Param(
        [String] $cleanPath,
        [Array] $zipIncludeFilePatterns,
		[Array] $zipExcludeFilePatterns,
		[Int] $zipFilesOlderThan,
		[Bool] $zipByDate,
		[Bool] $deleteZippedFiles
	)
	Process
	{
		#Create an array of files to zip, with the right creation time and type, exclude it's own log path because it has it's own cleaning function
		log -message "Info: Start zipping: Get-ChildItem -Path $cleanPath -recurse -include $zipIncludeFilePatterns -exclude $zipExcludeFilePatterns | WHERE { $_.CreationTime -le ($(Get-Date).AddDays($zipFilesOlderThan * -1)) -and $_.Attributes -ne 'Directory' }";
		$filesToZip = Get-ChildItem -Path $cleanPath -recurse -include $zipIncludeFilePatterns -exclude $zipExcludeFilePatterns | WHERE { $_.CreationTime -le ($(Get-Date).AddDays($zipFilesOlderThan * -1)) -and $_.Attributes -ne 'Directory' };
	
		if ($filesToZip)
		{
			foreach ($thisFile in $filesToZip)
			{
				#ZIP all files that matches critera
				[int]$fileAge = ($(Get-Date) - $thisFile.CreationTime).TotalDays; #The age of the file in days

				if ($zipByDate)
				{
					#Add files to the zip with the name of the files creation date
					$zipName = ([DateTime]$thisFile.CreationTime).ToShortDateString() + $thisFile.Extension + '.zip';
				}
				else
				{
					#The new ZIP file name, if not grouped by date: group by filename
					$zipName = $thisFile.Name + '.zip';
				}
				
				if ($archivePath)
				{
					#Add the zip directory to the specified in $archivePath
					if ($archivePath -match '^[A-z]\:\\')
					{
						#Absolut path, store it with it's previosly absolut path intact
						$zipName = $archivePath + "\" + [Regex]::Replace($thisFile.DirectoryName, ".\:\\", "") + "\" + $zipName;
					}
					else
					{
						#Relative path, store it in a folder at the same location as the log file itself
						$zipName = $thisFile.DirectoryName + $archivePath + "\" + $zipName;
					}
				}
				else
				{
					#Add the zip directory to the log files path
					$zipName = $thisFile.DirectoryName + "\" + $zipName;
				}
				
				if ((!$zipByDate -and (Test-Path -Path $zipName) -ne $True) -or $zipByDate)
				{
					#Zip the file with format ZIP, suppress 7zip output
					Set-Alias zip $zipExePath; #Needed because powershell can't handle exe files that begins with a number, like 7z.exe
					zip a -tzip "-mx=$compressionLevel" -y $zipName $thisFile | Out-Null;
					
					if ($LASTEXITCODE -eq 0) #7zip returns 0 if it's a success
					{
						#If zip individual files check that such a zip doesn't already exist
						log -message "Zipping: $thisFile ($fileAge days old) to $zipName";

						#Change the creation time on the new zip file so that newly created zipfiles containing old logs still can be deleted on time.
						$zipFile = Get-ChildItem -Path $zipName; 
						if ([DateTime]$thisFile.CreationTime -lt [DateTime]$zipFile.CreationTime)
						{
							Set-ItemProperty -Path $zipName -Name CreationTime -Value $thisFile.CreationTime;
						}
						
						if ($deleteZippedFiles -and (Test-Path -Path $zipName) -eq $True)
						{
							#If the script should delete the file afterwards that got zipped
							#Don't remove the file if we cannot find the created ZIP file, for security
							try
							{
								Remove-Item $thisFile -ErrorAction Stop
							}
							catch
							{
								log -message "Error: Could not delete $thisFile";
							}
						}
					}
					else
					{
						#Warning on zipping
						Remove-Item $zipName; #7zip stores an empty ZIP-file, we don't need this
						log -message "Warning: Zipping $thisFile to $zipName failed, probably due to access denied. 7zip exit code: $LASTEXITCODE";
					}
				}
			}
		}
	}
}

function deleteOwnLogFiles()
{
	#For removing it's own log files
	Param(
        [String] $logPath,
        [Int] $deleteLogsOlderThan
	)
	Process
	{
		#Create an array of files of $logPath
		$logsToDelete = Get-ChildItem -Path $logPath -Recurse | WHERE { $_.CreationTime -le ($(Get-Date).AddDays($deleteLogsOlderThan * -1)) }

		if ($logsToDelete)
		{
			#If there is any files there
			foreach ($thisFile in $logsToDelete)
			{
				#Delete the old log file
				log -message "Info: Deleting own log file: $thisFile";
				Remove-Item $thisFile.FullName;
			}
		}
	}
}

if (!(Test-Path $zipExePath))
{
	#Exit if the exe isn't found
	log -message "Error: 7z.exe was not found at $zipExePath.";
	throw "Error: 7z.exe was not found at $zipExePath."
}

log -message "############### Starting LogCleaner ###############";

foreach ($cleanJob in $cleanJobs)
{
	#For every path to clean
	
	#Get settings for current clean job from XML
	$cleanPath					= [string]$cleanJob.path;
	$archivePath 				= [string]$cleanJob.archivePath;												#Absolute or relative path to put ZIP files, or $false for saving in the same location as the log files
	$zipByDate 					= [System.Convert]::ToBoolean($cleanJob.zipByDate);							#Should files be zipped by date, or individually?
	$zipIncludeFilePatterns		= [array]$cleanJob.zipIncludeFilePattern;									#File types as an array that will be zipped. * for everything.
	$zipExcludeFilePatterns 	= [array]$cleanJob.zipExcludeFilePattern;									#Excluded files from being zipped, used if you want to zip ALL files but *.zip for example.
	$deleteIncludeFilePatterns	= [array]$cleanJob.deleteIncludeFilePattern;								#File types that can be deleted if they are to old, include zip for removing own zipped files. * for everything.
	$deleteExcludeFilePatterns	= [array]$cleanJob.deleteExcludeFilePattern;								#File types to exclude from deletion, used if you want to delete ALL files but *.bmp for example. $false to disable, or @("*.zip", "*.rar") etc for different types.
	$zipFilesOlderThan			= [int]$cleanJob.zipFilesOlderThan;											#Number of days or $false to disable
	$deleteFilesOlderThan		= [int]$cleanJob.deleteFilesOlderThan;										#Number of days or $false to disable.
	$deleteZippedFiles			= [System.Convert]::ToBoolean($cleanJob.deleteZippedFiles);					#$true or $false. If $false, the files will remain after compression.
	$compressionLevel			= [int]$cleanJob.compressionLevel;
	
	if (!(Test-Path $cleanPath))
	{
		#If the path does not exist
		log -message "Warning: Tried to clean $cleanPath but the path doesn't exist!";
	}
	else
	{
		log -message "Path: Beginning to clean $cleanPath";
	
		if ($deleteFilesOlderThan -ne $False)
		{
			#Delete old files that should not be zipped
			log -message "Info: File types to delete: $deleteIncludeFilePatterns. Exclude file types: $deleteExcludeFilePatterns. File ages: Older than $deleteFilesOlderThan days.";
			deleteOldFiles -cleanPath $cleanPath -deleteIncludeFilePatterns $deleteIncludeFilePatterns -deleteFilesOlderThan $deleteFilesOlderThan;
		}

		if ($zipFilesOlderThan -ne $False)
		{
			#Zip old files
			log -message "Info: File types to ZIP: $zipIncludeFilePatterns. Exclude file types: $zipExcludeFilePatterns. Older than $zipFilesOlderThan days.";
			if ($zipByDate) { log -message "Info: ZIP-files will be named by date."; } else { log -message "Info: ZIP-files will be named after original file names." }
			if ($deleteZippedFiles) { log -message "Info: Outdated zip files will be deleted."; } else { log -message "Info: Outdated zipped files will not be deleted." }
			zipOldFiles -cleanPath $cleanPath -zipIncludeFilePatterns $zipIncludeFilePatterns -zipExcludeFilePatterns $zipExcludeFilePatterns -zipFilesOlderThan $zipFilesOlderThan -zipByDate $zipByDate -deleteZippedFiles $deleteZippedFiles;
		}
	}

	if ($loggingTurnedOn -and $deleteLogsOlderThan -ne $False -and (Test-Path $logPath))
	{
		#For removing it's own log files
		deleteOwnLogFiles -logPath $logPath -deleteLogsOlderThan $deleteLogsOlderThan;
	}
}

#Stop the timer, get seconds since it started
$stopWatch.Stop();
$executionTime = [System.Math]::Round($stopWatch.ElapsedMilliseconds.ToString() / 1000);

log -message "Info: Done with the cleaning for this time. Execution time: $executionTime seconds.";

#This is needed for the task manager to end the script
exit
