#Requires -Version 5.1
<#
.SYNOPSIS
  Merge dev hostnames from WSL /etc/hosts into the Windows hosts file (Admin).

.DESCRIPTION
  Browsers on Windows read C:\Windows\System32\drivers\etc\hosts, not WSL /etc/hosts.
  Copies lines from the WSL distro hosts file that look like local dev entries
  (.local domains and custom 127.0.0.1 mappings), into a managed block.

.PARAMETER Distro
  WSL distribution name. Default: current distro from WSL_DISTRO_NAME env or Ubuntu.

.PARAMETER DryRun
  Print what would change without writing.
#>
param(
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

function Get-WslHostsText {
  param([string]$Name)
  if (-not $Name) {
    $Name = (wsl.exe -l -q 2>$null | Where-Object { $_ -match '\S' } | Select-Object -First 1)
  }
  if (-not $Name) {
    throw 'Could not detect WSL distro. Pass -Distro Ubuntu (or your distro name).'
  }
  $text = wsl.exe -d $Name -e cat /etc/hosts 2>&1
  if ($LASTEXITCODE -ne 0) {
    throw "Failed to read /etc/hosts from WSL distro '$Name': $text"
  }
  return $text
}

function Get-DevHostLines {
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
  Write-Host 'Re-launching elevated (required to edit Windows hosts)...' -ForegroundColor Yellow
  $argList = @(
    '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath
  )
  if ($Distro) { $argList += @('-Distro', $Distro) }
  if ($DryRun) { $argList += '-DryRun' }
  Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $argList
  exit 0
}

$wslText = Get-WslHostsText -Name $Distro
$devLines = Get-DevHostLines -HostsText $wslText
if ($devLines.Count -eq 0) {
  Write-Host "No dev host lines found in WSL /etc/hosts (looked for .local and 127.0.0.1 entries)." -ForegroundColor Yellow
  Write-Host 'Run your repo setup in WSL first (e.g. just setup), then retry.'
  exit 1
}

Write-Host "Distro: $Distro"
Write-Host 'Dev host entries to sync to Windows:'
$devLines | ForEach-Object { Write-Host "  $_" }

$existing = Get-Content -Path $WinHosts -ErrorAction Stop
$body = Remove-ManagedBlock -Content $existing
$body.Add('')
$body.Add($MarkerBegin)
$body.Add("# Synced from WSL $Distro on $(Get-Date -Format 'yyyy-MM-dd HH:mm')")
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
Write-Host 'Flush DNS (optional): ipconfig /flushdns'
Write-Host 'Test in browser: http://<your-host>.local:<port>  (port is not part of hosts file)'
