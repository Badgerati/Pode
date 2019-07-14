
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
    if ($null -ne $Data -and $Data.Count -gt 0) {
        $Content = "param(`$data)`nreturn `"$($Content -replace '"', '``"')`""
    }
    else {
        $Content = "return `"$($Content -replace '"', '``"')`""
    }

    # invoke the content as a script to generate the dynamic content
    return (Invoke-PodeScriptBlock -ScriptBlock ([scriptblock]::Create($Content)) -Arguments $Data -Return)
}

function Get-PodeFileContentUsingViewEngine
{
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Path,

        [Parameter()]
        [hashtable]
        $Data
    )

    # work out the engine to use when parsing the file
    $engine = $PodeContext.Server.ViewEngine.Type

    $ext = Get-PodeFileExtension -Path $Path -TrimPeriod
    if (![string]::IsNullOrWhiteSpace($ext) -and ($ext -ine $PodeContext.Server.ViewEngine.Extension)) {
        $engine = $ext
    }

    # setup the content
    $content = [string]::Empty

    # run the relevant engine logic
    switch ($engine.ToLowerInvariant())
    {
        'html' {
            $content = Get-Content -Path $Path -Raw -Encoding utf8
        }

        'pode' {
            $content = Get-Content -Path $Path -Raw -Encoding utf8
            $content = ConvertFrom-PodeFile -Content $content -Data $Data
        }

        default {
            if ($null -ne $PodeContext.Server.ViewEngine.Script) {
                if ($null -eq $Data -or $Data.Count -eq 0) {
                    $content = (Invoke-PodeScriptBlock -ScriptBlock $PodeContext.Server.ViewEngine.Script -Arguments $Path -Return)
                }
                else {
                    $content = (Invoke-PodeScriptBlock -ScriptBlock $PodeContext.Server.ViewEngine.Script -Arguments @($Path, $Data) -Return -Splat)
                }
            }
        }
    }

    return $content
}

function Get-PodeFileContent
{
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Path
    )

    return (Get-Content -Path $Path -Raw -Encoding utf8)
}

function Get-PodeType
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

function Get-PodePSVersionTable
{
    return $PSVersionTable
}

function Test-IsAdminUser
{
    # check the current platform, if it's unix then return true
    if (Test-IsUnix) {
        return $true
    }

    try {
        $principal = New-Object System.Security.Principal.WindowsPrincipal([System.Security.Principal.WindowsIdentity]::GetCurrent())
        if ($null -eq $principal) {
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

    return $cert
}

function Get-PodeCertificate
{
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Certificate
    )

    # ensure the certificate exists, and get its thumbprint
    $cert = (Get-ChildItem 'Cert:\LocalMachine\My' | Where-Object { $_.Subject -imatch [regex]::Escape($Certificate) })
    if (Test-IsEmpty $cert) {
        throw "Failed to find the $($Certificate) certificate at LocalMachine\My"
    }

    $cert = @($cert)[0].Thumbprint
    return $cert
}

function Set-PodeCertificate
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Address,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Port,

        [Parameter()]
        [string]
        $Certificate,

        [Parameter()]
        [string]
        $Thumbprint,

        [switch]
        $SelfSigned
    )

    $addrport = "$($Address):$($Port)"

    # only bind if windows at the moment
    if (!(Test-IsWindows)) {
        Write-Host "Certificates are currently only supported on Windows" -ForegroundColor Yellow
        return
    }

    # check if this addr/port is already bound
    $sslPortInUse = (netsh http show sslcert) | Where-Object {
        ($_ -ilike "*IP:port*" -or $_ -ilike "*Hostname:port*") -and $_ -ilike "*$($addrport)"
    }

    if ($sslPortInUse) {
        Write-Host "$($addrport) already has a certificate bound" -ForegroundColor Green
        return
    }

    # ensure a cert, or thumbprint, has been supplied
    if (!$SelfSigned -and (Test-IsEmpty $Certificate) -and (Test-IsEmpty $Thumbprint)) {
        throw "A certificate name, or thumbprint, is required for ssl connections. For the name, either 'self' or '*.example.com' can be supplied to the 'listen' function"
    }

    # use the cert specified from the thumbprint
    if (!(Test-IsEmpty $Thumbprint)) {
        $cert = $Thumbprint
    }

    # otherwise, generate/find a certificate
    else
    {
        # generate a self-signed cert
        if ($SelfSigned) {
            Write-Host "Generating self-signed certificate for $($addrport)..." -NoNewline -ForegroundColor Cyan
            $cert = (New-PodeSelfSignedCertificate)
        }

        # ensure a given cert exists for binding
        else {
            Write-Host "Binding $($Certificate) to $($addrport)..." -NoNewline -ForegroundColor Cyan
            $cert = (Get-PodeCertificate -Certificate $Certificate)
        }
    }

    # bind the cert to the ip:port or hostname:port
    if (Test-PodeIPAddress -IP $Address -IPOnly) {
        $result = netsh http add sslcert ipport=$addrport certhash=$cert appid=`{e3ea217c-fc3d-406b-95d5-4304ab06c6af`}
        if ($LASTEXITCODE -ne 0 -or !$?) {
            throw "Failed to attach certificate against ipport:`n$($result)"
        }
    }
    else {
        $result = netsh http add sslcert hostnameport=$addrport certhash=$cert certstorename=MY appid=`{e3ea217c-fc3d-406b-95d5-4304ab06c6af`}
        if ($LASTEXITCODE -ne 0 -or !$?) {
            throw "Failed to attach certificate against hostnameport:`n$($result)"
        }
    }

    Write-Host " Done" -ForegroundColor Green
}

