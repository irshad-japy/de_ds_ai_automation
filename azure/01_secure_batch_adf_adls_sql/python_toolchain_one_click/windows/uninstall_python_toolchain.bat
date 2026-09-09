@echo off
SETLOCAL EnableDelayedExpansion

echo =========================================
echo  Starting Windows Uninstall Process
echo =========================================

SET "PYENV_ROOT=%USERPROFILE%\.pyenv\pyenv-win"
SET "PATH=!PYENV_ROOT!\bin;!PYENV_ROOT!\shims;!PATH!"
SET "POETRY_BIN=%APPDATA%\Python\Scripts"

:: 1. Uninstall Poetry
where poetry >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo [STATUS] Found active Poetry installation. Running standard uninstaller...
    REM FIXED: URL changed to install.python-poetry.org to download the actual installation/uninstallation engine
    powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; (Invoke-WebRequest -Uri https://python-poetry.org -UseBasicParsing).Content | python - --uninstall"
)

:: Clear out lingering Poetry profile application files if they exist
if exist "%USERPROFILE%\AppData\Roaming\pypoetry" (
    echo [STATUS] Removing lingering Poetry configuration files...
    rmdir /s /q "%USERPROFILE%\AppData\Roaming\pypoetry" 2>nul
)
if exist "%POETRY_BIN%\poetry.exe" (
    echo [STATUS] Removing lingering Poetry binaries...
    del /f /q "%POETRY_BIN%\poetry*" >nul 2>&1
)

:: 2. Uninstall Python 3.12.9 from pyenv
where pyenv >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo [STATUS] Checking for Python 3.12.9 inside pyenv...
    
    SET "PYTHON_FOUND=NO"
    for /f "tokens=*" %%i in ('call pyenv versions') do (
        echo %%i | findstr "3.12.9" >nul && SET "PYTHON_FOUND=YES"
    )
    
    if "!PYTHON_FOUND!"=="YES" (
        echo [STATUS] Uninstalling Python 3.12.9 via pyenv...
        call pyenv uninstall -f 3.12.9
    ) else (
        echo [STATUS] Python 3.12.9 was not found in pyenv. Skipping...
    )
)

:: 3. Remove Pyenv directories entirely
if exist "%USERPROFILE%\.pyenv" (
    echo [STATUS] Removing pyenv installation directories...
    rmdir /s /q "%USERPROFILE%\.pyenv"
)

:: 4. Clean User Registry Environment variables
echo [STATUS] Cleaning user environment path variables...
powershell -Command "[Environment]::SetEnvironmentVariable('PYENV', $null, 'User')"
powershell -Command "[Environment]::SetEnvironmentVariable('PYENV_ROOT', $null, 'User')"
powershell -Command "[Environment]::SetEnvironmentVariable('PYENV_HOME', $null, 'User')"

echo =========================================
echo  Uninstallation Completed!
echo  Please restart your terminal/IDE.
echo =========================================
pause
