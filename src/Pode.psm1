# root path
$root = Split-Path -Parent -Path $MyInvocation.MyCommand.Path

# load assemblies
Add-Type -AssemblyName System.Web
Add-Type -AssemblyName System.Net.Http

# netstandard2 for <7.2
if ($PSVersionTable.PSVersion -lt [version]'7.2.0') {
    Add-Type -LiteralPath "$($root)/Libs/netstandard2.0/Pode.dll" -ErrorAction Stop
}
# net6 for =7.2
elseif ($PSVersionTable.PSVersion -lt [version]'7.3.0') {
    Add-Type -LiteralPath "$($root)/Libs/net6.0/Pode.dll" -ErrorAction Stop
}
# net7 for >7.2
else {
    Add-Type -LiteralPath "$($root)/Libs/net7.0/Pode.dll" -ErrorAction Stop
}

# load private functions
Get-ChildItem "$($root)/Private/*.ps1" | ForEach-Object { . ([System.IO.Path]::GetFullPath($_)) }

# only import public functions
$sysfuncs = Get-ChildItem Function:

# load public functions
Get-ChildItem "$($root)/Public/*.ps1" | ForEach-Object { . ([System.IO.Path]::GetFullPath($_)) }

# get functions from memory and compare to existing to find new functions added
$funcs = Get-ChildItem Function: | Where-Object { $sysfuncs -notcontains $_ }

# export the module's public functions
Export-ModuleMember -Function ($funcs.Name)