# Determine which Program Files path to use
if (![string]::IsNullOrEmpty($env:ProgramFiles))
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
    [Environment]::SetEnvironmentVariable('PSModulePath', $psModules)
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
Write-Host 'Copying Pode content to module path'

New-Item -ItemType Directory -Path (Join-Path $podeModulePath 'Tools') -Force | Out-Null
Copy-Item -Path ./src/Tools/* -Destination (Join-Path $podeModulePath 'Tools') -Force | Out-Null

Copy-Item -Path ./src/Pode.psm1 -Destination $podeModulePath -Force | Out-Null
Copy-Item -Path ./src/Pode.psd1 -Destination $podeModulePath -Force | Out-Null
Copy-Item -Path ./LICENSE.txt -Destination $podeModulePath -Force | Out-Null

Write-Host 'Pode installed'