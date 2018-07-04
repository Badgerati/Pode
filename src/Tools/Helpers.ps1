
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
    return (Invoke-ScriptBlock -ScriptBlock ([scriptblock]::Create($Content)) -Arguments $Data)
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

    $type = $Value.GetType()
    return @{
        'Name' = $type.Name.ToLowerInvariant();
        'BaseName' = $type.BaseType.Name.ToLowerInvariant();
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

function Get-PSVersionTable
{
    return $PSVersionTable
}

function Test-IsUnix
{
    return (Get-PSVersionTable).Platform -ieq 'unix'
}

function Test-IsPSCore
{
    return (Get-PSVersionTable).PSEdition -ieq 'core'
}

function Test-IPAddress
{
    param (
        [Parameter()]
        [string]
        $IP
    )

    if ((Test-Empty $IP) -or $IP -ieq '*' -or $IP -ieq 'all') {
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

function ConvertTo-IPAddress
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        $Endpoint
    )

    return [System.Net.IPAddress]::Parse(([System.Net.IPEndPoint]$Endpoint).Address.ToString())
}

function Test-IPAddressLocal
{
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $IP
    )

    return (@('0.0.0.0', '*', '127.0.0.1', 'all') -icontains $IP)
}

function Test-IPAddressAny
{
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $IP
    )

    return (@('0.0.0.0', '*', 'all') -icontains $IP)
}

function Get-IPAddress
{
    param (
        [Parameter()]
        [string]
        $IP
    )

    if ((Test-Empty $IP) -or $IP -ieq '*' -or $IP -ieq 'all') {
        return [System.Net.IPAddress]::Any
    }

    return [System.Net.IPAddress]::Parse($IP)
}

function Test-IPAddressInRange
{
    param (
        [Parameter(Mandatory=$true)]
        $IP,

        [Parameter(Mandatory=$true)]
        $LowerIP,

        [Parameter(Mandatory=$true)]
        $UpperIP
    )

    if ($IP.Family -ine $LowerIP.Family) {
        return $false
    }

    $valid = $true

    0..3 | ForEach-Object {
        if ($valid -and (($IP.Bytes[$_] -lt $LowerIP.Bytes[$_]) -or ($IP.Bytes[$_] -gt $UpperIP.Bytes[$_]))) {
            $valid = $false
        }
    }

    return $valid
}

function Test-IPAddressIsSubnetMask
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $IP
    )

    return (($IP -split '/').Length -gt 1)
}

function Get-SubnetRange
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $SubnetMask
    )

    # split for ip and number of 1 bits
    $split = $SubnetMask -split '/'
    if ($split.Length -le 1) {
        return $null
    }

    $ip_parts = $split[0] -isplit '\.'
    $bits = [int]$split[1]

    # generate the netmask
    $network = @("", "", "", "")
    $count = 0

    foreach ($i in 0..3) {
        foreach ($b in 1..8) {
            $count++

            if ($count -le $bits) {
                $network[$i] += "1"
            }
            else {
                $network[$i] += "0"
            }
        }
    }

    # covert netmask to bytes
    0..3 | ForEach-Object {
        $network[$_] = [Convert]::ToByte($network[$_], 2)
    }

    # calculate the bottom range
    $bottom = @(0..3 | ForEach-Object { [byte]([byte]$network[$_] -band [byte]$ip_parts[$_]) })

    # calculate the range
    $range = @(0..3 | ForEach-Object { 256 + (-bnot [byte]$network[$_]) })

    # calculate the top range
    $top = @(0..3 | ForEach-Object { [byte]([byte]$ip_parts[$_] + [byte]$range[$_]) })

    return @{
        'Lower' = ($bottom -join '.');
        'Upper' = ($top -join '.');
        'Range' = ($range -join '.');
        'Netmask' = ($network -join '.');
        'IP' = ($ip_parts -join '.');
    }
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
    param (
        [switch]
        $ClosePool
    )

    try {
        if (!(Test-Empty $PodeSession.Runspaces)) {
            # sleep for 1s before doing this, to let listeners dispose
            Start-Sleep -Seconds 1

            # now dispose runspaces
            $PodeSession.Runspaces | Where-Object { !$_.Stopped } | ForEach-Object {
                $_.Runspace.Dispose()
                $_.Stopped = $true
            }

            $PodeSession.Runspaces = @()
        }

        if ($ClosePool -and $PodeSession.RunspacePool -ne $null -and !$PodeSession.RunspacePool.IsDisposed) {
            $PodeSession.RunspacePool.Close()
            $PodeSession.RunspacePool.Dispose()
        }
    }
    catch {
        $Error[0] | Out-Default
        throw $_.Exception
    }
}

function Test-TerminationPressed
{
    if ($PodeSession.DisableTermination -or [Console]::IsInputRedirected -or ![Console]::KeyAvailable) {
        return $false
    }

    $key = [Console]::ReadKey($true)

    if ($key.Key -ieq 'c' -and $key.Modifiers -band [ConsoleModifiers]::Control) {
        return $true
    }

    return $false
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
                    $PodeSession.Tokens.Cancellation.Cancel()
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

    Close-PodeRunspaces -ClosePool
    Stop-PodeFileMonitor

    try {
        $PodeSession.Tokens.Cancellation.Dispose()
        $PodeSession.Tokens.Restart.Dispose()
    } catch {
        $Error[0] | Out-Default
    }

    if ($Exit) {
        Write-Host " Done" -ForegroundColor Green
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

    if ($InputObject -eq $null) {
        return
    }

    if ($InputObject.GetType().IsValueType) {
        throw 'Cannot lock value types'
    }

    $locked = $false

    try {
        [System.Threading.Monitor]::Enter($InputObject.SyncRoot)
        $locked = $true

        if ($ScriptBlock -ne $null) {
            Invoke-ScriptBlock -ScriptBlock $ScriptBlock
        }
    }
    catch {
        $Error[0] | Out-Default
        throw $_.Exception
    }
    finally {
        if ($locked) {
            [System.Threading.Monitor]::Pulse($InputObject.SyncRoot)
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

function Invoke-ScriptBlock
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [scriptblock]
        $ScriptBlock,
        
        [Parameter()]
        [hashtable]
        $Arguments = $null,

        [switch]
        $Scoped
    )

    if ($Scoped) {
        & $ScriptBlock $Arguments
    }
    else {
        . $ScriptBlock $Arguments
    }
}