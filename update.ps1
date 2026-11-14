<#
.SYNOPSIS
  Updates the zellij / zellij.portable packages to a Zellij release and packs them into .\out.

.EXAMPLE
  .\update.ps1                 # latest release, only if it is newer than the current package
  .\update.ps1 -Force          # repack the current/latest version even if unchanged
  .\update.ps1 -Tag v0.45.1    # a specific release
#>
[CmdletBinding()]
param(
  [string]$Tag,
  [switch]$Force
)

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'

$root          = $PSScriptRoot
$assetName     = 'zellij-x86_64-pc-windows-msvc.zip'
$portableSpec  = Join-Path $root 'zellij.portable\zellij.portable.nuspec'
$metaSpec      = Join-Path $root 'zellij\zellij.nuspec'
$installScript = Join-Path $root 'zellij.portable\tools\chocolateyInstall.ps1'
$outDir        = Join-Path $root 'out'
$utf8NoBom     = New-Object System.Text.UTF8Encoding($false)

function Set-GhOutput([string]$Name, [string]$Value) {
  if ($env:GITHUB_OUTPUT) { Add-Content -Path $env:GITHUB_OUTPUT -Value "$Name=$Value" }
}

function Update-File([string]$Path, [scriptblock]$Transform) {
  $text = [IO.File]::ReadAllText($Path)
  [IO.File]::WriteAllText($Path, (& $Transform $text), $utf8NoBom)
}

# --- Find the release -------------------------------------------------------
$headers = @{ 'User-Agent' = 'zellij-choco-updater'; 'Accept' = 'application/vnd.github+json' }
if ($env:GITHUB_TOKEN) { $headers.Authorization = "Bearer $env:GITHUB_TOKEN" }

$api     = 'https://api.github.com/repos/zellij-org/zellij/releases'
$release = if ($Tag) { Invoke-RestMethod "$api/tags/$Tag" -Headers $headers }
           else      { Invoke-RestMethod "$api/latest"    -Headers $headers }

$version = $release.tag_name -replace '^v', ''
$asset   = $release.assets | Where-Object name -eq $assetName
if (-not $asset) { throw "Release $($release.tag_name) has no asset named $assetName" }

$current = ([xml][IO.File]::ReadAllText($portableSpec)).package.metadata.version
$hasPlaceholder = (Get-Content $installScript -Raw) -match '__CHECKSUM64__'

Write-Host "Current package version: $current"
Write-Host "Target Zellij release:   $version"

if (-not $Force -and -not $hasPlaceholder -and [version]$version -le [version]$current) {
  Write-Host 'Already up to date.'
  Set-GhOutput 'changed' 'false'
  return
}

# --- Download and checksum --------------------------------------------------
$tmp = Join-Path ([IO.Path]::GetTempPath()) ("zellij-choco-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $tmp | Out-Null
try {
  $zip = Join-Path $tmp $assetName
  Write-Host "Downloading $($asset.browser_download_url)"
  & curl.exe -fsSL --retry 3 -o $zip $asset.browser_download_url
  if ($LASTEXITCODE -ne 0) { throw "Download failed (curl exit $LASTEXITCODE)" }
  $checksum = (Get-FileHash $zip -Algorithm SHA256).Hash.ToLowerInvariant()
  Write-Host "SHA256: $checksum"
} finally {
  Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

# --- Rewrite package sources ------------------------------------------------
$notesUrl = $release.html_url

foreach ($spec in $portableSpec, $metaSpec) {
  Update-File $spec {
    param($t)
    $t = $t -replace '<version>[^<]*</version>', "<version>$version</version>"
    $t = $t -replace '<releaseNotes>[^<]*</releaseNotes>', "<releaseNotes>$notesUrl</releaseNotes>"
    $t -replace '(<dependency id="zellij\.portable" version=")[^"]*(")', "`${1}[$version]`${2}"
  }
}

Update-File $installScript {
  param($t)
  $t = $t -replace "(url64bit\s*=\s*')[^']*(')", "`${1}$($asset.browser_download_url)`${2}"
  $t -replace "(checksum64\s*=\s*')[^']*(')", "`${1}$checksum`${2}"
}

# --- Pack -------------------------------------------------------------------
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
Get-ChildItem $outDir -Filter '*.nupkg' | Remove-Item -Force

foreach ($spec in $portableSpec, $metaSpec) {
  & choco pack $spec --outputdirectory $outDir --limit-output --yes
  if ($LASTEXITCODE -ne 0) { throw "choco pack failed for $spec" }
}

Write-Host "Packed $version into $outDir"
Set-GhOutput 'changed' 'true'
Set-GhOutput 'version' $version
