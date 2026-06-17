@echo off
REM Double-click to remove the F2F right-click menu entries.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Uninstall-F2F.ps1"
echo.
pause
