
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
    return (Invoke-ScriptBlock -ScriptBlock ([scriptblock]::Create($Content)) -Arguments $Data -Return)
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

    switch ($type.Name) {
        'string' {
            return [string]::IsNullOrWhiteSpace($Value)
        }

        'hashtable' {
            return ($Value.Count -eq 0)
        }

        'scriptblock' {
            return ($null -eq $Value -or [string]::IsNullOrWhiteSpace($Value.ToString()))
        }
    }

    switch ($type.BaseName) {
        'valuetype' {
            return $false
        }

        'array' {
            return ((Get-Count $Value) -eq 0 -or $Value.Count -eq 0)
        }
    }

    return ([string]::IsNullOrWhiteSpace($Value) -or (Get-Count $Value) -eq 0 -or $Value.Count -eq 0)
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

function Test-IsAdminUser
{
    # check the current platform, if it's unix then return true
    if (Test-IsUnix) {
        return $true
    }

    try {
        $principal = New-Object System.Security.Principal.WindowsPrincipal([System.Security.Principal.WindowsIdentity]::GetCurrent())
        if ($principal -eq $null) {
            return $false
        }

        return $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch [exception] {
        Write-Host 'Error checking user administrator priviledges' -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        return $false
    }
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
        throw "A certificate is required for ssl connections, either 'self' or '*.example.com' can be supplied to the 'listen' function"
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

function Get-HostIPRegex
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet('Both', 'Hostname', 'IP')]
        [string]
        $Type
    )

    $ip_rgx = '\[[a-f0-9\:]+\]|((\d+\.){3}\d+)|\:\:\d+|\*|all'
    $host_rgx = '([a-z]|\*\.)(([a-z0-9]|[a-z0-9][a-z0-9\-]*[a-z0-9])\.)*([a-z0-9]|[a-z0-9][a-z0-9\-]*[a-z0-9])+'

    switch ($Type.ToLowerInvariant())
    {
        'both' {
            return "(?<host>($($ip_rgx)|$($host_rgx)))"
        }

        'hostname' {
            return "(?<host>($($host_rgx)))"
        }

        'ip' {
            return "(?<host>($($ip_rgx)))"
        }
    }
}

function Get-PortRegex
{
    return '(?<port>\d+)'
}

function Get-PodeEndpointInfo
{
    param (
        [Parameter()]
        [string]
        $Endpoint,

        [switch]
        $AnyPortOnZero
    )

    if ([string]::IsNullOrWhiteSpace($Endpoint)) {
        return $null
    }

    $hostRgx = Get-HostIPRegex -Type Both
    $portRgx = Get-PortRegex
    $cmbdRgx = "$($hostRgx)\:$($portRgx)"

    # validate that we have a valid ip/host:port address
    if (!(($Endpoint -imatch "^$($cmbdRgx)$") -or ($Endpoint -imatch "^$($hostRgx)[\:]{0,1}") -or ($Endpoint -imatch "[\:]{0,1}$($portRgx)$"))) {
        throw "Failed to parse '$($Endpoint)' as a valid IP/Host:Port address"
    }

    # grab the ip address/hostname
    $_host = $Matches['host']
    if (Test-Empty $_host) {
        $_host = '*'
    }

    # ensure we have a valid ip address/hostname
    if (!(Test-IPAddress -IP $_host)) {
        throw "The IP address supplied is invalid: $($_host)"
    }

    # grab the port
    $_port = $Matches['port']
    if (Test-Empty $_port) {
        $_port = 0
    }

    # ensure the port is valid
    if ($_port -lt 0) {
        throw "The port cannot be negative: $($_port)"
    }

    # return the info
    return @{
        'Host' = $_host;
        'Port' = (iftet ($AnyPortOnZero -and $_port -eq 0) '*' $_port);
    }
}

function Test-IPAddress
{
    param (
        [Parameter()]
        [string]
        $IP
    )

    if ((Test-Empty $IP) -or ($IP -ieq '*') -or ($IP -ieq 'all') -or ($IP -imatch "^$(Get-HostIPRegex -Type Hostname)$")) {
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

function Test-Hostname
{
    param (
        [Parameter()]
        [string]
        $Hostname
    )

    return ($Hostname -imatch "^$(Get-HostIPRegex -Type Hostname)$")
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

function Get-IPAddressesForHostname
{
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Hostname,

        [Parameter(Mandatory=$true)]
        [ValidateSet('All', 'IPv4', 'IPv6')]
        [string]
        $Type
    )

    # get the ip addresses for the hostname
    $ips = @([System.Net.Dns]::GetHostAddresses($Hostname))

    # return ips based on type
    switch ($Type.ToLowerInvariant())
    {
        'ipv4' {
            $ips = @(($ips | Where-Object { $_.AddressFamily -ieq 'InterNetwork' }))
        }

        'ipv6' {
            $ips = @(($ips | Where-Object { $_.AddressFamily -ieq 'InterNetworkV6' }))
        }
    }

    return @(($ips | Select-Object -ExpandProperty IPAddressToString))
}

function Test-IPAddressLocal
{
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $IP
    )

    return (@('127.0.0.1', '::1', '[::1]', 'localhost') -icontains $IP)
}

function Test-IPAddressAny
{
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $IP
    )

    return (@('0.0.0.0', '*', 'all', '::', '[::]') -icontains $IP)
}