function Get-PodeHostIPRegex
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

    $hostRgx = Get-PodeHostIPRegex -Type Both
    $portRgx = Get-PortRegex
    $cmbdRgx = "$($hostRgx)\:$($portRgx)"

    # validate that we have a valid ip/host:port address
    if (!(($Endpoint -imatch "^$($cmbdRgx)$") -or ($Endpoint -imatch "^$($hostRgx)[\:]{0,1}") -or ($Endpoint -imatch "[\:]{0,1}$($portRgx)$"))) {
        throw "Failed to parse '$($Endpoint)' as a valid IP/Host:Port address"
    }

    # grab the ip address/hostname
    $_host = $Matches['host']
    if ([string]::IsNullOrWhiteSpace($_host)) {
        $_host = '*'
    }

    # ensure we have a valid ip address/hostname
    if (!(Test-PodeIPAddress -IP $_host)) {
        throw "The IP address supplied is invalid: $($_host)"
    }

    # grab the port
    $_port = $Matches['port']
    if ([string]::IsNullOrWhiteSpace($_port)) {
        $_port = 0
    }

    # ensure the port is valid
    if ($_port -lt 0) {
        throw "The port cannot be negative: $($_port)"
    }

    # return the info
    return @{
        'Host' = $_host;
        'Port' = (Resolve-PodeValue -Check ($AnyPortOnZero -and $_port -eq 0) -TrueValue '*' -FalseValue $_port);
    }
}

function Test-PodeIPAddress
{
    param (
        [Parameter()]
        [string]
        $IP,

        [switch]
        $IPOnly
    )

    if ([string]::IsNullOrWhiteSpace($IP) -or ($IP -ieq '*') -or ($IP -ieq 'all')) {
        return $true
    }

    if ($IP -imatch "^$(Get-PodeHostIPRegex -Type Hostname)$") {
        return (!$IPOnly)
    }

    try {
        [System.Net.IPAddress]::Parse($IP) | Out-Null
        return $true
    }
    catch [exception] {
        return $false
    }
}

function Test-PodeHostname
{
    param (
        [Parameter()]
        [string]
        $Hostname
    )

    return ($Hostname -imatch "^$(Get-PodeHostIPRegex -Type Hostname)$")
}

function ConvertTo-PodeIPAddress
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        $Endpoint
    )

    return [System.Net.IPAddress]::Parse(([System.Net.IPEndPoint]$Endpoint).Address.ToString())
}

function Get-PodeIPAddressesForHostname
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
            $ips = @(foreach ($ip in $ips) {
                if ($ip.AddressFamily -ieq 'InterNetwork') {
                    $ip
                }
            })
        }

        'ipv6' {
            $ips = @(foreach ($ip in $ips) {
                if ($ip.AddressFamily -ieq 'InterNetworkV6') {
                    $ip
                }
            })
        }
    }

    return (@($ips)).IPAddressToString
}

function Test-PodeIPAddressLocal
{
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $IP
    )

    return (@('127.0.0.1', '::1', '[::1]', 'localhost') -icontains $IP)
}

function Test-PodeIPAddressAny
{
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $IP
    )

    return (@('0.0.0.0', '*', 'all', '::', '[::]') -icontains $IP)
}

function Test-PodeIPAddressLocalOrAny
{
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $IP
    )

    return ((Test-PodeIPAddressLocal -IP $IP) -or (Test-PodeIPAddressAny -IP $IP))
}

function Get-PodeIPAddress
{
    param (
        [Parameter()]
        [string]
        $IP
    )

    if ([string]::IsNullOrWhiteSpace($IP) -or ($IP -ieq '*') -or ($IP -ieq 'all')) {
        return [System.Net.IPAddress]::Any
    }

    if (($IP -ieq '::') -or ($IP -ieq '[::]')) {
        return [System.Net.IPAddress]::IPv6Any
    }

    if ($IP -imatch "^$(Get-PodeHostIPRegex -Type Hostname)$") {
        return $IP
    }

    return [System.Net.IPAddress]::Parse($IP)
}

