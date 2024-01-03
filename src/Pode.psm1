# root path
$root = Split-Path -Parent -Path $MyInvocation.MyCommand.Path

# load assemblies
Add-Type -AssemblyName System.Web
Add-Type -AssemblyName System.Net.Http

# Construct the path to the module manifest (.psd1 file)
$moduleManifestPath = Join-Path -Path $PSScriptRoot -ChildPath "Pode.psd1"

# Import the module manifest to access its properties
$moduleManifest = Import-PowerShellDataFile -Path $moduleManifestPath
$moduleVersion=([version]::new($moduleManifest.ModuleVersion+".0"))

$podeDll = [AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.GetName().Name -like 'Pode' }

if ($podeDll) {
    if ($moduleVersion -ne '$version$' -and $podeDll.GetName().Version.CompareTo($moduleVersion) -ne 0) {
        throw "An existing incompatible Pode.DLL version $($podeDll.GetName().Version) is loaded. Version $moduleVersion is required. Open a new Powershell/pwsh session and retry."
    }
} else {
    # netstandard2 for <7.2
    if ($PSVersionTable.PSVersion -lt [version]'7.2.0') {
        Add-Type -LiteralPath "$($root)/Libs/netstandard2.0/Pode.dll" -ErrorAction Stop
    }
    # net6 for =7.2
    elseif ($PSVersionTable.PSVersion -lt [version]'7.3.0') {
        Add-Type -LiteralPath "$($root)/Libs/net6.0/Pode.dll" -ErrorAction Stop
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
    } else {
        Export-ModuleMember -Function ($funcs.Name)
    }
}
