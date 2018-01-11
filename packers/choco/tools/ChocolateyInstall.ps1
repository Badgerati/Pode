$ErrorActionPreference = 'Stop'

$packageName    = 'Pode'
$toolsDir       = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
$url            = 'https://github.com/Badgerati/Pode/releases/download/v$version$/$version$-Binaries.zip'
$checksum       = '$checksum$'
$checksumType   = 'sha256'

$packageArgs = @{
  PackageName   = $packageName
  UnzipLocation = $toolsDir
  Url           = $url
  Checksum      = $checksum
  ChecksumType  = $checksumType
}

# Download
Install-ChocolateyZipPackage @packageArgs

# Install Module
# Determine which Program Files path to use
if (![string]::IsNullOrWhiteSpace($env:ProgramFiles))
{
    $modulePath = Join-Path $env:ProgramFiles (Join-Path 'WindowsPowerShell' 'Modules')
}
else
{
    $modulePath = Join-Path ${env:ProgramFiles(x86)} (Join-Path 'WindowsPowerShell' 'Modules')
}

# Check to see if we need to create the Modules path
if (!(Test-Path $modulePath))
{
    Write-Host "Creating path: $modulePath"
    New-Item -ItemType Directory -Path $modulePath -Force | Out-Null
    if (!$?)
    {
        throw "Failed to create: $modulePath"
    }
}

# Check to see if Modules path is in PSModulePaths
$psModules = $env:PSModulePath
if (!$psModules.Contains($modulePath))
{
    Write-Host 'Adding module path to PSModulePaths'
    $psModules += ";$modulePath"
    Install-ChocolateyEnvironmentVariable -VariableName 'PSModulePath' -VariableValue $psModules -VariableType Machine
    $env:PSModulePath = $psModules
}

# Create Pode module
$podeModulePath = Join-Path $modulePath 'Pode'
if (!(Test-Path $podeModulePath))
{
    Write-Host 'Creating Pode module directory'
    New-Item -ItemType Directory -Path $podeModulePath -Force | Out-Null
    if (!$?)
    {
        throw "Failed to create: $podeModulePath"
    }
}

# Copy contents to module
Write-Host 'Copying Pode to module path'

try
{
    Push-Location (Join-Path $env:ChocolateyPackageFolder 'tools/src')

    New-Item -ItemType Directory -Path (Join-Path $podeModulePath 'Tools') -Force | Out-Null
    Copy-Item -Path ./Tools/* -Destination (Join-Path $podeModulePath 'Tools') -Force | Out-Null
    Copy-Item -Path ./Pode.psm1 -Destination $podeModulePath -Force | Out-Null
    Copy-Item -Path ./Pode.psd1 -Destination $podeModulePath -Force | Out-Null
}
finally
{
    Pop-Location
}