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
  Write-Host '=== Next step (Windows, corporate elevation) ===' -ForegroundColor Cyan
  Write-Host ''
  Write-Host "Files ready in: $DevboxDir"
  Write-Host ''
  Write-Host 'Do NOT use "Run as administrator" (domain admin password).'
  Write-Host 'Use your company elevation instead:'
  Write-Host ''
  Write-Host '  Option A — Explorer'
  Write-Host "    1. Win+R → paste: $DevboxDir"
  Write-Host '    2. Right-click apply-dev-hosts.ps1'
  Write-Host '    3. Choose "Run with elevated access" (or your company equivalent)'
  Write-Host ''
  Write-Host '  Option B — Elevated PowerShell (via company menu)'
  Write-Host "    cd `"$DevboxDir`""
  Write-Host '    powershell -ExecutionPolicy Bypass -File .\apply-dev-hosts.ps1'
  Write-Host ''
  Write-Host '  Then: ipconfig /flushdns'
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
  $launcher = Join-Path $devboxDir 'apply-dev-hosts.ps1'

  Copy-Item -LiteralPath $InputFile -Destination $linesDest -Force
  Copy-Item -LiteralPath $SourceApplyScript -Destination $applyDest -Force

  @"
# devbox — run this file with your company's "Run with elevated access"
`$ErrorActionPreference = 'Stop'
`$here = Split-Path -Parent `$MyInvocation.MyCommand.Path
& "`$here\$ApplyScriptName" -InputFile "`$here\hosts-lines.txt"
if (`$LASTEXITCODE -ne 0) { exit `$LASTEXITCODE }
Write-Host ''
Write-Host 'Success. You can close this window.' -ForegroundColor Green
"@ | Set-Content -Path $launcher -Encoding UTF8

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
    '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $devboxDir 'apply-dev-hosts.ps1')
  )
  Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $argList
  exit 0
}

Write-CorporateElevationInstructions -DevboxDir $devboxDir
exit 0
