@echo off
title wznotes Update & Release Manager
powershell -ExecutionPolicy Bypass -File "%~dp0scripts\publish_ui.ps1"