function Test-PodeIPAddressInRange
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

    foreach ($i in 0..3) {
        if (($IP.Bytes[$i] -lt $LowerIP.Bytes[$i]) -or ($IP.Bytes[$i] -gt $UpperIP.Bytes[$i])) {
            $valid = $false
            break
        }
    }

    return $valid
}

function Test-PodeIPAddressIsSubnetMask
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $IP
    )

    return (($IP -split '/').Length -gt 1)
}

function Get-PodeSubnetRange
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
    foreach ($i in 0..3) {
        $network[$i] = [Convert]::ToByte($network[$i], 2)
    }

    # calculate the bottom range
    $bottom = @(foreach ($i in 0..3) {
        [byte]([byte]$network[$i] -band [byte]$ip_parts[$i])
    })

    # calculate the range
    $range = @(foreach ($i in 0..3) {
        256 + (-bnot [byte]$network[$i])
    })

    # calculate the top range
    $top = @(foreach ($i in 0..3) {
        [byte]([byte]$ip_parts[$i] + [byte]$range[$i])
    })

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
        $ps.RunspacePool = $PodeContext.RunspacePools[$Type]
        $ps.AddScript({ Add-PodePSDrives }) | Out-Null
        $ps.AddScript($ScriptBlock) | Out-Null

        if (!(Test-IsEmpty $Parameters)) {
            $Parameters.Keys | ForEach-Object {
                $ps.AddParameter($_, $Parameters[$_]) | Out-Null
            }
        }

        if ($Forget) {
            $ps.BeginInvoke() | Out-Null
        }
        else {
            $PodeContext.Runspaces += @{
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

    if ($PodeContext.Server.IsServerless) {
        return
    }

    try {
        if (!(Test-IsEmpty $PodeContext.Runspaces)) {
            # sleep for 1s before doing this, to let listeners dispose
            Start-Sleep -Seconds 1

            # now dispose runspaces
            $PodeContext.Runspaces | Where-Object { !$_.Stopped } | ForEach-Object {
                Close-PodeDisposable -Disposable $_.Runspace
                $_.Stopped = $true
            }

            $PodeContext.Runspaces = @()
        }

        # dispose the runspace pools
        if ($ClosePool -and $null -ne $PodeContext.RunspacePools) {
            $PodeContext.RunspacePools.Values | Where-Object { $null -ne $_ -and !$_.IsDisposed } | ForEach-Object {
                Close-PodeDisposable -Disposable $_ -Close
            }
        }
    }
    catch {
        $Error[0] | Out-Default
        throw $_.Exception
    }
}

function Get-PodeConsoleKey
{
    if ([Console]::IsInputRedirected -or ![Console]::KeyAvailable) {
        return $null
    }

    return [Console]::ReadKey($true)
}

function Test-PodeTerminationPressed
{
    param (
        [Parameter()]
        $Key = $null
    )

    if ($PodeContext.DisableTermination) {
        return $false
    }

    if ($null -eq $Key) {
        $Key = Get-PodeConsoleKey
    }

    return ($null -ne $Key -and $Key.Key -ieq 'c' -and $Key.Modifiers -band [ConsoleModifiers]::Control)
}

function Test-PodeRestartPressed
{
    param (
        [Parameter()]
        $Key = $null
    )

    if ($null -eq $Key) {
        $Key = Get-PodeConsoleKey
    }

    return ($null -ne $Key -and $Key.Key -ieq 'r' -and $Key.Modifiers -band [ConsoleModifiers]::Control)
}

function Start-PodeTerminationListener
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
                    $PodeContext.Tokens.Cancellation.Cancel()
                    break
                }
            }

            Start-Sleep -Milliseconds 10
        }
    }
}

function Close-PodeServer
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
        Close-PodeDisposable -Disposable $PodeContext.Tokens.Cancellation
        Close-PodeDisposable -Disposable $PodeContext.Tokens.Restart
    }
    catch {
        $Error[0] | Out-Default
    }

    # remove all of the pode temp drives
    Remove-PodePSDrives

    if ($Exit -and ![string]::IsNullOrWhiteSpace($PodeContext.Server.Type) -and !$PodeContext.Server.IsServerless) {
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

    # if no name is passed, used a randomly generated one
    if ([string]::IsNullOrWhiteSpace($Name)) {
        $Name = "PodeDir$(New-PodeGuid)"
    }

    # if the path supplied doesn't exist, error
    if (!(Test-Path $Path)) {
        throw "Path does not exist: $($Path)"
    }

    # create the temp drive
    $drive = (New-PSDrive -Name $Name -PSProvider FileSystem -Root $Path -Scope Global -ErrorAction Stop)

    # store internally, and return the drive's name
    if (!$PodeContext.Server.Drives.ContainsKey($drive.Name)) {
        $PodeContext.Server.Drives[$drive.Name] = $Path
    }

    return "$($drive.Name):"
}

