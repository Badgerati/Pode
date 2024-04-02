<#
.SYNOPSIS
Retrieves the PowerShell module manifest object for the specified module.

.DESCRIPTION
This function constructs the path to a PowerShell module manifest file (.psd1) located in the parent directory of the script root. It then imports the module manifest file to access its properties and returns the manifest object. This can be useful for scripts that need to dynamically discover and utilize module metadata, such as version, dependencies, and exported functions.

.PARAMETERS
This function does not accept any parameters.

.EXAMPLE
$manifest = Get-ModuleManifest
This example calls the `Get-ModuleManifest` function to retrieve the module manifest object and stores it in the variable `$manifest`.

#>
function Get-ModuleManifest {
    # Construct the path to the module manifest (.psd1 file)
    $moduleManifestPath = Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath 'Pode.psd1'

    # Import the module manifest to access its properties
    $moduleManifest = Import-PowerShellDataFile -Path $moduleManifestPath
    return  $moduleManifest
}


<#
.SYNOPSIS
Gets the version of the Pode module.

.DESCRIPTION
The Get-PodeVersion function checks the version of the Pode module specified in the module manifest. If the module version is not a placeholder value ('$version$'), it returns the actual version prefixed with 'v.'. If the module version is the placeholder value, indicating the development branch, it returns '[develop branch]'.

.PARAMETER None
This function does not accept any parameters.

.OUTPUTS
System.String
Returns a string indicating the version of the Pode module or '[develop branch]' if on a development version.

.EXAMPLE
PS> $moduleManifest = @{ ModuleVersion = '1.2.3' }
PS> Get-PodeVersion

Returns 'v.1.2.3'.

.EXAMPLE
PS> $moduleManifest = @{ ModuleVersion = '$version$' }
PS> Get-PodeVersion

Returns '[develop branch]'.

.NOTES
This function assumes that $moduleManifest is a hashtable representing the loaded module manifest, with a key of ModuleVersion.

#>
function Get-PodeVersion {
    $moduleManifest = Get-ModuleManifest
    if ($moduleManifest.ModuleVersion -ne '$version$') {
        return "v.$($moduleManifest.ModuleVersion)"
    }
    else {
        return '[develop branch]'
    }
}

<#
.SYNOPSIS
Tests if the Pode module is from the development branch.

.DESCRIPTION
The Test-PodeDevelop function checks if the Pode module's version matches the placeholder value ('$version$'), which is used to indicate the development branch of the module. It returns $true if the version matches, indicating the module is from the development branch, and $false otherwise.

.PARAMETER None
This function does not accept any parameters.

.OUTPUTS
System.Boolean
Returns $true if the Pode module version is '$version$', indicating the development branch. Returns $false for any other version.

.EXAMPLE
PS> $moduleManifest = @{ ModuleVersion = '$version$' }
PS> Test-PodeDevelop

Returns $true, indicating the development branch.

.EXAMPLE
PS> $moduleManifest = @{ ModuleVersion = '1.2.3' }
PS> Test-PodeDevelop

Returns $false, indicating a specific release version.

.NOTES
This function assumes that $moduleManifest is a hashtable representing the loaded module manifest, with a key of ModuleVersion.

#>
function Test-PodeDevelop {
    return (Get-ModuleManifest).ModuleVersion -eq '$version$'
}


<#
.SYNOPSIS
Tests if the current PowerShell version is considered End-of-Life (EOL).

.DESCRIPTION
The Test-PSVersionEOL function checks if the PowerShell session is running on the Core edition and if the version is earlier than $moduleManifest.PrivateData.PwshCoreVersionUntested. If both conditions are met, it indicates that the PowerShell version is EOL. A warning message is displayed, noting that while Pode should still function, it has not been tested on EOL versions.

.PARAMETER None
This function does not accept any parameters.

.EXAMPLE
PS> Test-PSVersionEOL

If running on PowerShell Core version earlier than $moduleManifest.PrivateData.PwshCoreVersionUntested, you will see a warning message indicating the version is EOL.

#>
function Test-PSVersionEOL {
    $moduleManifest = Get-ModuleManifest
    if ($moduleManifest.ModuleVersion -ne '$version$') {
        # Check if the PowerShell edition is Core and the version is earlier than the last version tested
        if ($PSVersionTable.PSEdition -eq 'Core' -and $PSVersionTable.PSVersion -lt [version]$moduleManifest.PrivateData.PwshCoreVersionUntested) {
            Write-Host "This PowerShell version $($PSVersionTable.PSVersion) was EOL when Pode $(Get-PodeVersion) was released. Pode should work but has not been tested." -ForegroundColor Yellow
            return $true
        }
    }
    return $false
}
