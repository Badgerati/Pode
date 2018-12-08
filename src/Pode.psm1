# get existing functions from memory for later comparison
$sysfuncs = Get-ChildItem Function:

# load pode functions
$root = Split-Path -Parent -Path $MyInvocation.MyCommand.Path
Get-ChildItem "$($root)\Tools\*.ps1" | Resolve-Path | ForEach-Object { . $_ }

# check if there are any extensions and load them
$ext = 'C:/Pode/Extensions'
if ($PSVersionTable.Platform -ieq 'unix') {
    $ext = '/usr/src/pode/extensions'
}

if (Test-Path $ext) {
    Get-ChildItem "$($ext)/*.ps1" | Resolve-Path | ForEach-Object { . $_ }
}

# get functions from memory and compare to existing to find new functions added
$podefuncs = Get-ChildItem Function: | Where-Object { $sysfuncs -notcontains $_ }

# export the module
Export-ModuleMember -Function ($podefuncs.Name)