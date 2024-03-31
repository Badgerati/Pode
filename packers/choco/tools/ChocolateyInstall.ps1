$ErrorActionPreference = 'Stop'


# create the module directory, and copy files over
function Install-PodeModule($path, $version)
{
    # Create module
    $path = Join-Path $path 'Pode'
    if (![string]::IsNullOrWhiteSpace($version)) {
        $path = Join-Path $path $version
    }

    if (!(Test-Path $path))
    {
        Write-Host "Creating module directory: $($path)"
        New-Item -ItemType Directory -Path $path -Force | Out-Null
        if (!$?) {
            throw "Failed to create: $path"
        }
    }

    # Copy contents to module
    Write-Host 'Copying scripts to module path'

    try
    {
        Push-Location (Join-Path $toolsDir 'src')

        # which folders do we need?
        $folders = @('Private', 'Public', 'Misc', 'Libs')

        # create the directories, then copy the source
        $folders | ForEach-Object {
            New-Item -ItemType Directory -Path (Join-Path $path $_) -Force | Out-Null
            Copy-Item -Path "./$($_)/*" -Destination (Join-Path $path $_) -Force -Recurse | Out-Null
        }

        # copy general files
        Copy-Item -Path ./Pode.psm1 -Destination $path -Force | Out-Null
        Copy-Item -Path ./Pode.psd1 -Destination $path -Force | Out-Null
        Copy-Item -Path ./Pode.Internal.psm1 -Destination $path -Force | Out-Null
        Copy-Item -Path ./Pode.Internal.psd1 -Destination $path -Force | Out-Null
        Copy-Item -Path ./LICENSE.txt -Destination $path -Force | Out-Null
    }
    finally {
        Pop-Location
    }
}



# Determine which Program Files path to use
$progFiles = [string]$env:ProgramFiles

# determine the path to choco tools
$toolsDir = Split-Path -Path (Split-Path -Parent $MyInvocation.MyCommand.Definition)

# Install PS Module
# Set the module path
$modulePath = Join-Path $progFiles (Join-Path 'WindowsPowerShell' 'Modules')

# Check to see if Modules path is in PSModulePaths
$psModules = $env:PSModulePath
if (!$psModules.Contains($modulePath))
{
    Write-Host 'Adding module path to PSModulePaths'
    $psModules += ";$modulePath"
    Install-ChocolateyEnvironmentVariable -VariableName 'PSModulePath' -VariableValue $psModules -VariableType Machine
    $env:PSModulePath = $psModules
}

# create the module
if ($PSVersionTable.PSVersion.Major -ge 5) {
    Install-PodeModule $modulePath '2.10.0'
}
else {
    Install-PodeModule $modulePath
}


# Install PS-Core Module
$def = (Get-Command pwsh -ErrorAction SilentlyContinue).Definition

if (![string]::IsNullOrWhiteSpace($def))
{
    # Set the module path
    $modulePath = Join-Path $progFiles (Join-Path 'PowerShell' 'Modules')

    # create the module
    Install-PodeModule $modulePath '2.10.0'
}
