@echo off
rem Double-click to remove Inventor's Journal. You will be asked before any entries are deleted.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Uninstall-Journal.ps1"
echo.
pause
