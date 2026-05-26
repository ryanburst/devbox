# devbox — launcher for corporate "Run with elevated access"
# Copied to %LOCALAPPDATA%\devbox\apply-dev-hosts.ps1 by devbox setup hosts
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$logFile = Join-Path $here 'apply-dev-hosts.log'
$exitCode = 0

function Wait-ForUser {
  Write-Host ''
  Read-Host 'Press Enter to close this window'
}

try {
  Start-Transcript -LiteralPath $logFile -Force | Out-Null
  Write-Host "devbox hosts sync - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
  Write-Host "Log file: $logFile"
  Write-Host ''

  $apply = Join-Path $here 'Apply-DevHostsElevated.ps1'
  $lines = Join-Path $here 'hosts-lines.txt'
  if (-not (Test-Path -LiteralPath $apply)) {
    throw "Missing $apply - re-run from WSL: devbox setup hosts"
  }
  if (-not (Test-Path -LiteralPath $lines)) {
    throw "Missing $lines - re-run from WSL: devbox setup hosts"
  }

  & $apply -InputFile $lines
  if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
    $exitCode = $LASTEXITCODE
  }
} catch {
  Write-Host ''
  Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
  $exitCode = 1
} finally {
  try { Stop-Transcript | Out-Null } catch { }
  if ($exitCode -eq 0) {
    Write-Host ''
    Write-Host 'Success. Optional: ipconfig /flushdns' -ForegroundColor Green
  } else {
    Write-Host ''
    Write-Host "Failed (exit $exitCode). Full log: $logFile" -ForegroundColor Red
  }
  Wait-ForUser
  exit $exitCode
}
