@echo off
setlocal
if "%POC08_SQL_ADMIN_PASSWORD%"=="" (
  echo ERROR: Set POC08_SQL_ADMIN_PASSWORD before running the full profile.
  echo Example in CMD: set POC08_SQL_ADMIN_PASSWORD=YourStrongTemporaryPassword
  exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0deploy_bicep.ps1" -Profile full
endlocal
