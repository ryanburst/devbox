#Requires -Version 5.1
<#
.SYNOPSIS
  Prepare or apply Windows hosts sync from WSL-exported lines.

  Uses USERPROFILE\AppData\Local\devbox (not $env:LOCALAPPDATA) — corporate
  profiles often break LOCALAPPDATA (e.g. COMPANY_username_$).
#>
param(
  [string]$InputFile,
  [string]$DevboxDir,
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

function Get-DevboxHostsDir {
  param(
    [string]$InputFile,
    [string]$PreferredDir
  )
  if ($PreferredDir) {
    return $PreferredDir
  }
  # Path WSL used: C:\Users\<user>\AppData\Local\...
  if ($InputFile -match '\\Users\\([^\\]+)\\AppData\\Local\\') {
    $user = $Matches[1]
    return Join-Path "C:\Users\$user\AppData\Local" 'devbox'
  }
  if ($env:USERPROFILE) {
    return Join-Path $env:USERPROFILE 'AppData\Local\devbox'
  }
  $local = [Environment]::GetFolderPath('LocalApplicationData')
  if ($local) {
    return Join-Path $local 'devbox'
  }
  throw 'Could not resolve devbox hosts directory — pass -DevboxDir from WSL'
}

function Write-CorporateElevationInstructions {
  param([string]$DevboxDir)
  Write-Host ''
  Write-Host '=== Next step (Windows) ===' -ForegroundColor Cyan
  Write-Host ''
  Write-Host "Hosts bundle: $DevboxDir"
  Write-Host "Also read: $DevboxDir\START-HERE-hosts.txt"
  Write-Host ''
  Write-Host 'Do NOT use $env:LOCALAPPDATA on corporate PCs (often wrong, e.g. COMPANY_user_$).'
  Write-Host 'Use this exact path:'
  Write-Host ''
  Write-Host '  1. Start → PowerShell → Run with elevated access'
  Write-Host ''
  Write-Host '  2. Paste:'
  Write-Host "     cd `"$DevboxDir`""
  Write-Host '     powershell -ExecutionPolicy Bypass -File .\apply-dev-hosts.ps1'
  Write-Host ''
  Write-Host '  3. ipconfig /flushdns   (optional)'
  Write-Host ''
  Write-Host '  Log: apply-dev-hosts.log'
  Write-Host ''
}

function Write-StartHereFile {
  param([string]$DevboxDir)
  $readme = Join-Path $DevboxDir 'START-HERE-hosts.txt'
  @"
devbox — sync WSL hosts to Windows (browser .local URLs)
========================================================

Your bundle folder (use this exact path):

  $DevboxDir

Corporate PCs: do NOT use %LOCALAPPDATA% or `$env:LOCALAPPDATA
(it may show as COMPANY_username_`$ instead of your real profile).

STEP 1 — PowerShell → Run with elevated access (company menu)

STEP 2 — Paste:

  cd "$DevboxDir"
  powershell -ExecutionPolicy Bypass -File .\apply-dev-hosts.ps1

STEP 3 — Press Enter when you see Success.

STEP 4 — Optional: ipconfig /flushdns

Log on failure: $DevboxDir\apply-dev-hosts.log

Re-prepare from WSL: devbox setup hosts
"@ | Set-Content -LiteralPath $readme -Encoding UTF8
}

function Install-DevboxHostsBundle {
  param(
    [string]$InputFile,
    [string]$SourceApplyScript,
    [string]$TargetDir
  )
  $devboxDir = Get-DevboxHostsDir -InputFile $InputFile -PreferredDir $TargetDir
  $null = New-Item -ItemType Directory -Path $devboxDir -Force
  $linesDest = Join-Path $devboxDir 'hosts-lines.txt'
  $applyDest = Join-Path $devboxDir $ApplyScriptName
  $launcherPs1 = Join-Path $devboxDir 'apply-dev-hosts.ps1'
  $launcherCmd = Join-Path $devboxDir 'apply-dev-hosts.cmd'
  $pathFile = Join-Path $devboxDir 'devbox-hosts-dir.txt'
  $scriptDir = Split-Path -Parent $SourceApplyScript
  $launcherSource = Join-Path $scriptDir 'apply-dev-hosts.launcher.ps1'
  $cmdSource = Join-Path $scriptDir 'apply-dev-hosts.cmd'

  Copy-Item -LiteralPath $InputFile -Destination $linesDest -Force
  Copy-Item -LiteralPath $SourceApplyScript -Destination $applyDest -Force
  Copy-Item -LiteralPath $launcherSource -Destination $launcherPs1 -Force
  Copy-Item -LiteralPath $cmdSource -Destination $launcherCmd -Force
  Set-Content -LiteralPath $pathFile -Value $devboxDir -Encoding ascii -NoNewline
  Write-StartHereFile -DevboxDir $devboxDir

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

if ((Test-Admin) -and -not $PrepareOnly) {
  & $applySource -InputFile $InputFile @PSBoundParameters
  exit $LASTEXITCODE
}

$devboxDir = Install-DevboxHostsBundle -InputFile $InputFile -SourceApplyScript $applySource -TargetDir $DevboxDir
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