function Add-PodePSDrives
{
    $PodeContext.Server.Drives.Keys | ForEach-Object {
        New-PodePSDrive -Path $PodeContext.Server.Drives[$_] -Name $_ | Out-Null
    }
}

function Add-PodePSInbuiltDrives
{
    # create drive for views, if path exists
    $path = (Join-PodeServerRoot 'views')
    if (Test-Path $path) {
        $PodeContext.Server.InbuiltDrives['views'] = (New-PodePSDrive -Path $path)
    }

    # create drive for public content, if path exists
    $path = (Join-PodeServerRoot 'public')
    if (Test-Path $path) {
        $PodeContext.Server.InbuiltDrives['public'] = (New-PodePSDrive -Path $path)
    }

    # create drive for errors, if path exists
    $path = (Join-PodeServerRoot 'errors')
    if (Test-Path $path) {
        $PodeContext.Server.InbuiltDrives['errors'] = (New-PodePSDrive -Path $path)
    }
}

function Remove-PodePSDrives
{
    Get-PSDrive PodeDir* | Remove-PSDrive | Out-Null
}

function Join-PodeServerRoot
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
    if ([string]::IsNullOrWhiteSpace($Root)) {
        $Root = $PodeContext.Server.Root
    }

    # join the folder/file to the root path
    return (Join-PodePaths @($Root, $Folder, $FilePath))
}

function Remove-PodeEmptyItemsFromArray
{
    param (
        [Parameter()]
        $Array
    )

    if ($null -eq $Array) {
        return @()
    }

    return @(@($Array -ne ([string]::Empty)) -ne $null)
}

function Join-PodePaths
{
    param (
        [Parameter()]
        [string[]]
        $Paths
    )

    # remove any empty/null paths
    $Paths = @(Remove-PodeEmptyItemsFromArray $Paths)

    # if there are no paths, return blank
    if ($null -eq $Paths -or $Paths.Length -eq 0) {
        return ([string]::Empty)
    }

    # return the first path if singular
    if ($Paths.Length -eq 1) {
        return $Paths[0]
    }

    # join the first two paths
    $_path = Join-Path $Paths[0] $Paths[1]

    # if there are any more, add them on
    if ($Paths.Length -gt 2) {
        foreach ($p in $Paths[2..($Paths.Length - 1)]) {
            $_path = Join-Path $_path $p
        }
    }

    return $_path
}

function Get-PodeFileExtension
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

function Get-PodeFileName
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

function Test-PodeValidNetworkFailure
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

    $match = @(foreach ($msg in $msgs) {
        if ($Exception.Message -ilike $msg) {
            $msg
        }
    })[0]

    return ($null -ne $match)
}

