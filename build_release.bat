@echo off
setlocal
chcp 65001 >nul
cd /d "%~dp0"
title WZNotes Release Builder
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build_release.ps1" %*
pause
