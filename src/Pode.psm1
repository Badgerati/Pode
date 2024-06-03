<#
.SYNOPSIS
    Pode PowerShell Module

.DESCRIPTION
    This module sets up the Pode environment, including
    localization and loading necessary assemblies and functions.

.PARAMETER UICulture
    Specifies the culture to be used for localization.

.EXAMPLE
    Import-Module -Name "Pode" -ArgumentList @{ UICulture = 'ko-KR' }
    Sets the culture to Korean.

.EXAMPLE
    Import-Module -Name "Pode"
    Uses the default culture.

.EXAMPLE
    Import-Module -Name "Pode" -ArgumentList 'it-SM'
    Uses the Italian San Marino region culture.

.NOTES
    This is the entry point for the Pode module.
#>

param(
    [string]$UICulture
)

# root path
$root = Split-Path -Parent -Path $MyInvocation.MyCommand.Path
# Import localized messages
if ([string]::IsNullOrEmpty($UICulture)) {
    $UICulture = $PsUICulture
}

#Culture list available here https://azuliadesigns.com/c-sharp-tutorials/list-net-culture-country-codes/
Import-LocalizedData -BindingVariable tmpPodeLocale -BaseDirectory (Join-Path -Path $root -ChildPath 'Locales') -UICulture $UICulture -ErrorAction:SilentlyContinue
if ($null -eq $tmpPodeLocale) {
    try {
        Import-LocalizedData -BindingVariable tmpPodeLocale -BaseDirectory (Join-Path -Path $root -ChildPath 'Locales') -UICulture 'en' -ErrorAction:Stop
    }
    catch {
        throw
    }
}

try {
    # Create the global msgTable read-only variable
    New-Variable -Name 'PodeLocale' -Value $tmpPodeLocale -Scope script -Option ReadOnly -Force -Description "Localization HashTable"

    # load assemblies
    Add-Type -AssemblyName System.Web -ErrorAction Stop
    Add-Type -AssemblyName System.Net.Http -ErrorAction Stop

    # Construct the path to the module manifest (.psd1 file)
    $moduleManifestPath = Join-Path -Path $root -ChildPath 'Pode.psd1'

    # Import the module manifest to access its properties
    $moduleManifest = Import-PowerShellDataFile -Path $moduleManifestPath -ErrorAction Stop
}
catch {
    throw
}

$podeDll = [AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.GetName().Name -eq 'Pode' }

if ($podeDll) {
    if ( $moduleManifest.ModuleVersion -ne '$version$') {
        $moduleVersion = ([version]::new($moduleManifest.ModuleVersion + '.0'))
        if ($podeDll.GetName().Version -ne $moduleVersion) {
            # An existing incompatible Pode.DLL version {0} is loaded. Version {1} is required. Open a new Powershell/pwsh session and retry.
            throw ($PodeLocale.incompatiblePodeDllExceptionMessage -f $podeDll.GetName().Version, $moduleVersion)
        }
    }
}
else {
    try {
        if ($PSVersionTable.PSVersion -ge [version]'7.4.0') {
            Add-Type -LiteralPath "$($root)/Libs/net8.0/Pode.dll" -ErrorAction Stop
        }
        elseif ($PSVersionTable.PSVersion -ge [version]'7.2.0') {
            Add-Type -LiteralPath "$($root)/Libs/net6.0/Pode.dll" -ErrorAction Stop
        }
        else {
            Add-Type -LiteralPath "$($root)/Libs/netstandard2.0/Pode.dll" -ErrorAction Stop
        }
    }
    catch {
        throw
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
