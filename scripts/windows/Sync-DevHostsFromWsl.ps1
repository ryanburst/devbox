#Requires -Version 5.1
<#
.SYNOPSIS
  Merge dev hostnames into the Windows hosts file (Admin).

.DESCRIPTION
  Elevated PowerShell often cannot run wsl.exe. Run from WSL via sync-hosts-to-windows.sh,
  which writes lines to a temp file and passes -InputFile so the admin session never calls WSL.

.PARAMETER InputFile
  Windows path to a text file with one hosts line per row (required when elevating).

.PARAMETER Distro
  WSL distro name — only used when -InputFile is omitted (non-elevated dev only).

.PARAMETER DryRun
  Print what would change without writing.
#>
param(
  [string]$InputFile,
  [string]$Distro = $env:WSL_DISTRO_NAME,
  [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$MarkerBegin = '# BEGIN devbox-managed hosts (from WSL)'
$MarkerEnd = '# END devbox-managed hosts'
$WinHosts = Join-Path $env:Windir 'System32\drivers\etc\hosts'

function Test-Admin {
  $id = [Security.Principal.WindowsIdentity]::GetCurrent()
  $p = [Security.Principal.WindowsPrincipal]$id
  $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-DevHostLinesFromText {
  param([string]$HostsText)
  $lines = @()
  foreach ($line in ($HostsText -split "`n")) {
    $t = $line.Trim()
    if (-not $t -or $t.StartsWith('#')) { continue }
    if ($t -match '^\s*127\.0\.0\.1\s+localhost(\s|$)') { continue }
    if ($t -match '^\s*::1\s+') { continue }
    if ($t -match '\.local\b' -or $t -match '^\s*127\.0\.0\.1\s+\S') {
      $lines += $t
    }
  }
  return $lines | Select-Object -Unique
}

function Get-WslHostsText {
  param([string]$Name)
  if (-not $Name) {
    $Name = (wsl.exe -l -q 2>$null | Where-Object { $_ -match '\S' } | Select-Object -First 1)
  }
  if (-not $Name) {
    throw 'Could not detect WSL distro. Run from WSL: devbox setup hosts'
  }
  $text = wsl.exe -d $Name -e cat /etc/hosts 2>&1
  if ($LASTEXITCODE -ne 0) {
    throw "Failed to read /etc/hosts from WSL distro '$Name': $text"
  }
  return $text
}

function Remove-ManagedBlock {
  param([string[]]$Content)
  $out = New-Object System.Collections.Generic.List[string]
  $skip = $false
  foreach ($line in $Content) {
    if ($line -eq $MarkerBegin) { $skip = $true; continue }
    if ($line -eq $MarkerEnd) { $skip = $false; continue }
    if (-not $skip) { $out.Add($line) }
  }
  return $out
}

if (-not (Test-Admin)) {
  if (-not $InputFile) {
    Write-Host 'Run from WSL: devbox setup hosts' -ForegroundColor Yellow
    Write-Host '(Reads /etc/hosts in WSL, then elevates using a temp file — no wsl in Admin PowerShell.)'
    exit 1
  }
  if (-not (Test-Path -LiteralPath $InputFile)) {
    throw "Input file not found: $InputFile"
  }
  Write-Host 'Opening elevated PowerShell (Admin) to update Windows hosts...' -ForegroundColor Yellow
  Write-Host 'Elevated window does not need WSL — it only reads the temp file.' -ForegroundColor DarkGray
  $argList = @(
    '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath,
    '-InputFile', $InputFile
  )
  if ($DryRun) { $argList += '-DryRun' }
  Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $argList
  exit 0
}

if ($InputFile) {
  if (-not (Test-Path -LiteralPath $InputFile)) {
    throw "Input file not found: $InputFile"
  }
  $hostsText = Get-Content -LiteralPath $InputFile -Raw
  $sourceNote = "file $InputFile"
} else {
  $hostsText = Get-WslHostsText -Name $Distro
  $sourceNote = "WSL distro $Distro"
}

$devLines = Get-DevHostLinesFromText -HostsText $hostsText
if ($devLines.Count -eq 0) {
  Write-Host 'No dev host lines found (.local or 127.0.0.1 entries).' -ForegroundColor Yellow
  Write-Host 'Run your repo setup in WSL first (e.g. just setup), then: devbox setup hosts'
  exit 1
}

Write-Host "Source: $sourceNote"
Write-Host 'Dev host entries for Windows hosts:'
$devLines | ForEach-Object { Write-Host "  $_" }

$existing = Get-Content -Path $WinHosts -ErrorAction Stop
$body = Remove-ManagedBlock -Content $existing
$body.Add('')
$body.Add($MarkerBegin)
$body.Add("# Synced on $(Get-Date -Format 'yyyy-MM-dd HH:mm') from $sourceNote")
foreach ($l in $devLines) { $body.Add($l) }
$body.Add($MarkerEnd)
$body.Add('')

$newContent = ($body -join "`r`n").TrimEnd() + "`r`n"

if ($DryRun) {
  Write-Host "`n--- Would write to $WinHosts ---"
  Write-Host $newContent
  exit 0
}

Set-Content -Path $WinHosts -Value $newContent -Encoding ascii
Write-Host "`nUpdated Windows hosts: $WinHosts" -ForegroundColor Green
Write-Host 'Optional: ipconfig /flushdns'
Write-Host 'Test: http://<hostname>.local:<port> in your Windows browser'
if ($InputFile) {
  Remove-Item -LiteralPath $InputFile -Force -ErrorAction SilentlyContinue
}
