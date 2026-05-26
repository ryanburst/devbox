@echo off
REM devbox — prefer this for "Run with elevated access" (window stays open)
cd /d "%~dp0"
echo devbox hosts sync started %DATE% %TIME%
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0apply-dev-hosts.ps1"
exit /b %ERRORLEVEL%
