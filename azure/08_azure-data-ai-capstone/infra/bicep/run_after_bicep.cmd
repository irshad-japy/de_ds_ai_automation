@echo off
set /p DEPLOYMENT_NAME=Enter the Bicep deployment name shown after deployment: 
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run_after_bicep.ps1" -DeploymentName "%DEPLOYMENT_NAME%"
