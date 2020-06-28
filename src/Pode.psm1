# root path
$root = Split-Path -Parent -Path $MyInvocation.MyCommand.Path

# load binaries
Add-Type -AssemblyName System.Web
Add-Type -AssemblyName System.Net.Http
Add-Type -LiteralPath "$($root)/Libs/Pode.dll"

# import everything if in a runspace
if ($PODE_SCOPE_RUNSPACE) {
    $sysfuncs = Get-ChildItem Function:
}

# load private functions
Get-ChildItem "$($root)/Private/*.ps1" | Resolve-Path | ForEach-Object { . $_ }

# only import public functions if not in a runspace
if (!$PODE_SCOPE_RUNSPACE) {
    $sysfuncs = Get-ChildItem Function:
}

# load public functions
Get-ChildItem "$($root)/Public/*.ps1" | Resolve-Path | ForEach-Object { . $_ }

# get functions from memory and compare to existing to find new functions added
$funcs = Get-ChildItem Function: | Where-Object { $sysfuncs -notcontains $_ }

# export the module's public functions
Export-ModuleMember -Function ($funcs.Name)