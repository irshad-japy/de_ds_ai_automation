@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "PYTHON_VERSION=3.12.9"
set "PYENV_ROOT=%USERPROFILE%\.pyenv\pyenv-win"
set "PYENV_BIN=%PYENV_ROOT%\bin"
set "PYENV_SHIMS=%PYENV_ROOT%\shims"
set "POETRY_BIN=%APPDATA%\Python\Scripts"

echo =====================================================
echo  Python Toolchain Setup - Windows
 echo  pyenv-win + Python %PYTHON_VERSION% + Poetry
 echo =====================================================
echo.

REM -------------------------------------------------------
REM 0. Prerequisite: Windows PowerShell
REM -------------------------------------------------------
where powershell.exe >nul 2>&1
if errorlevel 1 (
    echo [ERROR] powershell.exe was not found.
    echo         Windows PowerShell is required for this installer.
    goto :FAIL
)

REM -------------------------------------------------------
REM 1. Install or reuse pyenv-win
REM -------------------------------------------------------
set "PATH=%PYENV_BIN%;%PYENV_SHIMS%;%PATH%"

where pyenv >nul 2>&1
if errorlevel 1 (
    echo [STATUS] pyenv-win not found. Installing...

    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
      "$ErrorActionPreference='Stop'; [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; $installer=Join-Path $env:TEMP 'install-pyenv-win.ps1'; Invoke-WebRequest -UseBasicParsing -Uri 'https://raw.githubusercontent.com/pyenv-win/pyenv-win/master/pyenv-win/install-pyenv-win.ps1' -OutFile $installer; & $installer"

    if errorlevel 1 (
        echo [ERROR] pyenv-win installation failed.
        goto :FAIL
    )
) else (
    echo [STATUS] pyenv-win is already installed. Reusing it.
)

REM Add pyenv to this CMD session immediately.
set "PYENV=%PYENV_ROOT%"
set "PYENV_HOME=%PYENV_ROOT%"
set "PATH=%PYENV_BIN%;%PYENV_SHIMS%;%PATH%"

REM Persist the official pyenv-win environment variables and PATH entries.
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$root=Join-Path $env:USERPROFILE '.pyenv\pyenv-win'; [Environment]::SetEnvironmentVariable('PYENV',$root,'User'); [Environment]::SetEnvironmentVariable('PYENV_ROOT',$root,'User'); [Environment]::SetEnvironmentVariable('PYENV_HOME',$root,'User'); $userPath=[Environment]::GetEnvironmentVariable('Path','User'); if($null -eq $userPath){$userPath=''}; foreach($entry in @($root+'\shims',$root+'\bin')){ if(-not (($userPath -split ';') -contains $entry)){ $userPath=$entry+';'+$userPath } }; [Environment]::SetEnvironmentVariable('Path',$userPath.Trim(';'),'User')"

if errorlevel 1 (
    echo [ERROR] Could not persist pyenv-win environment variables.
    goto :FAIL
)

where pyenv >nul 2>&1
if errorlevel 1 (
    echo [ERROR] pyenv command is still unavailable after installation.
    echo         Expected location: %PYENV_BIN%
    goto :FAIL
)

call pyenv --version
if errorlevel 1 goto :FAIL

REM -------------------------------------------------------
REM 2. Install or reuse Python %PYTHON_VERSION%
REM -------------------------------------------------------
echo.
echo [STATUS] Checking Python %PYTHON_VERSION% in pyenv...

call pyenv versions 2>nul | findstr /C:"%PYTHON_VERSION%" >nul 2>&1
if errorlevel 1 (
    echo [STATUS] Python %PYTHON_VERSION% not found. Installing via pyenv...
    call pyenv install %PYTHON_VERSION%
    if errorlevel 1 (
        echo [ERROR] Python %PYTHON_VERSION% installation failed.
        goto :FAIL
    )
) else (
    echo [STATUS] Python %PYTHON_VERSION% is already installed. Reusing it.
)

