
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

    if ($null -eq $Value) {
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
    if ($null -eq $type) {
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

function Test-IsWindows
{
    $v = Get-PSVersionTable
    return ($v.Platform -ilike '*win*' -or ($null -eq $v.Platform -and $v.PSEdition -ieq 'desktop'))
}

function Test-IsPSCore
{
    return (Get-PSVersionTable).PSEdition -ieq 'core'
}

function New-PodeSelfSignedCertificate
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $IP,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Port,

        [Parameter()]
        [string]
        $Certificate
    )

    # only bind if windows at the moment
    if (!(Test-IsWindows)) {
        Write-Host "Certificates are currently only supported on Windows" -ForegroundColor Yellow
        return
    }

    # check if this ip/port is already bound
    $sslPortInUse = (netsh http show sslcert) | Where-Object { $_ -ilike "*IP:port*" -and $_ -ilike "*$($IP):$($Port)" }
    if ($sslPortInUse)
    {
        Write-Host "$($IP):$($Port) already has a certificate bound" -ForegroundColor Green
        return
    }

    # ensure a cert has been supplied
    if (Test-Empty $Certificate) {
        throw "A certificate is required for ssl connections, either 'self' or '*.example.com' can be supplied to the 'listen' command"
    }

    # generate a self-signed cert
    if (@('self', 'self-signed') -icontains $Certificate)
    {
        Write-Host "Generating self-signed certificate for $($IP):$($Port)..." -NoNewline -ForegroundColor Cyan

        # generate the cert -- has to call "powershell.exe" for ps-core on windows
        $cert = (PowerShell.exe -NoProfile -Command {
            $expire = (Get-Date).AddYears(1)

            $c = New-SelfSignedCertificate -DnsName 'localhost' -CertStoreLocation 'Cert:\LocalMachine\My' -NotAfter $expire `
                    -KeyAlgorithm RSA -HashAlgorithm SHA256 -KeyLength 4096 -Subject 'CN=localhost';

            if ($null -eq $c.Thumbprint) {
                return $c
            }

            return $c.Thumbprint
        })

        if ($LASTEXITCODE -ne 0 -or !$?) {
            throw "Failed to generate self-signed certificte:`n$($cert)"
        }
    }

    # ensure a given cert exists for binding
    else
    {
        Write-Host "Binding $($Certificate) to $($IP):$($Port)..." -NoNewline -ForegroundColor Cyan

        # ensure the certificate exists, and get it's thumbprint
        $cert = (Get-ChildItem 'Cert:\LocalMachine\My' | Where-Object { $_.Subject -imatch [regex]::Escape($Certificate) })
        if (Test-Empty $cert) {
            throw "Failed to find the $($Certificate) certificate at LocalMachine\My"
        }

        $cert = ($cert)[0].Thumbprint
    }

    # bind the cert to the ip:port
    $ipport = "$($IP):$($Port)"

    $result = netsh http add sslcert ipport=$ipport certhash=$cert appid=`{e3ea217c-fc3d-406b-95d5-4304ab06c6af`}
    if ($LASTEXITCODE -ne 0 -or !$?) {
        throw "Failed to attach certificate:`n$($result)"
    }

    Write-Host " Done" -ForegroundColor Green
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
        [ValidateSet('Main', 'Schedules')]
        [string]
        $Type,

        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        $Parameters,

        [switch]
        $Forget
    )

    try
    {
        $ps = [powershell]::Create()
        $ps.RunspacePool = $PodeSession.RunspacePools[$Type]
        $ps.AddScript($ScriptBlock) | Out-Null

        if (!(Test-Empty $Parameters)) {
            $Parameters.Keys | ForEach-Object {
                $ps.AddParameter($_, $Parameters[$_]) | Out-Null
            }
        }

        if ($Forget) {
            $ps.BeginInvoke() | Out-Null
        }
        else {
            $PodeSession.Runspaces += @{
                'Pool' = $Type;
                'Runspace' = $ps;
                'Status' = $ps.BeginInvoke();
                'Stopped' = $false;
            }
        }
    }
    catch {
        $Error[0] | Out-Default
        throw $_.Exception
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
                dispose $_.Runspace
                $_.Stopped = $true
            }

            $PodeSession.Runspaces = @()
        }

        # dispose the runspace pools
        if ($ClosePool -and $null -ne $PodeSession.RunspacePools) {
            $PodeSession.RunspacePools.Values | Where-Object { !$_.IsDisposed } | ForEach-Object {
                dispose $_ -Close
            }
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
    Add-PodeRunspace -Type 'Main' {
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
        dispose $PodeSession.Tokens.Cancellation
        dispose $PodeSession.Tokens.Restart
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

    if ($null -eq $InputObject) {
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
        [object]
        $Arguments = $null,

        [switch]
        $Scoped,

        [switch]
        $Return
    )

    if ($Scoped) {
        if ($Return) {
            return (& $ScriptBlock $Arguments)
        }
        else {
            & $ScriptBlock $Arguments
        }
    }
    else {
        if ($Return) {
            return (. $ScriptBlock $Arguments)
        }
        else {
            . $ScriptBlock $Arguments
        }
    }
}

<#
    If-This-Else-That. If Check is true return Value1, else return Value2
#>
function Iftet
{
    param (
        [Parameter()]
        [bool]
        $Check,

        [Parameter()]
        $Value1,

        [Parameter()]
        $Value2
    )

    if ($Check) {
        return $Value1
    }

    return $Value2
}

function Get-FileExtension
{
    param (
        [Parameter()]
        [string]
        $Path,

        [switch]
        $TrimPeriod
    )

    $ext = [System.IO.Path]::GetExtension($Path)

    if ($TrimPeriod) {
        $ext = $ext.Trim('.')
    }

    return $ext
}

function Get-FileName
{
    param (
        [Parameter()]
        [string]
        $Path,

        [switch]
        $WithoutExtension
    )

    if ($WithoutExtension) {
        return [System.IO.Path]::GetFileNameWithoutExtension($Path)
    }

    return [System.IO.Path]::GetFileName($Path)
}

<#
    This is basically like "using" in .Net
#>
function Stream
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [System.IDisposable]
        $InputObject,

        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [scriptblock]
        $ScriptBlock
    )

    try {
        return (Invoke-ScriptBlock -ScriptBlock $ScriptBlock -Arguments $InputObject)
    }
    catch {
        $Error[0] | Out-Default
        throw $_.Exception
    }
    finally {
        $InputObject.Dispose()
    }
}

