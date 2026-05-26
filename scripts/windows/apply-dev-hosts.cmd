@echo off
REM devbox - prefer elevated PowerShell; see START-HERE-hosts.txt (ASCII only)
cd /d "%~dp0"
echo devbox hosts sync started %DATE% %TIME%
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0apply-dev-hosts.ps1"
exit /b %ERRORLEVEL%
