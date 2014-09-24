@echo off
REM Copies the LogCleaner and creates a task for this

echo #### WARNING ####
echo If you didn't run this script as admin, or some of the tasks will fail!
echo ______________________________

set scriptPath=D:\Scripts\LogCleaner
set adminUser=Administrator
set schedTime=02:00:00
set schedName=LogCleaner
set overwriteConfig=n
set runNow=n

set /p scriptPath=Where to put the LogCleaner script? [D:\Scripts\LogCleaner] 
set /p schedTime=When should the script run each day? [02:00:00] 
set /p schedName=What name should the job scheduled job get? [LogCleaner] 
set /p adminUser=What's the user that will run the task? [Administrator] 
set /p adminPass=What's the password for this user? 

mkdir %scriptPath%
mkdir %scriptPath%\7zip
copy "%~dp0\LogCleaner.ps1" "%scriptPath%" /y
copy "%~dp0\readme.txt" "%scriptPath%" /y
copy "%~dp0\7zip\7z.dll" "%scriptPath%\7zip" /y
copy "%~dp0\7zip\7z.exe" "%scriptPath%\7zip" /y

if exist "%scriptPath%\config.xml" (
	REM I needed this extra if exist because batch script is stupid
	set /p overwriteConfig=config.xml already exist, do you want to overwrite it? [n] 
)

if exist "%scriptPath%\config.xml" (
	if "%overwriteConfig%" == "y" (
		copy "%~dp0\config.xml" "%scriptPath%" /y
	) else (
		echo Configuration file not copied.
	)
) else (
	copy "%~dp0\config.xml" "%scriptPath%" /y
)

powershell Set-ExecutionPolicy RemoteSigned

schtasks /create /RU %adminUser% /RP %adminPass% /SC DAILY /ST %schedTime% /TN %schedName% /RL HIGHEST /TR "powershell %scriptPath%\LogCleaner.ps1"

echo Please edit the configuration XML to match your needs, then save end exit...
notepad.exe "%scriptPath%\config.xml"

set /p runNow=Do you want to run the script now? y/n [n] 
if "%runNow%" == "y" (
	schtasks /run /TN %schedName%
)

pause