function Test-IPAddressLocalOrAny
{
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $IP
    )

    return ((Test-IPAddressLocal -IP $IP) -or (Test-IPAddressAny -IP $IP))
}

function Get-IPAddress
{
    param (
        [Parameter()]
        [string]
        $IP
    )

    if ((Test-Empty $IP) -or ($IP -ieq '*') -or ($IP -ieq 'all')) {
        return [System.Net.IPAddress]::Any
    }

    if (($IP -ieq '::') -or ($IP -ieq '[::]')) {
        return [System.Net.IPAddress]::IPv6Any
    }

    if ($IP -imatch "^$(Get-HostIPRegex -Type Hostname)$") {
        return $IP
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
        [ValidateSet('Main', 'Schedules', 'Gui')]
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
        $ps.AddScript({ Add-PodePSDrives }) | Out-Null
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
            $PodeSession.RunspacePools.Values | Where-Object { $null -ne $_ -and !$_.IsDisposed } | ForEach-Object {
                dispose $_ -Close
            }
        }
    }
    catch {
        $Error[0] | Out-Default
        throw $_.Exception
    }
}

function Get-ConsoleKey
{
    if ([Console]::IsInputRedirected -or ![Console]::KeyAvailable) {
        return $null
    }

    return [Console]::ReadKey($true)
}

function Test-TerminationPressed
{
    param (
        [Parameter()]
        $Key = $null
    )

    if ($PodeSession.DisableTermination) {
        return $false
    }

    if ($null -eq $Key) {
        $Key = Get-ConsoleKey
    }

    return ($null -ne $Key -and $Key.Key -ieq 'c' -and $Key.Modifiers -band [ConsoleModifiers]::Control)
}

function Test-RestartPressed
{
    param (
        [Parameter()]
        $Key = $null
    )

    if ($null -eq $Key) {
        $Key = Get-ConsoleKey
    }

    return ($null -ne $Key -and $Key.Key -ieq 'r' -and $Key.Modifiers -band [ConsoleModifiers]::Control)
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

    # stpo all current runspaces
    Close-PodeRunspaces -ClosePool

    # stop the file monitor if it's running
    Stop-PodeFileMonitor

    try {
        # remove all the cancellation tokens
        dispose $PodeSession.Tokens.Cancellation
        dispose $PodeSession.Tokens.Restart
    } catch {
        $Error[0] | Out-Default
    }

    # remove all of the pode temp drives
    Remove-PodePSDrives

    if ($Exit -and ![string]::IsNullOrWhiteSpace($PodeSession.Server.Type)) {
        Write-Host " Done" -ForegroundColor Green
    }
}

function New-PodePSDrive
{
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Path,

        [Parameter()]
        [string]
        $Name
    )

    if ([string]::IsNullOrWhiteSpace($Name)) {
        $Name = "PodeDir$(Get-NewGuid)"
    }

    $drive = (New-PSDrive -Name $Name -PSProvider FileSystem -Root $Path -Scope Global)

    if (!$PodeSession.Server.Drives.ContainsKey($drive.Name)) {
        $PodeSession.Server.Drives[$drive.Name] = $Path
    }

    return "$($drive.Name):"
}

function Add-PodePSDrives
{
    $PodeSession.Server.Drives.Keys | ForEach-Object {
        New-PodePSDrive -Path $PodeSession.Server.Drives[$_] -Name $_ | Out-Null
    }
}

function Add-PodePSInbuiltDrives
{
    $PodeSession.Server.InbuiltDrives['views'] = (New-PodePSDrive -Path (Join-ServerRoot 'views'))
    $PodeSession.Server.InbuiltDrives['public'] = (New-PodePSDrive -Path (Join-ServerRoot 'public'))
}

