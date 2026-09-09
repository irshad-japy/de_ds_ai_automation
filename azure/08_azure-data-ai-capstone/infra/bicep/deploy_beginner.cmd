@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0deploy_bicep.ps1" -Profile beginner
endlocal
