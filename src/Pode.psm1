# import everything if in a runspace
if ($PODE_IN_RUNSPACE) {
    $sysfuncs = Get-ChildItem Function:
}

# load private functions
$root = Split-Path -Parent -Path $MyInvocation.MyCommand.Path
Get-ChildItem "$($root)/Private/*.ps1" | Resolve-Path | ForEach-Object { . $_ }

# get existing functions from memory for later comparison
if (!$PODE_IN_RUNSPACE) {
    $sysfuncs = Get-ChildItem Function:
}

# load public functions
Get-ChildItem "$($root)/Public/*.ps1" | Resolve-Path | ForEach-Object { . $_ }

# get functions from memory and compare to existing to find new functions added
$funcs = Get-ChildItem Function: | Where-Object { $sysfuncs -notcontains $_ }

# export the module's public functions
Export-ModuleMember -Function ($funcs.Name)