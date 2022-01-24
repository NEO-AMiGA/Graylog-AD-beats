@echo OFF

:: CHECK IF WE ARE ADMIN --------------------------------------------------------------------------------------------------------
NET SESSION >nul 2>&1
IF %ERRORLEVEL% EQU 0 (
	echo.
	echo ####### ADMINISTRATOR PRIVILEGES DETECTED #########
	echo.
) ELSE (
   echo.
   echo ####### ERROR: ADMINISTRATOR PRIVILEGES REQUIRED #########
   echo This script must be run as administrator to work properly!  
   echo Right click on the shortcut and select "Run As Administrator".
   echo ##########################################################
   echo.
   EXIT /B 1
)


:: SOME VARS, EDIT FOR YOUR OWN NEEDS ----------------------------------------------------------------------------------
:: Your environment
:: Name of your server, only cosmetic in the installer and never used
set "graylogServerHostName=m5-logger01"

:: Installation directory on disk. Normally C:\Program Files\graylog
set "graylogInstallationDir=C:\Program Files\graylog"

:: Path to the graylog_sidecar_installer_x.x.x-x.exe installer
set "graylogSidecarInstaller=C:\Users\%USERNAME%\Downloads\graylog_sidecar_installer_1.1.0-1.exe"

:: URL to your server
set "graylogServerURL=http://192.168.44.92:9000/api/"

:: API TOKEN. Generate in web ui for the graylog-sidecar user
set "graylogAPItoken=1u3ivm9ubg7fpi4tfqo0uass3e0n4nms5lvj96fuphj0qilubvgf"

:: The Graylog-AD-beats-master dir. Default is the one this bat file is runing from. 
set "installerDir=%~dp0"

:: timestamp for backup of settings
for /F "usebackq tokens=1,2 delims==" %%i in (`wmic os get LocalDateTime /VALUE 2^>NUL`) do if '.%%i.'=='.LocalDateTime.' set ldt=%%j
set timestamp=%ldt:~2,2%%ldt:~4,2%%ldt:~6,2% %ldt:~8,2%%ldt:~10,2%%ldt:~12,2%


:: DEBUG OUTPUT OF VARS ------------------------------------------------------------------------------------------------
:: comment out the below 'goto' to see output. Normally only needed when you have issues with install.
goto :skipdebug
echo.
echo ####### DEBUG OUTPUT! ####################################################################
echo DEBUG: graylogServerHostName: %graylogServerHostName%
echo DEBUG: graylogInstallationDir: %graylogInstallationDir%
echo DEBUG: graylogSidecarInstaller: %graylogSidecarInstaller%
echo DEBUG: graylogServerURL: %graylogServerURL%
echo DEBUG: graylogAPItoken: %graylogAPItoken%
echo DEBUG: installerDir: %installerDir%
::echo DEBUG: tags: %tags%
echo.
echo.
:skipdebug


:: --------------------------------------------------------------------------------------------------------------
:: --------------------------------------------------------------------------------------------------------------
:: --------------------------------------------------------------------------------------------------------------
:: INSTALLATION PROCESS, PROBABLY NO NEED TO EDIT ANYTHING BELOW ------------------------------------------------

echo This script installs the Graylog Sidecar log forwarder going to %graylogServerHostName%
echo.

: GIVE THE USER AN OPTION OF WHAT TO DO
goto :install_choice

:install_choice
	echo.
	set /P c=Are you sure you want to continue with the installation [y/N]? 
	setlocal EnableDelayedExpansion
	if /I "!c!" == "Y" goto :startInstall
	if /I "!c!" == "N" goto :eof
	goto :install_choice

:startInstall
	:: Check if alreaedy installed. If so, uninstall service.
	if exist "%graylogInstallationDir%\sidecar\graylog-sidecar.exe" (
		echo.
		echo - Graylog Sidecar SERVICE UNINSTALL...
		"%graylogInstallationDir%\sidecar\graylog-sidecar.exe" -service uninstall
	)

	echo.
	echo - Graylog Sidecar INSTALL
 	%graylogSidecarInstaller% /S -SERVERURL=%graylogServerURL% /S -SERVERURL=%graylogServerURL% -APITOKEN=%graylogAPItoken%

 	echo.
	echo - Graylog YAML - Backing up original config to 'sidecar.yml-orig-%timestamp%'...
	move "%graylogInstallationDir%\sidecar\sidecar.yml" "%graylogInstallationDir%\sidecar\sidecar.yml-orig-%timestamp%" >nul 2>&1

	echo.
	echo - Graylog YAML - Creating Yaml from template and adding server URL and API Token to it...
	echo server_url: %graylogServerURL% >>"%graylogInstallationDir%\sidecar\sidecar.yml"
	echo server_api_token: "%graylogAPItoken%" >>"%graylogInstallationDir%\sidecar\sidecar.yml"

	type %installerDir%\windows-graylog-sidecar.yml >> "%graylogInstallationDir%\sidecar\sidecar.yml"

	echo.
	echo - Graylog Sidecar App Installed and configured

	echo.
	:: Check if alreaedy installed. If it is we DON'T install it. We only need to start it. Some issues so we run this twice.
	sc query graylog-sidecar >nul 2>&1
	sc query graylog-sidecar >nul 2>&1
	if %ERRORLEVEL% NEQ 0 (
		echo - Graylog Sidecar SERVICE Installing...
		"%graylogInstallationDir%\sidecar\graylog-sidecar.exe" -service install 
		"%graylogInstallationDir%\sidecar\graylog-sidecar.exe" -service start
	) else (
		echo.
		echo - Graylog Sidecar SERVICE starting...
		:: the stop is here since the installer starts one of the services. Stoping gives a cleaner result.
		:: But honesly, the else isn't needed since we uninstall the service above instead of stopping
		"%graylogInstallationDir%\sidecar\graylog-sidecar.exe" -service stop
		"%graylogInstallationDir%\sidecar\graylog-sidecar.exe" -service start
	)
	echo.
	echo - Graylog Sidecar SERVICE Done
	echo.
	echo - Graylog Sidecar Installation Complete
	echo.

@echo ON

