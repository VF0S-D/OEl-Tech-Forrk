@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0restore_tus_save.ps1" %*
