$ErrorActionPreference = 'Stop'

$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

# Values below are rewritten by update.ps1 - do not edit by hand.
$packageArgs = @{
  packageName    = $env:ChocolateyPackageName
  unzipLocation  = $toolsDir
  url64bit       = 'https://github.com/zellij-org/zellij/releases/download/v0.46.0/zellij-x86_64-pc-windows-msvc.zip'
  checksum64     = 'be19eed784ed3dd22a3b179b8b79086c0e3ee67ddc836092a1ea9d4306dfd934'
  checksumType64 = 'sha256'
}

# Zellij only ships x64 Windows builds; url64bit-only makes choco refuse on 32-bit OSes.
Install-ChocolateyZipPackage @packageArgs

# Every .exe extracted into $toolsDir is automatically shimmed onto PATH by Chocolatey.
