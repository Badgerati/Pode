# root path
$root = Split-Path -Parent -Path $MyInvocation.MyCommand.Path

# load assemblies
Add-Type -AssemblyName System.Web
Add-Type -AssemblyName System.Net.Http

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
    return $moduleManifest.ModuleVersion -eq '$version$'
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
    if (! (Test-PodeDevelop)) {
        # Check if the PowerShell edition is Core and the version is earlier than the last version tested
        if ($PSVersionTable.PSEdition -eq 'Core' -and $PSVersionTable.PSVersion -lt [version]$moduleManifest.PrivateData.PwshCoreVersionUntested) {
            Write-Host "This PowerShell version $($PSVersionTable.PSVersion) was EOL when Pode $(Get-PodeVersion) was released. Pode should work but has not been tested." -ForegroundColor Yellow
            return $true
        }
    }
    return $false
}

# Construct the path to the module manifest (.psd1 file)
$moduleManifestPath = Join-Path -Path $PSScriptRoot -ChildPath 'Pode.psd1'

# Import the module manifest to access its properties
$moduleManifest = Import-PowerShellDataFile -Path $moduleManifestPath

$podeDll = [AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.GetName().Name -like 'Pode' }

if ($podeDll) {
    if (! (Test-PodeDevelop)) {
        $moduleVersion = ([version]::new($moduleManifest.ModuleVersion + '.0'))
        if ( $podeDll.GetName().Version.CompareTo($moduleVersion) -ne 0) {
            throw "An existing incompatible Pode.DLL version $($podeDll.GetName().Version) is loaded. Version $moduleVersion is required. Open a new Powershell/pwsh session and retry."
        }
    }
}
else {
    # netstandard2 for any Powershell Core version EOL or Desktop
    if (($PSVersionTable.PSEdition -eq 'Desktop') -or ($PSVersionTable.PSVersion -lt [version]$moduleManifest.PrivateData.PwshCoreVersionUntested)) {
        Add-Type -LiteralPath "$($root)/Libs/netstandard2.0/Pode.dll" -ErrorAction Stop
    }
    # net7 for =7.3
    elseif ($PSVersionTable.PSVersion -lt [version]'7.4.0') {
        Add-Type -LiteralPath "$($root)/Libs/net7.0/Pode.dll" -ErrorAction Stop
    }
    # net8 for =7.4
    else {
        Add-Type -LiteralPath "$($root)/Libs/net8.0/Pode.dll" -ErrorAction Stop
    }
}

# load private functions
Get-ChildItem "$($root)/Private/*.ps1" | ForEach-Object { . ([System.IO.Path]::GetFullPath($_)) }

# only import public functions
$sysfuncs = Get-ChildItem Function:

# only import public alias
$sysaliases = Get-ChildItem Alias:

# load public functions
Get-ChildItem "$($root)/Public/*.ps1" | ForEach-Object { . ([System.IO.Path]::GetFullPath($_)) }

# get functions from memory and compare to existing to find new functions added
$funcs = Get-ChildItem Function: | Where-Object { $sysfuncs -notcontains $_ }
$aliases = Get-ChildItem Alias: | Where-Object { $sysaliases -notcontains $_ }
# export the module's public functions
if ($funcs) {
    if ($aliases) {
        Export-ModuleMember -Function ($funcs.Name) -Alias $aliases.Name
    }
    else {
        Export-ModuleMember -Function ($funcs.Name)
    }
}
