@echo off
setlocal

cd /d "%~dp0"
title WZNotes - PC Windows Desktop App

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run_pc.ps1" %*

if %ERRORLEVEL% neq 0 (
    echo.
    echo ================================================================
    echo Session ended with exit code: %ERRORLEVEL%
    echo ================================================================
    pause
)
