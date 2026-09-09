@echo off
SETLOCAL EnableDelayedExpansion

echo ===================================================
echo  POC-08 Poetry bootstrap
echo ===================================================

:: Ensure pyenv path context is bound for the script run
SET "PYENV_ROOT=%USERPROFILE%\.pyenv\pyenv-win"
SET "PATH=!PYENV_ROOT!\bin;!PYENV_ROOT!\shims;%USERPROFILE%\AppData\Roaming\Python\Scripts;%PATH%"

:: 1. Force verify Python 3.12 availability
echo [STATUS] Checking Python 3.12 version...
call python --version 2>nul
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Python is not accessible. Please ensure install.bat ran successfully.
    exit /b 1
)

:: 2. Force verify Poetry availability
echo [STATUS] Checking Poetry version...
call poetry --version 2>nul
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Poetry is not accessible. Please ensure install.bat ran successfully.
    exit /b 1
)

:: 3. Configure Poetry to create virtual environments inside the project folder (.venv)
echo [STATUS] Setting local virtual environment preferences...
call poetry config virtualenvs.in-project true

:: 4. Direct Poetry to use Python 3.12
echo [STATUS] Binding poetry environment to Python 3.12...
call poetry env use 3.12
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Poetry failed to target Python 3.12 environment setup.
    exit /b 1
)

:: 5. Execute dependency installation
echo [STATUS] Installing application package dependencies...
call poetry install
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Dependency tree assembly failed.
    exit /b 1
)

:: 6. Verify profile configuration
echo [STATUS] Triggering verify_config verification run...
call poetry run python -m scripts.verify_config --profile local
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Config framework verification validation failure.
    exit /b 1
)

:: 7. Execute testing engine suite
echo [STATUS] Running unit testing framework infrastructure...
call poetry run pytest
if %ERRORLEVEL% neq 0 (
    echo [ERROR] One or more testing sequences failed to pass completely.
    exit /b 1
)

echo ===================================================
echo  Bootstrap completed.
echo ===================================================
pause