function ConvertFrom-PodeRequestContent
{
    param (
        [Parameter()]
        $Request,

        [Parameter()]
        [string]
        $ContentType
    )

    # get the requests content type and boundary
    $MetaData = Get-PodeContentTypeAndBoundary -ContentType $ContentType
    $Encoding = $Request.ContentEncoding

    # result object for data/files
    $Result = @{
        'Data' = @{};
        'Files' = @{};
    }

    # if there is no content-type then do nothing
    if ([string]::IsNullOrWhiteSpace($MetaData.ContentType)) {
        return $Result
    }

    # if the content-type is not multipart/form-data, get the string data
    if ($MetaData.ContentType -ine 'multipart/form-data') {
        # get the content based on server type
        switch ($PodeContext.Server.Type.ToLowerInvariant()) {
            'awslambda' {
                $Content = $Request.body
            }

            'azurefunctions' {
                $Content = $Request.RawBody
            }

            default {
                $Content = Read-PodeStreamToEnd -Stream $Request.InputStream -Encoding $Encoding
            }
        }

        # if there is no content then do nothing
        if ([string]::IsNullOrWhiteSpace($Content)) {
            return $Result
        }
    }

    # run action for the content type
    switch ($MetaData.ContentType) {
        { $_ -ilike '*/json' } {
            if (Test-IsPSCore) {
                $Result.Data = ($Content | ConvertFrom-Json -AsHashtable)
            }
            else {
                $Result.Data = ($Content | ConvertFrom-Json)
            }
        }

        { $_ -ilike '*/xml' } {
            $Result.Data = [xml]($Content)
        }

        { $_ -ilike '*/csv' } {
            $Result.Data = ($Content | ConvertFrom-Csv)
        }

        { $_ -ilike '*/x-www-form-urlencoded' } {
            $Result.Data = (ConvertFrom-PodeNameValueToHashTable -Collection ([System.Web.HttpUtility]::ParseQueryString($Content)))
        }

        { $_ -ieq 'multipart/form-data' } {
            # convert the stream to bytes
            $Content = ConvertFrom-PodeStreamToBytes -Stream $Request.InputStream
            $Lines = Get-PodeByteLinesFromByteArray -Bytes $Content -Encoding $Encoding -IncludeNewLine

            # get the indexes for boundary lines (start and end)
            $boundaryIndexes = @()
            for ($i = 0; $i -lt $Lines.Length; $i++) {
                if ((Test-PodeByteArrayIsBoundary -Bytes $Lines[$i] -Boundary $MetaData.Boundary.Start -Encoding $Encoding) -or
                    (Test-PodeByteArrayIsBoundary -Bytes $Lines[$i] -Boundary $MetaData.Boundary.End -Encoding $Encoding)) {
                    $boundaryIndexes += $i
                }
            }

            # loop through the boundary indexes (exclude last, as it's the end boundary)
            for ($i = 0; $i -lt ($boundaryIndexes.Length - 1); $i++)
            {
                $bIndex = $boundaryIndexes[$i]

                # the next line contains the key-value field names (content-disposition)
                $fields = @{}
                $disp = ConvertFrom-PodeBytesToString -Bytes $Lines[$bIndex+1] -Encoding $Encoding -RemoveNewLine

                foreach ($line in @($disp -isplit ';')) {
                    $atoms = @($line -isplit '=')
                    if ($atoms.Length -eq 2) {
                        $fields[$atoms[0].Trim()] = $atoms[1].Trim(' "')
                    }
                }

                # use the next line to work out field values
                if (!$fields.ContainsKey('filename')) {
                    $value = ConvertFrom-PodeBytesToString -Bytes $Lines[$bIndex+3] -Encoding $Encoding -RemoveNewLine
                    $Result.Data.Add($fields.name, $value)
                }

                # if we have a file, work out file and content type
                if ($fields.ContainsKey('filename')) {
                    $Result.Data.Add($fields.name, $fields.filename)

                    if (![string]::IsNullOrWhiteSpace($fields.filename)) {
                        $type = ConvertFrom-PodeBytesToString -Bytes $Lines[$bIndex+2] -Encoding $Encoding -RemoveNewLine

                        $Result.Files.Add($fields.filename, @{
                            'ContentType' = (@($type -isplit ':')[1].Trim());
                            'Bytes' = $null;
                        })

                        $bytes = @()
                        foreach ($b in ($Lines[($bIndex+4)..($boundaryIndexes[$i+1]-1)])) {
                            $bytes += $b
                        }

                        $Result.Files[$fields.filename].Bytes = (Remove-PodeNewLineBytesFromArray $bytes $Encoding)
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

function Get-PodeContentTypeAndBoundary
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

    if ([string]::IsNullOrWhiteSpace($ContentType)) {
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

function ConvertFrom-PodeNameValueToHashTable
{
    param (
        [Parameter()]
        $Collection
    )

    if ($null -eq $Collection) {
        return $null
    }

    $ht = @{}
    foreach ($key in $Collection.Keys) {
        $ht[$key] = $Collection[$key]
    }

    return $ht
}

function Get-PodeCount
{
    param (
        [Parameter()]
        $Object
    )

    if ($null -eq $Object) {
        return 0
    }

    if ($Object.Length -ge $Object.Count) {
        return $Object.Length
    }

    return $Object.Count
}

function Test-PodePathAccess
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
    if ([string]::IsNullOrWhiteSpace($Path) -or !(Test-Path $Path)) {
        if (!$NoStatus) {
            Set-PodeResponseStatus -Code 404
        }

        return $false
    }

    # if the file isn't accessible then fail 401
    if (!(Test-PodePathAccess $Path)) {
        if (!$NoStatus) {
            Set-PodeResponseStatus -Code 401
        }

        return $false
    }

    # if we're failing on a directory then fail on 404
    if ($FailOnDirectory -and (Test-PodePathIsDirectory $Path)) {
        if (!$NoStatus) {
            Set-PodeResponseStatus -Code 404
        }

        return $false
    }

    return $true
}

function Test-PodePathIsFile
{
    param (
        [Parameter()]
        [string]
        $Path,

        [switch]
        $FailOnWildcard
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $false
    }

    if ($FailOnWildcard -and (Test-PodePathIsWildcard $Path)) {
        return $false
    }

    return (![string]::IsNullOrWhiteSpace([System.IO.Path]::GetExtension($Path)))
}

function Test-PodePathIsWildcard
{
    param (
        [Parameter()]
        [string]
        $Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $false
    }

    return $Path.Contains('*')
}

function Test-PodePathIsDirectory
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Path,

        [switch]
        $FailOnWildcard
    )

    if ($FailOnWildcard -and (Test-PodePathIsWildcard $Path)) {
        return $false
    }

    return ([string]::IsNullOrWhiteSpace([System.IO.Path]::GetExtension($Path)))
}

function Convert-PodePathSeparators
{
    param (
        [Parameter()]
        $Paths
    )

    return @($Paths | ForEach-Object {
        if (![string]::IsNullOrWhiteSpace($_)) {
            $_ -ireplace '[\\/]', [System.IO.Path]::DirectorySeparatorChar
        }
    })
}

function Convert-PodePathPatternToRegex
{
    param (
        [Parameter()]
        [string]
        $Path,

        [switch]
        $NotSlashes,

        [switch]
        $NotStrict
    )    

    if (!$NotSlashes) {
        if ($Path -match '[\\/]\*$') {
            $Path = $Path -replace '[\\/]\*$', '/{0,1}*'
        }

        $Path = $Path -ireplace '[\\/]', '[\\/]'
    }

    $Path = $Path -ireplace '\.', '\.'

    $Path = $Path -ireplace '\*', '.*?'

    if ($NotStrict) {
        return $Path
    }

    return "^$($Path)$"
}

function Convert-PodePathPatternsToRegex
{
    param (
        [Parameter()]
        [string[]]
        $Paths,

        [switch]
        $NotSlashes,

        [switch]
        $NotStrict
    )

    # remove any empty entries
    $Paths = @($Paths | Where-Object {
        !(Test-IsEmpty $_)
    })

    # if no paths, return null
    if (Test-IsEmpty $Paths) {
        return $null
    }

    # replace certain chars
    $Paths = @($Paths | ForEach-Object {
        if (!(Test-IsEmpty $_)) {
            Convert-PodePathPatternToRegex -Path $_ -NotStrict -NotSlashes:$NotSlashes
        }
    })

    # join them all together
    $joined = "($($Paths -join '|'))"

    if ($NotStrict) {
        return "$($joined)"
    }

    return "^$($joined)$"
}

function Get-PodeModulePath
{
    # if there's 1 module imported already, use that
    $importedModule = @(Get-Module -Name Pode)
    if (($importedModule | Measure-Object).Count -eq 1) {
        return (@($importedModule)[0]).Path
    }

    # if there's none or more, attempt to get the module used for 'engine'
    try {
        $usedModule = (Get-Command -Name 'Set-PodeViewEngine').Module
        if (($usedModule | Measure-Object).Count -eq 1) {
            return $usedModule.Path
        }
    }
    catch { }

    # if there were multiple to begin with, use the newest version
    if (($importedModule | Measure-Object).Count -gt 1) {
        return (@($importedModule | Sort-Object -Property Version)[-1]).Path
    }

    # otherwise there were none, use the latest installed
    return (@(Get-Module -ListAvailable -Name Pode | Sort-Object -Property Version)[-1]).Path
}

function Get-PodeModuleRootPath
{
    return (Split-Path -Parent -Path $PodeContext.Server.PodeModulePath)
}

function Get-PodeUrl
{
    return "$($WebEvent.Protocol)://$($WebEvent.Endpoint)$($WebEvent.Path)"
}

function Find-PodeErrorPage
{
    param (
        [Parameter()]
        [int]
        $Code,

        [Parameter()]
        [string]
        $ContentType
    )

    # if a defined content type is supplied, attempt to find an error page for that first
    if (![string]::IsNullOrWhiteSpace($ContentType)) {
        $path = Get-PodeErrorPage -Code $Code -ContentType $ContentType
        if (![string]::IsNullOrWhiteSpace($path)) {
            return @{ 'Path' = $path; 'ContentType' = $ContentType }
        }
    }

    # if a defined route error page content type is supplied, attempt to find an error page for that
    if (![string]::IsNullOrWhiteSpace($WebEvent.ErrorType)) {
        $path = Get-PodeErrorPage -Code $Code -ContentType $WebEvent.ErrorType
        if (![string]::IsNullOrWhiteSpace($path)) {
            return @{ 'Path' = $path; 'ContentType' = $WebEvent.ErrorType }
        }
    }

    # if route patterns have been defined, see if an error content type matches and attempt that
    if (!(Test-IsEmpty $PodeContext.Server.Web.ErrorPages.Routes)) {
        # find type by pattern
        $matched = @(foreach ($key in $PodeContext.Server.Web.ErrorPages.Routes.Keys) {
            if ($WebEvent.Path -imatch $key) {
                $key
            }
        })[0]

        # if we have a match, see if a page exists
        if (!(Test-IsEmpty $matched)) {
            $type = $PodeContext.Server.Web.ErrorPages.Routes[$matched]
            $path = Get-PodeErrorPage -Code $Code -ContentType $type
            if (![string]::IsNullOrWhiteSpace($path)) {
                return @{ 'Path' = $path; 'ContentType' = $type }
            }
        }
    }

    # if we're using strict typing, attempt that, if we have a content type
    if ($PodeContext.Server.Web.ErrorPages.StrictContentTyping -and ![string]::IsNullOrWhiteSpace($WebEvent.ContentType)) {
        $path = Get-PodeErrorPage -Code $Code -ContentType $WebEvent.ContentType
        if (![string]::IsNullOrWhiteSpace($path)) {
            return @{ 'Path' = $path; 'ContentType' = $WebEvent.ContentType }
        }
    }

    # if we have a default defined, attempt that
    if (!(Test-IsEmpty $PodeContext.Server.Web.ErrorPages.Default)) {
        $path = Get-PodeErrorPage -Code $Code -ContentType $PodeContext.Server.Web.ErrorPages.Default
        if (![string]::IsNullOrWhiteSpace($path)) {
            return @{ 'Path' = $path; 'ContentType' = $PodeContext.Server.Web.ErrorPages.Default }
        }
    }

    # if there's still no error page, use default HTML logic
    $type = Get-PodeContentType -Extension 'html'
    $path = (Get-PodeErrorPage -Code $Code -ContentType $type)

    if (![string]::IsNullOrWhiteSpace($path)) {
        return @{ 'Path' = $path; 'ContentType' = $type }
    }

    return $null
}

function Get-PodeErrorPage
{
    param (
        [Parameter()]
        [int]
        $Code,

        [Parameter()]
        [string]
        $ContentType
    )

    # parse the passed content type
    $ContentType = (Get-PodeContentTypeAndBoundary -ContentType $ContentType).ContentType

    # object for the page path
    $path = $null

    # attempt to find a custom error page
    $path = Find-PodeCustomErrorPage -Code $Code -ContentType $ContentType

    # if there's no custom page found, attempt to find an inbuilt page
    if ([string]::IsNullOrWhiteSpace($path)) {
        $podeRoot = Join-Path (Get-PodeModuleRootPath) 'Misc'
        $path = Find-PodeFileForContentType -Path $podeRoot -Name 'default-error-page' -ContentType $ContentType -Engine 'pode'
    }

    # if there's no path found, or it's inaccessible, return null
    if (!(Test-PodePath $path -NoStatus)) {
        return $null
    }

    return $path
}

function Find-PodeCustomErrorPage
{
    param (
        [Parameter()]
        [int]
        $Code,

        [Parameter()]
        [string]
        $ContentType
    )

    # get the custom errors path
    $customErrPath = $PodeContext.Server.InbuiltDrives['errors']

    # if there's no custom error path, return
    if ([string]::IsNullOrWhiteSpace($customErrPath)) {
        return $null
    }

    # retrieve a status code page
    $path = (Find-PodeFileForContentType -Path $customErrPath -Name "$($Code)" -ContentType $ContentType)
    if (![string]::IsNullOrWhiteSpace($path)) {
        return $path
    }

    # retrieve default page
    $path = (Find-PodeFileForContentType -Path $customErrPath -Name 'default' -ContentType $ContentType)
    if (![string]::IsNullOrWhiteSpace($path)) {
        return $path
    }

    # no file was found
    return $null
}

function Find-PodeFileForContentType
{
    param (
        [Parameter()]
        [string]
        $Path,

        [Parameter()]
        [string]
        $Name,

        [Parameter()]
        [string]
        $ContentType,

        [Parameter()]
        [string]
        $Engine = $null
    )

    # get all files at the path that start with the name
    $files = @(Get-ChildItem -Path (Join-Path $Path "$($Name).*"))

    # if there are no files, return
    if ($null -eq $files -or $files.Length -eq 0) {
        return $null
    }

    # filter the files by the view engine extension (but only if the current engine is dynamic - non-html)
    if ([string]::IsNullOrWhiteSpace($Engine) -and $PodeContext.Server.ViewEngine.IsDynamic) {
        $Engine = $PodeContext.Server.ViewEngine.Extension
    }

    $Engine = (Protect-PodeValue -Value $Engine -Default 'pode')
    if ($Engine -ine 'pode') {
        $Engine = "($($Engine)|pode)"
    }

    $engineFiles = @(foreach ($file in $files) {
        if ($file.Name -imatch "\.$($Engine)$") {
            $file
        }
    })

    $files = @(foreach ($file in $files) {
        if ($file.Name -inotmatch "\.$($Engine)$") {
            $file
        }
    })

    # only attempt static files if we still have files after any engine filtering
    if ($null -ne $files -and $files.Length -gt 0)
    {
        # get files of the format '<name>.<type>'
        $file = @(foreach ($f in $files) {
            if ($f.Name -imatch "^$($Name)\.(?<ext>.*?)$") {
                if (($ContentType -ieq (Get-PodeContentType -Extension $Matches['ext']))) {
                    $f.FullName
                }
            }
        })[0]

        if (![string]::IsNullOrWhiteSpace($file)) {
            return $file
        }
    }

    # only attempt these formats if we have a files for the view engine
    if ($null -ne $engineFiles -and $engineFiles.Length -gt 0)
    {
        # get files of the format '<name>.<type>.<engine>'
        $file = @(foreach ($f in $engineFiles) {
            if ($f.Name -imatch "^$($Name)\.(?<ext>.*?)\.$($engine)$") {
                if ($ContentType -ieq (Get-PodeContentType -Extension $Matches['ext'])) {
                    $f.FullName
                }
            }
        })[0]

        if (![string]::IsNullOrWhiteSpace($file)) {
            return $file
        }

        # get files of the format '<name>.<engine>'
        $file = @(foreach ($f in $engineFiles) {
            if ($f.Name -imatch "^$($Name)\.$($engine)$") {
                $f.FullName
            }
        })[0]

        if (![string]::IsNullOrWhiteSpace($file)) {
            return $file
        }
    }

    # no file was found
    return $null
}

function Test-PodePathIsRelative
{
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Path
    )

    if (@('.', '..') -contains $Path) {
        return $true
    }

    return ($Path -match '^\.{1,2}[\\/]')
}

function Get-PodeRelativePath
{
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Path,

        [Parameter()]
        [string]
        $RootPath,

        [switch]
        $JoinRoot,

        [switch]
        $Resolve,

        [switch]
        $TestPath
    )

    # if the path is relative, join to root if flagged
    if ($JoinRoot -and (Test-PodePathIsRelative -Path $Path)) {
        if ([string]::IsNullOrWhiteSpace($RootPath)) {
            $RootPath = $PodeContext.Server.Root
        }

        $Path = Join-Path $RootPath $Path
    }

    # if flagged, resolve the path
    if ($Resolve) {
        $_rawPath = $Path
        $Path = (Resolve-Path -Path $Path -ErrorAction Ignore).Path
    }

    # if flagged, test the path and throw error if it doesn't exist
    if ($TestPath -and !(Test-PodePath $Path -NoStatus)) {
        throw "The path does not exist: $(Protect-PodeValue -Value $Path -Default $_rawPath)"
    }

    return $Path
}

function Get-PodeWildcardFiles
{
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Path,

        [Parameter()]
        [string]
        $Wildcard = '*.*'
    )

    # if the OriginalPath is a directory, add wildcard
    if (Test-PodePathIsDirectory -Path $Path) {
        $Path = (Join-Path $Path $Wildcard)
    }

    # if path has a *, assume wildcard
    if (Test-PodePathIsWildcard -Path $Path) {
        $Path = Get-PodeRelativePath -Path $Path -JoinRoot
        return @((Get-ChildItem $Path -Recurse -Force).FullName)
    }

    return $null
}

function Test-PodeIsServerless
{
    param (
        [Parameter()]
        [string]
        $FunctionName,

        [switch]
        $ThrowError
    )

    if ($PodeContext.Server.IsServerless -and $ThrowError) {
        throw "The $($FunctionName) function is not supported in a serverless context"
    }

    if (!$ThrowError) {
        return $PodeContext.Server.IsServerless
    }
}

function Get-PodeEndpointUrl
{
    param (
        [Parameter()]
        $Endpoint
    )

    # get the endpoint on which we're currently listening - use first if there are many
    if ($null -eq $Endpoint) {
        $Endpoint = $PodeContext.Server.Endpoints[0]
    }

    # work out the protocol
    $protocol = (Resolve-PodeValue -Check $Endpoint.Ssl -TrueValue 'https' -FalseValue 'http')

    # grab the port number
    $port = $Endpoint.Port
    if ($port -eq 0) {
        $port = (Resolve-PodeValue -Check $Endpoint.Ssl -TrueValue 8443 -FalseValue 8080)
    }

    return "$($protocol)://$($Endpoint.HostName):$($port)"
}

function Set-PodeServerHeader
{
    param (
        [Parameter()]
        [string]
        $Type
    )

    Set-PodeHeader -Name 'Server' -Value "Pode - $($Type)"
}