# root path
$root = Split-Path -Parent -Path $MyInvocation.MyCommand.Path

# import everything
$sysfuncs = Get-ChildItem Function:

# load private functions
Get-ChildItem -Path "$($root)/Private/*.ps1" -Recurse | ForEach-Object { . ([System.IO.Path]::GetFullPath($_)) }

# load public functions
Get-ChildItem -Path "$($root)/Public/*.ps1" -Recurse | ForEach-Object { . ([System.IO.Path]::GetFullPath($_)) }


# get functions from memory and compare to existing to find new functions added
$funcs = Get-ChildItem Function: | Where-Object { $sysfuncs -notcontains $_ }

# export the module's public functions
Export-ModuleMember -Function ($funcs.Name)

# Ensure backward compatibility by creating aliases for legacy Pode OpenAPI function names.
New-PodeFunctionAlias