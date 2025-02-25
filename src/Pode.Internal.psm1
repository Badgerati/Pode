# root path
$root = Split-Path -Parent -Path $MyInvocation.MyCommand.Path
write-podehost $root
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

# Alias
if (!(Test-Path Alias:New-PodeOASchemaProperty)) {
    New-Alias New-PodeOASchemaProperty -Value New-PodeOAComponentSchemaProperty
}

if (!(Test-Path Alias:Enable-PodeOpenApiViewer)) {
    New-Alias Enable-PodeOpenApiViewer -Value Enable-PodeOAViewer
}

if (!(Test-Path Alias:Enable-PodeOA)) {
    New-Alias Enable-PodeOA -Value Enable-PodeOpenApi
}

if (!(Test-Path Alias:Get-PodeOpenApiDefinition)) {
    New-Alias Get-PodeOpenApiDefinition -Value Get-PodeOADefinition
}
