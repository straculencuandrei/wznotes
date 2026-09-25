@echo off
setlocal

cd /d "%~dp0"
title WZNotes - Writing Performance Benchmark & Diagnostic Tool

:: Run via PowerShell with Bypass to auto-detect device and run benchmark
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0benchmark.ps1" %*

if %ERRORLEVEL% neq 0 (
    echo.
    echo ================================================================
    echo Benchmark session ended with exit code: %ERRORLEVEL%
    echo ================================================================
    pause
)
