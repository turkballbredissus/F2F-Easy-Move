@echo off
REM Double-click to install the F2F right-click menu entries.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-F2F.ps1"
echo.
pause
