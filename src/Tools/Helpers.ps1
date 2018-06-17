
# read in the content from a dynamic pode file and invoke its content
function ConvertFrom-PodeFile
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        $Content,

        [Parameter()]
        $Data = @{}
    )

    # if we have data, then setup the data param
    if (!(Test-Empty $Data)) {
        $Content = "param(`$data)`nreturn `"$($Content -replace '"', '``"')`""
    }
    else {
        $Content = "return `"$($Content -replace '"', '``"')`""
    }

    # invoke the content as a script to generate the dynamic content
    $Content = (Invoke-Command -ScriptBlock ([scriptblock]::Create($Content)) -ArgumentList $Data)
    return $Content
}

function Get-Type
{
    param (
        [Parameter()]
        $Value
    )

    if ($Value -eq $null) {
        return $null
    }

    return @{
        'Name' = $Value.GetType().Name.ToLowerInvariant();
        'BaseName' = $Value.GetType().BaseType.Name.ToLowerInvariant();
    }
}

function Test-Empty
{
    param (
        [Parameter()]
        $Value
    )

    $type = Get-Type $Value
    if ($type -eq $null) {
        return $true
    }

    if ($type.Name -ieq 'string') {
        return [string]::IsNullOrWhiteSpace($Value)
    }

    if ($type.Name -ieq 'hashtable') {
        return $Value.Count -eq 0
    }

    switch ($type.BaseName) {
        'valuetype' {
            return $false
        }

        'array' {
            return (($Value | Measure-Object).Count -eq 0 -or $Value.Count -eq 0)
        }
    }

    return ([string]::IsNullOrWhiteSpace($Value) -or ($Value | Measure-Object).Count -eq 0 -or $Value.Count -eq 0)
}

function Test-IsUnix
{
    return $PSVersionTable.Platform -ieq 'unix'
}

function Test-IsPSCore
{
    return $PSVersionTable.PSEdition -ieq 'core'
}

function Test-IPAddress
{
    param (
        [Parameter()]
        [string]
        $IP
    )

    if ((Test-Empty $IP) -or $IP -ieq '*') {
        return $true
    }

    try {
        [System.Net.IPAddress]::Parse($IP) | Out-Null
        return $true
    }
    catch [exception] {
        return $false
    }
}

function Test-IPAddressLocal
{
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $IP
    )

    return (@('0.0.0.0', '*', '127.0.0.1') -icontains $IP)
}

function Get-IPAddress
{
    param (
        [Parameter()]
        [string]
        $IP
    )

    if ((Test-Empty $IP) -or $IP -ieq '*') {
        return [System.Net.IPAddress]::Any
    }

    return [System.Net.IPAddress]::Parse($IP)
}

function Add-PodeRunspace
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        $Parameters
    )

    $ps = [powershell]::Create()
    $ps.RunspacePool = $PodeSession.RunspacePool
    $ps.AddScript($ScriptBlock) | Out-Null

    if (!(Test-Empty $Parameters)) {
        $Parameters.Keys | ForEach-Object {
            $ps.AddParameter($_, $Parameters[$_]) | Out-Null
        }
    }

    $PodeSession.Runspaces += @{
        'Runspace' = $ps;
        'Status' = $ps.BeginInvoke();
        'Stopped' = $false;
    }
}

function Close-PodeRunspaces
{
    $PodeSession.Runspaces | Where-Object { !$_.Stopped } | ForEach-Object {
        $_.Runspace.Dispose()
        $_.Stopped = $true
    }

    if (!$PodeSession.RunspacePool.IsDisposed) {
        $PodeSession.RunspacePool.Close()
        $PodeSession.RunspacePool.Dispose()
    }
}

function Start-TerminationListener
{
    Add-PodeRunspace {
        # default variables
        $options = "AllowCtrlC,IncludeKeyUp,NoEcho"
        $ctrlState = "LeftCtrlPressed"
        $char = 'c'
        $cancel = $false

        # are we on ps-core?
        $onCore = ($PSVersionTable.PSEdition -ieq 'core')

        while ($true) {
            if ($Console.UI.RawUI.KeyAvailable) {
                $key = $Console.UI.RawUI.ReadKey($options)

                if ([char]$key.VirtualKeyCode -ieq $char) {
                    if ($onCore) {
                        $cancel = ($key.Character -ine $char)
                    }
                    else {
                        $cancel = (($key.ControlKeyState -band $ctrlState) -ieq $ctrlState)
                    }
                }

                if ($cancel) {
                    Write-Host 'Terminating...' -NoNewline
                    $PodeSession.CancelToken.Cancel()
                    break
                }
            }

            Start-Sleep -Milliseconds 10
        }
    }
}

function Close-Pode
{
    param (
        [switch]
        $Exit
    )

    Close-PodeRunspaces

    try {
        $PodeSession.CancelToken.Dispose()
    } catch { }

    if ($Exit) {
        Write-Host " Done" -ForegroundColor Green
        exit 0
    }
}

<#
# Sourced and editted from https://davewyatt.wordpress.com/2014/04/06/thread-synchronization-in-powershell/
#>
function Lock
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [object]
        $InputObject,

        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [scriptblock]
        $ScriptBlock
    )

    if ($InputObject.GetType().IsValueType) {
        throw 'Cannot lock value types'
    }

    $locked = $false

    try {
        [System.Threading.Monitor]::Enter($InputObject.SyncRoot)
        $locked = $true
        . $ScriptBlock
    }
    finally {
        if ($locked) {
            [System.Threading.Monitor]::Exit($InputObject.SyncRoot)
        }
    }
}

function Join-ServerRoot
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet('Public', 'Views', 'Logs')]
        [string]
        $Type,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $FilePath,

        [Parameter()]
        [string]
        $Root
    )

    if (Test-Empty $Root) {
        $Root = $PodeSession.ServerRoot
    }

    return (Join-Path $Root (Join-Path $Type.ToLowerInvariant() $FilePath))
}