#Requires -Version 5.1
<#
.SYNOPSIS
  Export Zscaler TLS inspection certificate(s) from Windows certificate stores.

.DESCRIPTION
  Zscaler Client Connector installs corporate root/intermediate CAs into Windows
  stores. This script finds them and exports Base-64 (.CER) for use in WSL devbox.

.PARAMETER OutputPath
  Destination file. Default: %USERPROFILE%\.devbox\certs\zscaler-root.cer

.PARAMETER ListOnly
  Print matching certificates without exporting.

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File .\Export-ZscalerCa.ps1
#>
[CmdletBinding()]
param(
    [string] $OutputPath,
    [switch] $ListOnly
)

$ErrorActionPreference = 'Stop'

if (-not $OutputPath) {
    $OutputPath = Join-Path $env:USERPROFILE '.devbox\certs\zscaler-root.cer'
}

$storePaths = @(
    'Cert:\LocalMachine\Root',
    'Cert:\CurrentUser\Root',
    'Cert:\LocalMachine\CA',
    'Cert:\CurrentUser\CA'
)

function Test-ZscalerCert {
    param([System.Security.Cryptography.X509Certificates.X509Certificate2] $Cert)
    $text = "$($Cert.Subject) $($Cert.Issuer) $($Cert.FriendlyName)"
    return $text -match 'Zscaler'
}

function Get-ZscalerScore {
    param([System.Security.Cryptography.X509Certificates.X509Certificate2] $Cert)
    $score = 0
    if ($Cert.Subject -match 'Root') { $score += 100 }
    if ($Cert.Subject -match 'Zscaler') { $score += 50 }
    if ($Cert.Issuer -eq $Cert.Subject) { $score += 25 }
    return $score
}

$found = @{}
foreach ($storePath in $storePaths) {
    $items = Get-ChildItem -Path $storePath -ErrorAction SilentlyContinue
    foreach ($item in $items) {
        if (-not (Test-ZscalerCert -Cert $item)) { continue }
        $thumb = $item.Thumbprint
        if (-not $found.ContainsKey($thumb)) {
            $found[$thumb] = [PSCustomObject]@{
                Certificate = $item
                Store       = $storePath
                Score       = (Get-ZscalerScore -Cert $item)
            }
        }
    }
}

if ($found.Count -eq 0) {
    Write-Error @"
No Zscaler certificates found in Windows stores.
Ensure Zscaler Client Connector is installed and connected, then retry.
Stores checked: $($storePaths -join ', ')
"@
}

$sorted = $found.Values | Sort-Object -Property Score -Descending

Write-Host "Zscaler certificates found: $($sorted.Count)"
foreach ($entry in $sorted) {
    $c = $entry.Certificate
    Write-Host "  [$($entry.Store)] $($c.Subject)"
    Write-Host "           thumbprint=$($c.Thumbprint) expires=$($c.NotAfter)"
}

if ($ListOnly) {
    exit 0
}

$outDir = Split-Path -Parent $OutputPath
if (-not (Test-Path $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

# Export the best candidate (highest score = likely root) as PEM for WSL/curl
$primary = $sorted[0].Certificate
$raw = $primary.RawData
$b64 = [Convert]::ToBase64String($raw, [System.Base64FormattingOptions]::InsertLineBreaks)
$pem = @(
    '-----BEGIN CERTIFICATE-----'
    $b64
    '-----END CERTIFICATE-----'
) -join [Environment]::NewLine
Set-Content -Path $OutputPath -Value $pem -Encoding ascii -NoNewline
Add-Content -Path $OutputPath -Value ([Environment]::NewLine) -Encoding ascii
Write-Host "Exported primary cert (PEM) -> $OutputPath"

# If multiple distinct Zscaler certs, also write a bundle for chained trust
if ($sorted.Count -gt 1) {
    $bundlePath = [System.IO.Path]::ChangeExtension($OutputPath, '.bundle.cer')
    Remove-Item -Path $bundlePath -Force -ErrorAction SilentlyContinue
    foreach ($entry in $sorted) {
        $tmp = [System.IO.Path]::GetTempFileName()
        try {
            Export-Certificate -Cert $entry.Certificate -FilePath $tmp -Force | Out-Null
            Add-Content -Path $bundlePath -Value (Get-Content -Path $tmp -Raw)
        }
        finally {
            Remove-Item -Path $tmp -Force -ErrorAction SilentlyContinue
        }
    }
    Write-Host "Exported bundle (all matches) -> $bundlePath"
}

Write-Host "WSL path (typical): /mnt/c/Users/$($env:USERNAME)/.devbox/certs/zscaler-root.cer"