function Dispose
{
    param (
        [Parameter()]
        [System.IDisposable]
        $InputObject,

        [switch]
        $Close,

        [switch]
        $CheckNetwork
    )

    if ($InputObject -eq $null) {
        return
    }

    try {
        if ($Close) {
            $InputObject.Close()
        }
    }
    catch [exception] {
        if ($CheckNetwork -and (Test-ValidNetworkFailure $_.Exception)) {
            return
        }

        $Error[0] | Out-Default
        throw $_.Exception
    }
    finally {
        $InputObject.Dispose()
    }
}

function Stopwatch
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name,

        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [scriptblock]
        $ScriptBlock
    )

    try {
        $watch = [System.Diagnostics.Stopwatch]::StartNew()
        . $ScriptBlock
    }
    catch {
        $Error[0] | Out-Default
        throw $_.Exception
    }
    finally {
        $watch.Stop()
        Out-Default -InputObject "[Stopwatch]: $($watch.Elapsed) [$($Name)]"
    }
}

function Test-ValidNetworkFailure
{
    param (
        [Parameter()]
        $Exception
    )

    $msgs = @(
        '*network name is no longer available*',
        '*nonexistent network connection*',
        '*broken pipe*'
    )

    return (($msgs | Where-Object { $Exception.Message -ilike $_ } | Measure-Object).Count -gt 0)
}

function ConvertFrom-PodeContent
{
    param (
        [Parameter()]
        [string]
        $ContentType,

        [Parameter()]
        $Content
    )

    if (Test-Empty $Content) {
        return $Content
    }

    switch ($ContentType) {
        { $_ -ilike '*/json' } {
            $Content = ($Content | ConvertFrom-Json)
        }

        { $_ -ilike '*/xml' } {
            $Content = [xml]($Content)
        }

        { $_ -ilike '*/csv' } {
            $Content = ($Content | ConvertFrom-Csv)
        }
    }

    return $Content
}