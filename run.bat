@echo off
setlocal

cd /d "%~dp0"
title WZNotes - Quick Run

:: Run via PowerShell with Bypass to auto-detect device and run
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run.ps1" %*

if %ERRORLEVEL% neq 0 (
    echo.
    echo ================================================================
    echo Session ended with exit code: %ERRORLEVEL%
    echo ================================================================
    pause
)
