@echo off
:: Script `.\LameFallout4EspCleaner.bat`

:: Constants
set "GAME_TITLE=Fallout4"
set "SETTINGS_FILE=data\lfec_settings.psd1"
set "INSTALLER_SCRIPT=lfec_installer.ps1"
set "AUTOCLEANER_EXE=FO4EditQuickAutoClean.exe"

:: admin check
net session >nul 2>&1 || (
    echo Run as Administrator
    pause & exit /b 1
)

:: cd to script dir
pushd "%~dp0"

:: Create folders if they don't exist
if not exist ".\temp" mkdir ".\temp"
if not exist ".\data" mkdir ".\data"

:MainMenu
cls
goto :Banner
:Bar
echo ===============================================================================
goto :eof

:Banner
call :Bar
echo      %GAME_TITLE% Lame Fallout 4 Esp Cleaner
call :Bar
echo.
echo.
echo.
echo.
echo.
echo.
echo.
echo     1. Run %GAME_TITLE% Esp Cleaner
echo.
echo     2. Configure/Install Program
echo.
echo.
echo.
echo.
echo.
echo.
echo.
echo.
call :Bar
set /p "choice=Selection; Menu Options = 1-2, Exit Batch = X: "

:: Process menu choice
if /i "%choice%"=="1" goto :RunCleaner
if /i "%choice%"=="2" goto :Configure
if /i "%choice%"=="x" goto :Exit
if /i "%choice%"=="X" goto :Exit

echo Invalid selection. Please choose 1, 2, or X.
timeout /t 2 >nul
goto :MainMenu

:RunCleaner
cls
call :Bar
echo Starting %GAME_TITLE% Esp Cleaner...
call :Bar
echo.

:: Check if configuration exists
if not exist "%SETTINGS_FILE%" (
    echo [ERROR] Configuration not found!
    echo Please run "Configure/Install Program" first.
    echo.
    pause
    goto :MainMenu
)
echo [OK] Configuration found
timeout /t 1 >nul

:: Verify PowerShell
call :VerifyPowerShell
if %ERRORLEVEL% neq 0 (
    pause
    goto :MainMenu
)

:: Verify GameDataPath from settings
call :CheckGameDataPath
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Game data path not found: %GAME_DATA_PATH%
    echo Please run "Configure/Install Program" to fix settings.
    pause
    goto :MainMenu
)
echo [OK] Game data folder found
timeout /t 1 >nul

:: Verify Thread1 installation
if not exist ".\Thread1\%AUTOCLEANER_EXE%" (
    echo [ERROR] Missing %AUTOCLEANER_EXE% in Thread1 folder
    echo Please run "Configure/Install Program" to fix this issue.
    pause
    goto :MainMenu
)
echo [OK] Thread1 verified
timeout /t 1 >nul

:: Create blacklist if needed
if not exist ".\data\lfec_blacklist.txt" type nul >".\data\lfec_blacklist.txt"
echo [OK] Blacklist ready
timeout /t 1 >nul

:: Cleanup old temp files
call :CleanupFiles
echo [OK] Old files cleaned
timeout /t 1 >nul

:: PowerShell banner
echo.
echo Launching PowerShell script...

:: Run program script
"%PSCMD%" -NoP -EP Bypass -File "lfec_program.ps1"
set "PS_EXIT_CODE=%ERRORLEVEL%"

:: Post-execution cleanup
call :CleanupFiles

if %PS_EXIT_CODE% neq 0 (
    echo.
    echo [ERROR] PowerShell script failed with exit code %PS_EXIT_CODE%
    pause
    goto :MainMenu
)
echo [OK] PowerShell script finished
timeout /t 1 >nul
goto :MainMenu

:Configure
cls
call :Bar
echo Starting Configuration/Installation...
call :Bar
echo.

:: Verify PowerShell
call :VerifyPowerShell
if %ERRORLEVEL% neq 0 (
    pause
    goto :MainMenu
)

:: Run PowerShell installer
echo [INFO] Launching PowerShell installer...
echo.
"%PSCMD%" -NoP -EP Bypass -File ".\lfec_installer.ps1"

goto :MainMenu

:Exit
cls
call :Bar
echo    %GAME_TITLE% Esp Cleaner
call :Bar
echo.
echo Exiting Batch in 5 seconds...
timeout /t 5 >nul
popd
exit /b 0

:: Functions below

:VerifyPowerShell
set "PSCMD="
for /f "delims=" %%G in ('where pwsh.exe 2^>nul') do set "PSCMD=%%G"
if not defined PSCMD (
    for /f "delims=" %%G in ('where powershell.exe 2^>nul') do set "PSCMD=%%G"
)
if not defined PSCMD (
    echo [ERROR] PowerShell not found
    exit /b 1
)
echo [OK] PowerShell located
timeout /t 1 >nul
exit /b 0

:CheckGameDataPath
:: Read GameDataPath from the settings file
setlocal enabledelayedexpansion
set "GAME_DATA_PATH="
for /f "usebackq tokens=1,2 delims== " %%A in ("%SETTINGS_FILE%") do (
    if "%%A"=="GameDataPath" (
        set "TEMP_PATH=%%B"
        set "TEMP_PATH=!TEMP_PATH: =!"
        set "TEMP_PATH=!TEMP_PATH:'=!"
        set "TEMP_PATH=!TEMP_PATH:"=!"
    )
)
endlocal & set "GAME_DATA_PATH=%TEMP_PATH%"
if not defined GAME_DATA_PATH (
    echo [ERROR] GameDataPath not found in %SETTINGS_FILE%
    exit /b 1
)
:: Check if the folder exists
if not exist "%GAME_DATA_PATH%" (
    exit /b 1
)
exit /b 0

:CleanupFiles
:: Delete temp folder contents but preserve the folder
if exist ".\temp" (
    del /q ".\temp\*" 2>nul
)
:: Clean up Thread1 temp files
if exist ".\Thread1\*.tmp" del /q ".\Thread1\*.tmp" 2>nul
if exist ".\Thread1\FO4Edit_*.txt" del /q ".\Thread1\FO4Edit_*.txt" 2>nul
goto :eof