function Remove-PodePSDrives
{
    Get-PSDrive PodeDir* | Remove-PSDrive | Out-Null
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
            Invoke-ScriptBlock -ScriptBlock $ScriptBlock -NoNewClosure
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
        [ValidateNotNullOrEmpty()]
        [string]
        $Folder,

        [Parameter()]
        [string]
        $FilePath,

        [Parameter()]
        [string]
        $Root
    )

    # use the root path of the server
    if (Test-Empty $Root) {
        $Root = $PodeSession.Server.Root
    }

    # join the folder/file to the root path
    if ([string]::IsNullOrWhiteSpace($FilePath)) {
        return (Join-Path $Root $Folder)
    }
    else {
        return (Join-Path $Root (Join-Path $Folder $FilePath))
    }
}

function Invoke-ScriptBlock
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [Alias('s')]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [Alias('a')]
        $Arguments = $null,

        [switch]
        $Scoped,

        [switch]
        $Return,

        [switch]
        $Splat,

        [switch]
        $NoNewClosure
    )

    if (!$NoNewClosure) {
        $ScriptBlock = ($ScriptBlock).GetNewClosure()
    }

    if ($Scoped) {
        if ($Splat) {
            $result = (& $ScriptBlock @Arguments)
        }
        else {
            $result = (& $ScriptBlock $Arguments)
        }
    }
    else {
        if ($Splat) {
            $result = (. $ScriptBlock @Arguments)
        }
        else {
            $result = (. $ScriptBlock $Arguments)
        }
    }

    if ($Return) {
        return $result
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

function Coalesce
{
    param (
        [Parameter()]
        $Value1,

        [Parameter()]
        $Value2
    )

    return (iftet (Test-Empty $Value1) $Value2 $Value1)
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

function ConvertFrom-RequestContent
{
    param (
        [Parameter()]
        $Request
    )

    # get the requests content type and boundary
    $MetaData = Get-ContentTypeAndBoundary -ContentType $Request.ContentType
    $Encoding = $Request.ContentEncoding

    # result object for data/files
    $Result = @{
        'Data' = @{};
        'Files' = @{};
    }

    # if there is no content-type then do nothing
    if (Test-Empty $MetaData.ContentType) {
        return $Result
    }

    # if the content-type is not multipart/form-data, get the string data
    if ($MetaData.ContentType -ine 'multipart/form-data') {
        $Content = Read-StreamToEnd -Stream $Request.InputStream -Encoding $Encoding

        # if there is no content then do nothing
        if (Test-Empty $Content) {
            return $Result
        }
    }

    # run action for the content type
    switch ($MetaData.ContentType) {
        { $_ -ilike '*/json' } {
            $Result.Data = ($Content | ConvertFrom-Json)
        }

        { $_ -ilike '*/xml' } {
            $Result.Data = [xml]($Content)
        }

        { $_ -ilike '*/csv' } {
            $Result.Data = ($Content | ConvertFrom-Csv)
        }

        { $_ -ilike '*/x-www-form-urlencoded' } {
            $Result.Data = (ConvertFrom-NameValueToHashTable -Collection ([System.Web.HttpUtility]::ParseQueryString($Content)))
        }

        { $_ -ieq 'multipart/form-data' } {
            # convert the stream to bytes
            $Content = ConvertFrom-StreamToBytes -Stream $Request.InputStream
            $Lines = Get-ByteLinesFromByteArray -Bytes $Content -Encoding $Encoding -IncludeNewLine

            # get the indexes for boundary lines (start and end)
            $boundaryIndexes = @()
            for ($i = 0; $i -lt $Lines.Length; $i++) {
                if ((Test-ByteArrayIsBoundary -Bytes $Lines[$i] -Boundary $MetaData.Boundary.Start -Encoding $Encoding) -or
                    (Test-ByteArrayIsBoundary -Bytes $Lines[$i] -Boundary $MetaData.Boundary.End -Encoding $Encoding)) {
                    $boundaryIndexes += $i
                }
            }

            # loop through the boundary indexes (exclude last, as it's the end boundary)
            for ($i = 0; $i -lt ($boundaryIndexes.Length - 1); $i++)
            {
                $bIndex = $boundaryIndexes[$i]

                # the next line contains the key-value field names (content-disposition)
                $fields = @{}
                $disp = ConvertFrom-BytesToString -Bytes $Lines[$bIndex+1] -Encoding $Encoding -RemoveNewLine

                @($disp -isplit ';') | ForEach-Object {
                    $atoms = @($_ -isplit '=')
                    if ($atoms.Length -eq 2) {
                        $fields.Add($atoms[0].Trim(), $atoms[1].Trim(' "'))
                    }
                }

                # use the next line to work out field values
                if (!$fields.ContainsKey('filename')) {
                    $value = ConvertFrom-BytesToString -Bytes $Lines[$bIndex+3] -Encoding $Encoding -RemoveNewLine
                    $Result.Data.Add($fields.name, $value)
                }

                # if we have a file, work out file and content type
                if ($fields.ContainsKey('filename')) {
                    $Result.Data.Add($fields.name, $fields.filename)

                    if (!(Test-Empty $fields.filename)) {
                        $type = ConvertFrom-BytesToString -Bytes $Lines[$bIndex+2] -Encoding $Encoding -RemoveNewLine

                        $Result.Files.Add($fields.filename, @{
                            'ContentType' = (@($type -isplit ':')[1].Trim());
                            'Bytes' = $null;
                        })

                        $bytes = @()
                        $Lines[($bIndex+4)..($boundaryIndexes[$i+1]-1)] | ForEach-Object {
                            $bytes += $_
                        }

                        $Result.Files[$fields.filename].Bytes = (Remove-NewLineBytesFromArray $bytes $Encoding)
                    }
                }
            }
        }

        default {
            $Result.Data = $Content
        }
    }

    return $Result
}

function Test-ByteArrayIsBoundary
{
    param (
        [Parameter()]
        [byte[]]
        $Bytes,

        [Parameter()]
        [string]
        $Boundary,

        [Parameter()]
        $Encoding = [System.Text.Encoding]::UTF8
    )

    # if no bytes, return
    if ($Bytes.Length -eq 0) {
        return $false
    }

    # if length difference >3, return (ie, 2 offset for `r`n)
    if (($Bytes.Length - $Boundary.Length) -gt 3) {
        return $false
    }

    # check if bytes starts with the boundary
    return (ConvertFrom-BytesToString $Bytes $Encoding).StartsWith($Boundary)
}

function Get-ContentTypeAndBoundary
{
    param (
        [Parameter()]
        [string]
        $ContentType
    )

    $obj = @{
        'ContentType' = [string]::Empty;
        'Boundary' = @{
            'Start' = [string]::Empty;
            'End' = [string]::Empty;
        }
    }

    if (Test-Empty $ContentType) {
        return $obj
    }

    $split = @($ContentType -isplit ';')
    $obj.ContentType = $split[0].Trim()

    if ($split.Length -gt 1) {
        $obj.Boundary.Start = "--$(($split[1] -isplit '=')[1].Trim())"
        $obj.Boundary.End = "$($obj.Boundary.Start)--"
    }

    return $obj
}

function ConvertFrom-NameValueToHashTable
{
    param (
        [Parameter()]
        $Collection
    )

    if ($null -eq $Collection) {
        return $null
    }

    $ht = @{}
    $Collection.Keys | ForEach-Object {
        $ht[$_] = $Collection[$_]
    }

    return $ht
}

function Get-NewGuid
{
    return ([guid]::NewGuid()).ToString()
}

function Get-Count
{
    param (
        [Parameter()]
        $Object
    )

    return ($Object | Measure-Object).Count
}

function Get-ContentAsBytes
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Path
    )

    if (Test-IsPSCore) {
        return (Get-Content -Path $Path -Raw -AsByteStream)
    }

    return (Get-Content -Path $Path -Raw -Encoding byte)
}

function Test-PathAccess
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Path
    )

    try {
        Get-Item $Path | Out-Null
    }
    catch [System.UnauthorizedAccessException] {
        return $false
    }

    return $true
}

function Test-PodePath
{
    param (
        [Parameter()]
        $Path,

        [switch]
        $NoStatus,

        [switch]
        $FailOnDirectory
    )

    # if the file doesnt exist then fail on 404
    if ((Test-Empty $Path) -or !(Test-Path $Path)) {
        if (!$NoStatus) {
            status 404
        }

        return $false
    }

    # if the file isn't accessible then fail 401
    if (!(Test-PathAccess $Path)) {
        if (!$NoStatus) {
            status 401
        }

        return $false
    }

    # if we're failing on a directory then fail on 404
    if ($FailOnDirectory -and (Test-PathIsDirectory $Path)) {
        if (!$NoStatus) {
            status 404
        }

        return $false
    }

    return $true
}

function Test-PathIsFile
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Path
    )

    return (![string]::IsNullOrWhiteSpace([System.IO.Path]::GetExtension($Path)))
}

function Test-PathIsDirectory
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Path
    )

    return ([string]::IsNullOrWhiteSpace([System.IO.Path]::GetExtension($Path)))
}