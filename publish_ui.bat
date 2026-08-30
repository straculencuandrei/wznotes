@echo off
title wznotes Update and Release Manager
powershell -ExecutionPolicy Bypass -File "%~dp0scripts\publish_ui.ps1"
