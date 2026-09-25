@echo off
setlocal

cd /d "%~dp0"
title Exporting Benchmark Logs to logs benchmark.txt

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0capture_logs.ps1"

timeout /t 2 >nul
