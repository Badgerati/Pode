
# test running as admin
function Test-AdminUser
{
    # check the current platform, if it's unix then return true
    if ($PSVersionTable.Platform -ieq 'unix')
    {
        return $true
    }

    try
    {
        $principal = New-Object System.Security.Principal.WindowsPrincipal([System.Security.Principal.WindowsIdentity]::GetCurrent())

        if ($principal -eq $null)
        {
            return $false
        }

        return $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch [exception]
    {
        Write-Host 'Error checking user administrator priviledges' -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        return $false
    }
}

if (!(Test-AdminUser))
{
    throw 'Must be running with administrator priviledges to use pode module'
}


# get existing functions from memory for later comparison
$sysfuncs = Get-ChildItem Function:

# load pode functions
$root = Split-Path -Parent -Path $MyInvocation.MyCommand.Path
Get-ChildItem "$($root)\Tools\*.ps1" | Resolve-Path | ForEach-Object { . $_ }

# check if there are any extensions and load them
$ext = 'C:\Pode\Extensions'
if (Test-Path $ext)
{
    Get-ChildItem "$($ext)\*.ps1" | Resolve-Path | ForEach-Object { . $_ }
}

# get functions from memory and compare to existing to find new functions added
$podefuncs = Get-ChildItem Function: | Where-Object { $sysfuncs -notcontains $_ }

# export the module
Export-ModuleMember -Function ($podefuncs.Name)