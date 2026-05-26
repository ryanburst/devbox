#Requires -Version 5.1
<#
.SYNOPSIS
  Apply dev host lines to the Windows hosts file. Must run in an elevated shell.

  Corporate laptops: use your company's "Run with elevated access" on PowerShell,
  then run apply-dev-hosts.ps1 from %LOCALAPPDATA%\devbox\ (created by devbox setup hosts).
#>
param(
  [Parameter(Mandatory = $true)]
  [string]$InputFile,
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
  Write-Host ''
  Write-Host 'This shell is not elevated.' -ForegroundColor Red
  Write-Host ''
  Write-Host 'On corporate Windows, do NOT use "Run as administrator" (domain admin password).'
  Write-Host 'Instead:'
  Write-Host '  1. Open PowerShell via your company menu: "Run with elevated access"'
  Write-Host '  2. cd $env:LOCALAPPDATA\devbox'
  Write-Host '  3. powershell -ExecutionPolicy Bypass -File .\apply-dev-hosts.ps1'
  Write-Host ''
  Write-Host 'Or right-click apply-dev-hosts.cmd → Run with elevated access'
  Write-Host 'If a window flashes and closes, read apply-dev-hosts.log in that folder.'
  Write-Host ''
  Read-Host 'Press Enter to close'
  exit 1
}

if (-not (Test-Path -LiteralPath $InputFile)) {
  throw "Input file not found: $InputFile`nRe-run from WSL: devbox setup hosts"
}

$hostsText = Get-Content -LiteralPath $InputFile -Raw
$devLines = Get-DevHostLinesFromText -HostsText $hostsText
if ($devLines.Count -eq 0) {
  Write-Host 'No dev host lines in input file.' -ForegroundColor Yellow
  exit 1
}

Write-Host 'Applying to Windows hosts:'
$devLines | ForEach-Object { Write-Host "  $_" }

$existing = Get-Content -Path $WinHosts -ErrorAction Stop
$body = Remove-ManagedBlock -Content $existing
$body.Add('')
$body.Add($MarkerBegin)
$body.Add("# Applied $(Get-Date -Format 'yyyy-MM-dd HH:mm') from devbox")
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
Write-Host "`nUpdated: $WinHosts" -ForegroundColor Green
Write-Host 'Optional: ipconfig /flushdns'
Write-Host 'Test in browser: http://<name>.local:<port>'
