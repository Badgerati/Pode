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

.EXAMPLE
    try {
        Import-Module -Name Pode -MaximumVersion 2.99.99
    } catch {
        Write-Error "Failed to load the Pode module"
        throw
    }
    The import statement is within a try/catch block.
    This way, if the module fails to load, your script won’t proceed, preventing possible errors or unexpected behavior.

    .NOTES
    This is the entry point for the Pode module.

#>

param(
    [string]$UICulture
)

# root path
$root = Split-Path -Parent -Path $MyInvocation.MyCommand.Path
$localesPath = (Join-Path -Path $root -ChildPath 'Locales')

# Import localized messages
if ([string]::IsNullOrEmpty($UICulture)) {
    $UICulture = $PsUICulture
}

try {
    try {
        #The list of all available supported culture is available here https://azuliadesigns.com/c-sharp-tutorials/list-net-culture-country-codes/

        # ErrorAction:SilentlyContinue is not sufficient to avoid Import-LocalizedData to generate an exception when the Culture file is not the right format
        Import-LocalizedData -BindingVariable tmpPodeLocale -BaseDirectory $localesPath -UICulture $UICulture -ErrorAction:SilentlyContinue
        if ($null -eq $tmpPodeLocale) {
            $UICulture = 'en'
            Import-LocalizedData -BindingVariable tmpPodeLocale -BaseDirectory $localesPath -UICulture $UICulture -ErrorAction:Stop
        }
    }
    catch {
        throw ("Failed to Import Localized Data $(Join-Path -Path $localesPath -ChildPath  $UICulture -AdditionalChildPath 'Pode.psd1') $_")
    }

    # Create the global msgTable read-only variable
    New-Variable -Name 'PodeLocale' -Value $tmpPodeLocale -Scope script -Option ReadOnly -Force -Description 'Localization HashTable'

    # load assemblies
    Add-Type -AssemblyName System.Web -ErrorAction Stop
    Add-Type -AssemblyName System.Net.Http -ErrorAction Stop

    # Construct the path to the module manifest (.psd1 file)
    $moduleManifestPath = Join-Path -Path $root -ChildPath 'Pode.psd1'

    # Import the module manifest to access its properties
    $PodeManifest = Import-PowerShellDataFile -Path $moduleManifestPath -ErrorAction Stop


    $podeDll = [AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.GetName().Name -eq 'Pode' }

    if ($podeDll) {
        if ( $PodeManifest.ModuleVersion -ne '$version$') {
            $moduleVersion = ([version]::new($PodeManifest.ModuleVersion + '.0'))
            if ($podeDll.GetName().Version -ne $moduleVersion) {
                # An existing incompatible Pode.DLL version {0} is loaded. Version {1} is required. Open a new Powershell/pwsh session and retry.
                throw ($PodeLocale.incompatiblePodeDllExceptionMessage -f $podeDll.GetName().Version, $moduleVersion)
            }
            $assemblyInformationalVersion = $podeDll.CustomAttributes.Where({ $_.AttributeType -eq [System.Reflection.AssemblyInformationalVersionAttribute] })
            if ($null -ne $PodeManifest.PrivateData.PSData.Prerelease) {
                if (! $assemblyInformationalVersion.ConstructorArguments.Value.Contains($PodeManifest.PrivateData.PSData.Prerelease)) {
                    throw ($PodeLocale.incompatiblePodeDllExceptionMessage -f $assemblyInformationalVersion.ConstructorArguments.Value, "$moduleVersion-$($PodeManifest.PrivateData.PSData.Prerelease)")
                }
            }elseif($assemblyInformationalVersion.ConstructorArguments.Value.Contains('-')){
                throw ($PodeLocale.incompatiblePodeDllExceptionMessage -f $assemblyInformationalVersion.ConstructorArguments.Value, $moduleVersion)
            }
        }
    }
    else {
        # fetch the .net version and the libs path
        $version = [System.Environment]::Version.Major
        $libsPath = "$($root)/Libs"

        # filter .net dll folders based on version above, and get path for latest version found
        if (![string]::IsNullOrWhiteSpace($version)) {
            $netFolder = Get-ChildItem -Path $libsPath -Directory -Force |
                Where-Object { $_.Name -imatch "net[1-$($version)]" } |
                Sort-Object -Property Name -Descending |
                Select-Object -First 1 -ExpandProperty FullName
        }

        # use netstandard if no folder found
        if ([string]::IsNullOrWhiteSpace($netFolder)) {
            $netFolder = "$($libsPath)/netstandard2.0"
        }

        # append Pode.dll and mount
        Add-Type -LiteralPath "$($netFolder)/Pode.dll" -ErrorAction Stop
    }

    # load private functions
    Get-ChildItem "$($root)/Private/*.ps1" | ForEach-Object { . ([System.IO.Path]::GetFullPath($_)) }

    # only import public functions
    $sysfuncs = Get-ChildItem Function:

    # only import public alias
    $sysaliases = Get-ChildItem Alias:

    # load public functions
    Get-ChildItem "$($root)/Public/*.ps1" | ForEach-Object { . ([System.IO.Path]::GetFullPath($_)) }

    # Ensure backward compatibility by creating aliases for legacy Pode OpenAPI function names.
    New-PodeFunctionAlias

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

    # Define Properties Display
    if (!(Get-TypeData -TypeName 'PodeService')) {
        $TypeData = @{
            TypeName                  = 'PodeService'
            DefaultDisplayPropertySet = 'Name', 'Status', 'Pid'
        }
        Update-TypeData @TypeData
    }
}
catch {
    throw ("Failed to load the Pode module. $_")
}
finally {
    # Cleanup temporary variables
    Remove-Variable -Name 'tmpPodeLocale', 'localesPath', 'root', 'version', 'libsPath', 'netFolder', 'podeDll', 'sysfuncs', 'sysaliases', 'funcs', 'aliases', 'moduleManifestPath', 'moduleVersion' -ErrorAction SilentlyContinue
}
