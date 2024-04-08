# root path
$root = Split-Path -Parent -Path $MyInvocation.MyCommand.Path

# load assemblies
Add-Type -AssemblyName System.Web
Add-Type -AssemblyName System.Net.Http

# Construct the path to the module manifest (.psd1 file)
$moduleManifestPath = Join-Path -Path $root -ChildPath 'Pode.psd1'

# Import the module manifest to access its properties
$moduleManifest = Import-PowerShellDataFile -Path $moduleManifestPath

$podeDll = [AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.GetName().Name -eq 'Pode' }

if ($podeDll) {
    if ( $moduleManifest.ModuleVersion -ne '$version$') {
        $moduleVersion = ([version]::new($moduleManifest.ModuleVersion + '.0'))
        if ($podeDll.GetName().Version -ne $moduleVersion) {
            throw "An existing incompatible Pode.DLL version $($podeDll.GetName().Version) is loaded. Version $moduleVersion is required. Open a new Powershell/pwsh session and retry."
        }
    }
}
else {
    if ($PSVersionTable.PSVersion -ge [version]'7.4.0') {
        Add-Type -LiteralPath "$($root)/Libs/net8.0/Pode.dll" -ErrorAction Stop
    }
    elseif ($PSVersionTable.PSVersion -ge [version]'7.3.0') {
        Add-Type -LiteralPath "$($root)/Libs/net7.0/Pode.dll" -ErrorAction Stop
    }
    elseif ($PSVersionTable.PSVersion -ge [version]'7.2.0') {
        Add-Type -LiteralPath "$($root)/Libs/net6.0/Pode.dll" -ErrorAction Stop
    }
    else {
        Add-Type -LiteralPath "$($root)/Libs/netstandard2.0/Pode.dll" -ErrorAction Stop
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