REM Always select the requested Python version, even when it already existed.
echo [STATUS] Setting pyenv global Python to %PYTHON_VERSION%...
call pyenv global %PYTHON_VERSION%
if errorlevel 1 (
    echo [ERROR] Could not set pyenv global version to %PYTHON_VERSION%.
    goto :FAIL
)

call pyenv rehash

where python >nul 2>&1
if errorlevel 1 (
    echo [ERROR] python command is unavailable after pyenv setup.
    goto :FAIL
)

for /f "tokens=2" %%V in ('python --version 2^>^&1') do set "ACTIVE_PYTHON=%%V"
echo [STATUS] Active Python: !ACTIVE_PYTHON!

if /I not "!ACTIVE_PYTHON!"=="%PYTHON_VERSION%" (
    echo [ERROR] Expected Python %PYTHON_VERSION%, but active Python is !ACTIVE_PYTHON!.
    echo         Close other terminals and rerun this script if another Python is taking precedence.
    goto :FAIL
)

REM -------------------------------------------------------
REM 3. Install or reuse Poetry
REM -------------------------------------------------------
echo.
echo [STATUS] Checking Poetry...

REM Poetry's official Windows installer places its command wrapper here.
set "PATH=%POETRY_BIN%;%PATH%"

where poetry >nul 2>&1
if errorlevel 1 (
    echo [STATUS] Poetry not found. Installing with the official installer...

    REM IMPORTANT: this must be install.python-poetry.org, not python-poetry.org.
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
      "$ErrorActionPreference='Stop'; [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; (Invoke-WebRequest -Uri 'https://install.python-poetry.org' -UseBasicParsing).Content | python -"

    if errorlevel 1 (
        echo [ERROR] Poetry installation failed.
        goto :FAIL
    )
) else (
    echo [STATUS] Poetry is already installed. Reusing it.
)

REM Persist Poetry wrapper directory without duplicating it in User PATH.
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$entry=Join-Path $env:APPDATA 'Python\Scripts'; $userPath=[Environment]::GetEnvironmentVariable('Path','User'); if($null -eq $userPath){$userPath=''}; if(-not (($userPath -split ';') -contains $entry)){ $userPath=$entry+';'+$userPath; [Environment]::SetEnvironmentVariable('Path',$userPath.Trim(';'),'User') }"

if errorlevel 1 (
    echo [ERROR] Could not persist Poetry PATH.
    goto :FAIL
)

REM Refresh PATH for this running script and validate.
set "PATH=%POETRY_BIN%;%PYENV_BIN%;%PYENV_SHIMS%;%PATH%"

where poetry >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Poetry was installed but the poetry command cannot be found.
    echo         Expected wrapper directory: %POETRY_BIN%
    echo         Poetry environment is normally: %APPDATA%\pypoetry
    goto :FAIL
)

call poetry --version
if errorlevel 1 (
    echo [ERROR] Poetry command exists but failed to run.
    goto :FAIL
)

REM -------------------------------------------------------
REM 4. Final verification
REM -------------------------------------------------------
echo.
echo =====================================================
echo  SETUP COMPLETED SUCCESSFULLY
 echo =====================================================
echo.
echo [VERIFY] pyenv:
call pyenv --version
echo.
echo [VERIFY] Python:
call python --version
echo.
echo [VERIFY] Python executable:
where python
echo.
echo [VERIFY] Poetry:
call poetry --version
echo.
echo [VERIFY] Poetry executable:
where poetry
echo.
echo Python %PYTHON_VERSION%, pyenv-win, and Poetry are ready.
echo You can close this window and open a NEW Command Prompt or IDE.
echo.
pause
exit /b 0

:FAIL
echo.
echo =====================================================
echo  SETUP FAILED
 echo =====================================================
echo Review the [ERROR] message above.
echo.
pause
exit /b 1
