#Requires -Version 5.1
<#
.SYNOPSIS
  Prepare or apply Windows hosts sync from WSL-exported lines.

  Default (corporate): -PrepareOnly writes %LOCALAPPDATA%\devbox\ for "Run with elevated access".
  Optional: set DEVBOX_HOSTS_USE_RUNAS=1 to trigger classic UAC RunAs (home machines).
#>
param(
  [string]$InputFile,
  [string]$Distro = $env:WSL_DISTRO_NAME,
  [switch]$PrepareOnly,
  [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$ApplyScriptName = 'Apply-DevHostsElevated.ps1'

function Test-Admin {
  $id = [Security.Principal.WindowsIdentity]::GetCurrent()
  $p = [Security.Principal.WindowsPrincipal]$id
  $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Write-CorporateElevationInstructions {
  param([string]$DevboxDir)
  Write-Host ''
  Write-Host '=== Next step (Windows) ===' -ForegroundColor Cyan
  Write-Host ''
  Write-Host "Files ready in: $DevboxDir"
  Write-Host "Also read: $DevboxDir\START-HERE-hosts.txt"
  Write-Host ''
  Write-Host '.cmd / .ps1 right-click often has NO "Run with elevated access" on corporate PCs.'
  Write-Host 'Use elevated PowerShell from the Start menu instead:'
  Write-Host ''
  Write-Host '  1. Start → PowerShell → right-click → Run with elevated access'
  Write-Host '     (company elevation — NOT domain "Run as administrator")'
  Write-Host ''
  Write-Host '  2. Paste:'
  Write-Host "     cd `"$DevboxDir`""
  Write-Host '     powershell -ExecutionPolicy Bypass -File .\apply-dev-hosts.ps1'
  Write-Host ''
  Write-Host '  3. ipconfig /flushdns   (optional, same window)'
  Write-Host ''
  Write-Host '  Log if needed: apply-dev-hosts.log'
  Write-Host ''
}

function Install-DevboxHostsBundle {
  param(
    [string]$InputFile,
    [string]$SourceApplyScript
  )
  $devboxDir = Join-Path $env:LOCALAPPDATA 'devbox'
  $null = New-Item -ItemType Directory -Path $devboxDir -Force
  $linesDest = Join-Path $devboxDir 'hosts-lines.txt'
  $applyDest = Join-Path $devboxDir $ApplyScriptName
  $launcherPs1 = Join-Path $devboxDir 'apply-dev-hosts.ps1'
  $launcherCmd = Join-Path $devboxDir 'apply-dev-hosts.cmd'
  $readmeDest = Join-Path $devboxDir 'START-HERE-hosts.txt'
  $scriptDir = Split-Path -Parent $SourceApplyScript
  $launcherSource = Join-Path $scriptDir 'apply-dev-hosts.launcher.ps1'
  $cmdSource = Join-Path $scriptDir 'apply-dev-hosts.cmd'
  $readmeSource = Join-Path $scriptDir 'START-HERE-hosts.txt'

  Copy-Item -LiteralPath $InputFile -Destination $linesDest -Force
  Copy-Item -LiteralPath $SourceApplyScript -Destination $applyDest -Force
  Copy-Item -LiteralPath $launcherSource -Destination $launcherPs1 -Force
  Copy-Item -LiteralPath $cmdSource -Destination $launcherCmd -Force
  Copy-Item -LiteralPath $readmeSource -Destination $readmeDest -Force

  return $devboxDir
}

if (-not $InputFile) {
  Write-Host 'Run from WSL: devbox setup hosts' -ForegroundColor Yellow
  exit 1
}
if (-not (Test-Path -LiteralPath $InputFile)) {
  throw "Input file not found: $InputFile"
}

$applySource = Join-Path (Split-Path -Parent $PSCommandPath) $ApplyScriptName
if (-not (Test-Path -LiteralPath $applySource)) {
  throw "Missing $applySource"
}

# Already elevated — apply immediately
if ((Test-Admin) -and -not $PrepareOnly) {
  & $applySource -InputFile $InputFile @PSBoundParameters
  exit $LASTEXITCODE
}

$devboxDir = Install-DevboxHostsBundle -InputFile $InputFile -SourceApplyScript $applySource
Write-Host "Prepared hosts bundle: $devboxDir" -ForegroundColor Green
Get-Content (Join-Path $devboxDir 'hosts-lines.txt') | ForEach-Object { Write-Host "  $_" }

if ($env:DEVBOX_HOSTS_USE_RUNAS -eq '1') {
  Write-Host ''
  Write-Host 'DEVBOX_HOSTS_USE_RUNAS=1 — opening classic UAC elevation...' -ForegroundColor Yellow
  $argList = @(
    '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $devboxDir 'apply-dev-hosts.cmd')
  )
  Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $argList
  exit 0
}

Write-CorporateElevationInstructions -DevboxDir $devboxDir
exit 0
