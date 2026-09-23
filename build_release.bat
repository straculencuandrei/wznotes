@echo off
setlocal
cd /d "%~dp0"
echo ========================================================
echo       wznotes 1-Click Release Builder (PC & Android)
echo ========================================================
powershell -ExecutionPolicy Bypass -File "%~dp0build_release.ps1" %*
pause
