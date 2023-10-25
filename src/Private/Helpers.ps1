using namespace Pode

# read in the content from a dynamic pode file and invoke its content
function ConvertFrom-PodeFile {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        $Content,

        [Parameter()]
        $Data = @{}
    )

    # if we have data, then setup the data param
    if ($null -ne $Data -and $Data.Count -gt 0) {
        $Content = "param(`$data)`nreturn `"$($Content -replace '"', '``"')`""
    } else {
        $Content = "return `"$($Content -replace '"', '``"')`""
    }

    # invoke the content as a script to generate the dynamic content
    return (Invoke-PodeScriptBlock -ScriptBlock ([scriptblock]::Create($Content)) -Arguments $Data -Return)
}

function Get-PodeViewEngineType {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Path
    )

    # work out the engine to use when parsing the file
    $type = $PodeContext.Server.ViewEngine.Type

    $ext = Get-PodeFileExtension -Path $Path -TrimPeriod
    if (![string]::IsNullOrWhiteSpace($ext) -and ($ext -ine $PodeContext.Server.ViewEngine.Extension)) {
        $type = $ext
    }

    return $type
}

function Get-PodeFileContentUsingViewEngine {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Path,

        [Parameter()]
        [hashtable]
        $Data
    )

    # work out the engine to use when parsing the file
    $engine = Get-PodeViewEngineType -Path $Path

    # setup the content
    $content = [string]::Empty

    # run the relevant engine logic
    switch ($engine.ToLowerInvariant()) {
        'html' {
            $content = Get-Content -Path $Path -Raw -Encoding utf8
        }

        'md' {
            $content = Get-Content -Path $Path -Raw -Encoding utf8
        }

        'pode' {
            $content = Get-Content -Path $Path -Raw -Encoding utf8
            $content = ConvertFrom-PodeFile -Content $content -Data $Data
        }

        default {
            if ($null -ne $PodeContext.Server.ViewEngine.ScriptBlock) {
                $_args = @($Path)
                if (($null -ne $Data) -and ($Data.Count -gt 0)) {
                    $_args = @($Path, $Data)
                }

                $_args = @(Get-PodeScriptblockArguments -ArgumentList $_args -UsingVariables $PodeContext.Server.ViewEngine.UsingVariables)
                $content = (Invoke-PodeScriptBlock -ScriptBlock $PodeContext.Server.ViewEngine.ScriptBlock -Arguments $_args -Return -Splat)
            }
        }
    }

    return $content
}

function Get-PodeFileContent {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Path
    )

    return (Get-Content -Path $Path -Raw -Encoding utf8)
}

function Get-PodeType {
    param(
        [Parameter()]
        $Value
    )

    if ($null -eq $Value) {
        return $null
    }

    $type = $Value.GetType()
    return @{
        Name     = $type.Name.ToLowerInvariant()
        BaseName = $type.BaseType.Name.ToLowerInvariant()
    }
}

function Get-PodePSVersionTable {
    return $PSVersionTable
}

function Test-PodeIsAdminUser {
    # check the current platform, if it's unix then return true
    if (Test-PodeIsUnix) {
        return $true
    }

    try {
        $principal = New-Object System.Security.Principal.WindowsPrincipal([System.Security.Principal.WindowsIdentity]::GetCurrent())
        if ($null -eq $principal) {
            return $false
        }

        return $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch [exception] {
        Write-PodeHost 'Error checking user administrator priviledges' -ForegroundColor Red
        Write-PodeHost $_.Exception.Message -ForegroundColor Red
        return $false
    }
}

function Get-PodeHostIPRegex {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Both', 'Hostname', 'IP')]
        [string]
        $Type
    )

    $ip_rgx = '\[[a-f0-9\:]+\]|((\d+\.){3}\d+)|\:\:\d*|\*|all'
    $host_rgx = '([a-z]|\*\.)(([a-z0-9]|[a-z0-9][a-z0-9\-]*[a-z0-9])\.)*([a-z0-9]|[a-z0-9][a-z0-9\-]*[a-z0-9])+'

    switch ($Type.ToLowerInvariant()) {
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

function Get-PortRegex {
    return '(?<port>\d+)'
}

function Get-PodeEndpointInfo {
    param(
        [Parameter()]
        [string]
        $Address,

        [switch]
        $AnyPortOnZero
    )

    if ([string]::IsNullOrWhiteSpace($Address)) {
        return $null
    }

    $hostRgx = Get-PodeHostIPRegex -Type Both
    $portRgx = Get-PortRegex
    $cmbdRgx = "$($hostRgx)\:$($portRgx)"

    # validate that we have a valid ip/host:port address
    if (!(($Address -imatch "^$($cmbdRgx)$") -or ($Address -imatch "^$($hostRgx)[\:]{0,1}") -or ($Address -imatch "[\:]{0,1}$($portRgx)$"))) {
        throw "Failed to parse '$($Address)' as a valid IP/Host:Port address"
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
        Host = $_host
        Port = (Resolve-PodeValue -Check ($AnyPortOnZero -and ($_port -eq 0)) -TrueValue '*' -FalseValue $_port)
    }
}

function Test-PodeIPAddress {
    param(
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
        $null = [System.Net.IPAddress]::Parse($IP)
        return $true
    } catch [exception] {
        return $false
    }
}

function Test-PodeHostname {
    param(
        [Parameter()]
        [string]
        $Hostname
    )

    return ($Hostname -imatch "^$(Get-PodeHostIPRegex -Type Hostname)$")
}

function ConvertTo-PodeIPAddress {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        $Address
    )

    return [System.Net.IPAddress]::Parse(([System.Net.IPEndPoint]$Address).Address.ToString())
}

function Get-PodeIPAddressesForHostname {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Hostname,

        [Parameter(Mandatory = $true)]
        [ValidateSet('All', 'IPv4', 'IPv6')]
        [string]
        $Type
    )

    if (!(Test-PodeHostname -Hostname $Hostname)) {
        return $Hostname
    }

    # get the ip addresses for the hostname
    try {
        $ips = @([System.Net.Dns]::GetHostAddresses($Hostname))
    } catch {
        return '127.0.0.1'
    }

    # return ips based on type
    switch ($Type.ToLowerInvariant()) {
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

function Test-PodeIPAddressLocal {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $IP
    )

    return (@('127.0.0.1', '::1', '[::1]', 'localhost') -icontains $IP)
}

function Test-PodeIPAddressAny {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $IP
    )

    return (@('0.0.0.0', '*', 'all', '::', '[::]') -icontains $IP)
}

function Test-PodeIPAddressLocalOrAny {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $IP
    )

    return ((Test-PodeIPAddressLocal -IP $IP) -or (Test-PodeIPAddressAny -IP $IP))
}

function Get-PodeIPAddress {
    param(
        [Parameter()]
        [string]
        $IP
    )

    # any address for IPv4
    if ([string]::IsNullOrWhiteSpace($IP) -or ($IP -ieq '*') -or ($IP -ieq 'all')) {
        return [System.Net.IPAddress]::Any
    }

    # any address for IPv6
    if (($IP -ieq '::') -or ($IP -ieq '[::]')) {
        return [System.Net.IPAddress]::IPv6Any
    }

    # localhost
    if ($IP -ieq 'localhost') {
        return [System.Net.IPAddress]::Loopback
    }

    # hostname
    if ($IP -imatch "^$(Get-PodeHostIPRegex -Type Hostname)$") {
        return $IP
    }

    # raw ip
    return [System.Net.IPAddress]::Parse($IP)
}

function Test-PodeIPAddressInRange {
    param(
        [Parameter(Mandatory = $true)]
        $IP,

        [Parameter(Mandatory = $true)]
        $LowerIP,

        [Parameter(Mandatory = $true)]
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

function Test-PodeIPAddressIsSubnetMask {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $IP
    )

    return (($IP -split '/').Length -gt 1)
}

function Get-PodeSubnetRange {
    param(
        [Parameter(Mandatory = $true)]
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
    $network = @('', '', '', '')
    $count = 0

    foreach ($i in 0..3) {
        foreach ($b in 1..8) {
            $count++

            if ($count -le $bits) {
                $network[$i] += '1'
            } else {
                $network[$i] += '0'
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
        'Lower'   = ($bottom -join '.')
        'Upper'   = ($top -join '.')
        'Range'   = ($range -join '.')
        'Netmask' = ($network -join '.')
        'IP'      = ($ip_parts -join '.')
    }
}

function Add-PodeRunspace {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Main', 'Signals', 'Schedules', 'Gui', 'Web', 'Smtp', 'Tcp', 'Tasks', 'WebSockets', 'Files')]
        [string]
        $Type,

        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        $Parameters,

        [Parameter()]
        [System.Management.Automation.PSDataCollection[psobject]]
        $OutputStream = $null,

        [switch]
        $Forget,

        [switch]
        $NoProfile,

        [switch]
        $PassThru
    )

    try {
        # create powershell pipelines
        $ps = [powershell]::Create()
        $ps.RunspacePool = $PodeContext.RunspacePools[$Type].Pool

        # load modules/drives
        if (!$NoProfile) {
            $null = $ps.AddScript("Open-PodeRunspace -Type '$($Type)'")
        }

        # load main script
        $null = $ps.AddScript($ScriptBlock)

        # load parameters
        if (!(Test-PodeIsEmpty $Parameters)) {
            $Parameters.Keys | ForEach-Object {
                $null = $ps.AddParameter($_, $Parameters[$_])
            }
        }

        # start the pipeline
        if ($null -eq $OutputStream) {
            $pipeline = $ps.BeginInvoke()
        } else {
            $pipeline = $ps.BeginInvoke($OutputStream, $OutputStream)
        }

        # do we need to remember this pipeline? sorry, what did you say?
        if ($Forget) {
            $null = $pipeline
        }

        # or do we need to return it for custom processing? ie: tasks
        elseif ($PassThru) {
            return @{
                Pipeline = $ps
                Handler  = $pipeline
            }
        }

        # or store it here for later clean-up
        else {
            $PodeContext.Runspaces += @{
                Pool     = $Type
                Pipeline = $ps
                Handler  = $pipeline
                Stopped  = $false
            }
        }
    } catch {
        $_ | Write-PodeErrorLog
        throw $_.Exception
    }
}

function Open-PodeRunspace {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Type
    )

    try {
        Import-PodeModules
        Add-PodePSDrives
        $PodeContext.RunspacePools[$Type].State = 'Ready'
    } catch {
        if ($PodeContext.RunspacePools[$Type].State -ieq 'waiting') {
            $PodeContext.RunspacePools[$Type].State = 'Error'
        }

        $_ | Out-Default
        $_.ScriptStackTrace | Out-Default
        throw
    }
}

function Close-PodeRunspaces {
    param(
        [switch]
        $ClosePool
    )

    if ($PodeContext.Server.IsServerless) {
        return
    }

    try {
        if (!(Test-PodeIsEmpty $PodeContext.Runspaces)) {
            Write-Verbose 'Waiting until all Listeners are disposed'

            $count = 0
            $continue = $false
            while ($count -le 10) {
                Start-Sleep -Seconds 1
                $count++

                $continue = $false
                foreach ($listener in $PodeContext.Listeners) {
                    if (!$listener.IsDisposed) {
                        $continue = $true
                        break
                    }
                }

                foreach ($receiver in $PodeContext.Receivers) {
                    if (!$receiver.IsDisposed) {
                        $continue = $true
                        break
                    }
                }

                foreach ($watcher in $PodeContext.Watchers) {
                    if (!$watcher.IsDisposed) {
                        $continue = $true
                        break
                    }
                }

                if ($continue) {
                    continue
                }

                break
            }

            Write-Verbose 'All Listeners disposed'

            # now dispose runspaces
            Write-Verbose 'Disposing Runspaces'
            $runspaceErrors = @(foreach ($item in $PodeContext.Runspaces) {
                    if ($item.Stopped) {
                        continue
                    }

                    try {
                        # only do this, if the pool is in error
                        if ($PodeContext.RunspacePools[$item.Pool].State -ieq 'error') {
                            $item.Pipeline.EndInvoke($item.Handler)
                        }
                    } catch {
                        "$($item.Pool) runspace failed to load: $($_.Exception.InnerException.Message)"
                    }

                    Close-PodeDisposable -Disposable $item.Pipeline
                    $item.Stopped = $true
                })

            # dispose of schedule runspaces
            if ($PodeContext.Schedules.Processes.Count -gt 0) {
                foreach ($key in $PodeContext.Schedules.Processes.Keys.Clone()) {
                    Close-PodeScheduleInternal -Process $PodeContext.Schedules.Processes[$key]
                }
            }

            # dispose of task runspaces
            if ($PodeContext.Tasks.Results.Count -gt 0) {
                foreach ($key in $PodeContext.Tasks.Results.Keys.Clone()) {
                    Close-PodeTaskInternal -Result $PodeContext.Tasks.Results[$key]
                }
            }

            $PodeContext.Runspaces = @()
            Write-Verbose 'Runspaces disposed'
        }

        # close/dispose the runspace pools
        if ($ClosePool) {
            Close-PodeRunspacePools
        }

        # check for runspace errors
        if (($null -ne $runspaceErrors) -and ($runspaceErrors.Length -gt 0)) {
            foreach ($err in $runspaceErrors) {
                if ($null -eq $err) {
                    continue
                }

                throw $err
            }
        }

        # garbage collect
        [GC]::Collect()
    } catch {
        $_ | Write-PodeErrorLog
        throw $_.Exception
    }
}

function Get-PodeConsoleKey {
    if ([Console]::IsInputRedirected -or ![Console]::KeyAvailable) {
        return $null
    }

    return [Console]::ReadKey($true)
}

function Test-PodeTerminationPressed {
    param(
        [Parameter()]
        $Key = $null
    )

    if ($PodeContext.Server.DisableTermination) {
        return $false
    }

    return (Test-PodeKeyPressed -Key $Key -Character 'c')
}

function Test-PodeRestartPressed {
    param(
        [Parameter()]
        $Key = $null
    )

    return (Test-PodeKeyPressed -Key $Key -Character 'r')
}

function Test-PodeOpenBrowserPressed {
    param(
        [Parameter()]
        $Key = $null
    )

    return (Test-PodeKeyPressed -Key $Key -Character 'b')
}

function Test-PodeKeyPressed {
    param(
        [Parameter()]
        $Key = $null,

        [Parameter(Mandatory = $true)]
        [string]
        $Character
    )

    if ($null -eq $Key) {
        $Key = Get-PodeConsoleKey
    }

    return (($null -ne $Key) -and ($Key.Key -ieq $Character) -and
        (($Key.Modifiers -band [ConsoleModifiers]::Control) -or ((Test-PodeIsUnix) -and ($Key.Modifiers -band [ConsoleModifiers]::Shift))))
}

function Close-PodeServerInternal {
    param(
        [switch]
        $ShowDoneMessage
    )

    # ensure the token is cancelled
    if ($null -ne $PodeContext.Tokens.Cancellation) {
        Write-Verbose 'Cancelling main cancellation token'
        $PodeContext.Tokens.Cancellation.Cancel()
    }

    # stop all current runspaces
    Write-Verbose 'Closing runspaces'
    Close-PodeRunspaces -ClosePool

    # stop the file monitor if it's running
    Write-Verbose 'Stopping file monitor'
    Stop-PodeFileMonitor

    try {
        # remove all the cancellation tokens
        Write-Verbose 'Disposing cancellation tokens'
        Close-PodeDisposable -Disposable $PodeContext.Tokens.Cancellation
        Close-PodeDisposable -Disposable $PodeContext.Tokens.Restart

        # dispose mutex/semaphores
        Write-Verbose 'Diposing mutex and semaphores'
        Clear-PodeMutexes
        Clear-PodeSemaphores
    } catch {
        $_ | Out-Default
    }

    # remove all of the pode temp drives
    Write-Verbose 'Removing internal PSDrives'
    Remove-PodePSDrives

    if ($ShowDoneMessage -and ($PodeContext.Server.Types.Length -gt 0) -and !$PodeContext.Server.IsServerless) {
        Write-PodeHost ' Done' -ForegroundColor Green
    }
}

function New-PodePSDrive {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Path,

        [Parameter()]
        [string]
        $Name
    )

    # if the path is a share, do nothing
    if ($Path.StartsWith('\\')) {
        return $Path
    }

    # if no name is passed, used a randomly generated one
    if ([string]::IsNullOrWhiteSpace($Name)) {
        $Name = "PodeDir$(New-PodeGuid)"
    }

    # if the path supplied doesn't exist, error
    if (!(Test-Path $Path)) {
        throw "Path does not exist: $($Path)"
    }

    # resolve the path
    $Path = Get-PodeRelativePath -Path $Path -JoinRoot -Resolve

    # create the temp drive
    if (!(Test-PodePSDrive -Name $Name -Path $Path)) {
        $drive = (New-PSDrive -Name $Name -PSProvider FileSystem -Root $Path -Scope Global -ErrorAction Stop)
    } else {
        $drive = Get-PodePSDrive -Name $Name
    }

    # store internally, and return the drive's name
    if (!$PodeContext.Server.Drives.ContainsKey($drive.Name)) {
        $PodeContext.Server.Drives[$drive.Name] = $Path
    }

    return "$($drive.Name):$([System.IO.Path]::DirectorySeparatorChar)"
}

function Get-PodePSDrive {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    return (Get-PSDrive -Name $Name -PSProvider FileSystem -Scope Global -ErrorAction Ignore)
}

function Test-PodePSDrive {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter()]
        [string]
        $Path
    )

    $drive = Get-PodePSDrive -Name $Name
    if ($null -eq $drive) {
        return $false
    }

    if (![string]::IsNullOrWhiteSpace($Path)) {
        return ($drive.Root -ieq $Path)
    }

    return $true
}

function Add-PodePSDrives {
    foreach ($key in $PodeContext.Server.Drives.Keys) {
        $null = New-PodePSDrive -Path $PodeContext.Server.Drives[$key] -Name $key
    }
}

function Import-PodeModules {
    # import other modules in the session
    foreach ($path in $PodeContext.Server.Modules.Values) {
        $null = Import-Module $path -DisableNameChecking -Scope Global -ErrorAction Stop
    }
}

function Add-PodePSInbuiltDrives {
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

function Remove-PodePSDrives {
    $null = Get-PSDrive PodeDir* | Remove-PSDrive
}

function Join-PodeServerRoot {
    param(
        [Parameter(Mandatory = $true)]
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
    return [System.IO.Path]::Combine($Root, $Folder, $FilePath)
}

function Remove-PodeEmptyItemsFromArray {
    param(
        [Parameter(ValueFromPipeline = $true)]
        $Array
    )

    if ($null -eq $Array) {
        return @()
    }

    return @( @($Array -ne ([string]::Empty)) -ne $null )
}

function Remove-PodeNullKeysFromHashtable {
    param(
        [Parameter(ValueFromPipeline = $true)]
        [hashtable]
        $Hashtable
    )

    foreach ($key in ($Hashtable.Clone()).Keys) {
        if ($null -eq $Hashtable[$key]) {
            $null = $Hashtable.Remove($key)
            continue
        }

        if (($Hashtable[$key] -is [string]) -and [string]::IsNullOrEmpty($Hashtable[$key])) {
            $null = $Hashtable.Remove($key)
            continue
        }

        if ($Hashtable[$key] -is [array]) {
            if (($Hashtable[$key].Length -eq 1) -and ($null -eq $Hashtable[$key][0])) {
                $null = $Hashtable.Remove($key)
                continue
            }

            foreach ($item in $Hashtable[$key]) {
                if (($item -is [hashtable]) -or ($item -is [System.Collections.Specialized.OrderedDictionary])) {
                    $item | Remove-PodeNullKeysFromHashtable
                }
            }

            continue
        }

        if (($Hashtable[$key] -is [hashtable]) -or ($Hashtable[$key] -is [System.Collections.Specialized.OrderedDictionary])) {
            $Hashtable[$key] | Remove-PodeNullKeysFromHashtable
            continue
        }
    }
}

function Get-PodeFileExtension {
    param(
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

function Get-PodeFileName {
    param(
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

function Test-PodeValidNetworkFailure {
    param(
        [Parameter()]
        $Exception
    )

    $msgs = @(
        '*network name is no longer available*',
        '*nonexistent network connection*',
        '*the response has completed*',
        '*broken pipe*'
    )

    $match = @(foreach ($msg in $msgs) {
            if ($Exception.Message -ilike $msg) {
                $msg
            }
        })[0]

    return ($null -ne $match)
}

function ConvertFrom-PodeHeaderQValue {
    param(
        [Parameter(ValueFromPipeline = $true)]
        [string]
        $Value
    )

    $qs = [ordered]@{}

    # return if no value
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $qs
    }

    # split the values up
    $parts = @($Value -isplit ',').Trim()

    # go through each part and check its q-value
    foreach ($part in $parts) {
        # default of 1 if no q-value
        if ($part.IndexOf(';q=') -eq -1) {
            $qs[$part] = 1.0
            continue
        }

        # parse for q-value
        $atoms = @($part -isplit ';q=')
        $qs[$atoms[0]] = [double]$atoms[1]
    }

    return $qs
}

function Get-PodeAcceptEncoding {
    param(
        [Parameter()]
        [string]
        $AcceptEncoding,

        [switch]
        $ThrowError
    )

    # return if no encoding
    if ([string]::IsNullOrWhiteSpace($AcceptEncoding)) {
        return [string]::Empty
    }

    # return empty if not compressing
    if (!$PodeContext.Server.Web.Compression.Enabled) {
        return [string]::Empty
    }

    # convert encoding form q-form
    $encodings = ConvertFrom-PodeHeaderQValue -Value $AcceptEncoding
    if ($encodings.Count -eq 0) {
        return [string]::Empty
    }

    # check the encodings for one that matches
    $normal = @('identity', '*')
    $valid = @()

    # build up supported and invalid
    foreach ($encoding in $encodings.Keys) {
        if (($encoding -iin $PodeContext.Server.Compression.Encodings) -or ($encoding -iin $normal)) {
            $valid += @{
                Name  = $encoding
                Value = $encodings[$encoding]
            }
        }
    }

    # if it's empty, just return empty
    if ($valid.Length -eq 0) {
        return [string]::Empty
    }

    # find the highest ranked match
    $found = @{}
    $failOnIdentity = $false

    foreach ($encoding in $valid) {
        if ($encoding.Value -gt $found.Value) {
            $found = $encoding
        }

        if (!$failOnIdentity -and ($encoding.Value -eq 0) -and ($encoding.Name -iin $normal)) {
            $failOnIdentity = $true
        }
    }

    # force found to identity/* if the 0 is not identity - meaning it's still allowed
    if (($found.Value -eq 0) -and !$failOnIdentity) {
        $found = @{
            Name  = 'identity'
            Value = 1.0
        }
    }

    # return invalid, error, or return empty for idenity?
    if ($found.Value -eq 0) {
        if ($ThrowError) {
            throw (New-PodeRequestException -StatusCode 406)
        }
    }

    # else, we're safe
    if ($found.Name -iin $normal) {
        return [string]::Empty
    }

    if ($found.Name -ieq 'x-gzip') {
        return 'gzip'
    }

    return $found.Name
}

function Get-PodeRanges {
    param(
        [Parameter()]
        [string]
        $Range,

        [switch]
        $ThrowError
    )

    # return if no ranges
    if ([string]::IsNullOrWhiteSpace($Range)) {
        return $null
    }

    # split on '='
    $parts = @($Range -isplit '=').Trim()
    if (($parts.Length -le 1) -or ([string]::IsNullOrWhiteSpace($parts[1]))) {
        return $null
    }

    $unit = $parts[0]
    if ($unit -ine 'bytes') {
        if ($ThrowError) {
            throw (New-PodeRequestException -StatusCode 416)
        }

        return $null
    }

    # split on ','
    $parts = @($parts[1] -isplit ',').Trim()

    # parse into From-To hashtable array
    $ranges = @()

    foreach ($atom in $parts) {
        if ($atom -inotmatch '(?<start>[\d]+){0,1}\s?\-\s?(?<end>[\d]+){0,1}') {
            if ($ThrowError) {
                throw (New-PodeRequestException -StatusCode 416)
            }

            return $null
        }

        $ranges += @{
            Start = $Matches['start']
            End   = $Matches['end']
        }
    }

    return $ranges
}

function Get-PodeTransferEncoding {
    param(
        [Parameter()]
        [string]
        $TransferEncoding,

        [switch]
        $ThrowError
    )

    # return if no encoding
    if ([string]::IsNullOrWhiteSpace($TransferEncoding)) {
        return [string]::Empty
    }

    # convert encoding form q-form
    $encodings = ConvertFrom-PodeHeaderQValue -Value $TransferEncoding
    if ($encodings.Count -eq 0) {
        return [string]::Empty
    }

    # check the encodings for one that matches
    $normal = @('chunked', 'identity')
    $invalid = @()

    # if we see a supported one, return immediately. else build up invalid one
    foreach ($encoding in $encodings.Keys) {
        if ($encoding -iin $PodeContext.Server.Compression.Encodings) {
            if ($encoding -ieq 'x-gzip') {
                return 'gzip'
            }

            return $encoding
        }

        if ($encoding -iin $normal) {
            continue
        }

        $invalid += $encoding
    }

    # if we have any invalid, throw a 415 error
    if ($invalid.Length -gt 0) {
        if ($ThrowError) {
            throw (New-PodeRequestException -StatusCode 415)
        }

        return $invalid[0]
    }

    # else, we're safe
    return [string]::Empty
}

function Get-PodeEncodingFromContentType {
    param(
        [Parameter()]
        [string]
        $ContentType
    )

    if ([string]::IsNullOrWhiteSpace($ContentType)) {
        return [System.Text.Encoding]::UTF8
    }

    $parts = @($ContentType -isplit ';').Trim()

    foreach ($part in $parts) {
        if ($part.StartsWith('charset')) {
            return [System.Text.Encoding]::GetEncoding(($part -isplit '=')[1].Trim())
        }
    }

    return [System.Text.Encoding]::UTF8
}

function New-PodeRequestException {
    param(
        [Parameter(Mandatory = $true)]
        [int]
        $StatusCode
    )

    $err = [System.Net.Http.HttpRequestException]::new()
    $err.Data.Add('PodeStatusCode', $StatusCode)
    return $err
}

function ConvertTo-PodeResponseContent {
    param(
        [Parameter(ValueFromPipeline = $true)]
        $InputObject,

        [Parameter()]
        [string]
        $ContentType,

        [Parameter()]
        [int]
        $Depth = 10,

        [Parameter()]
        [string]
        $Delimiter = ',',

        [switch]
        $AsHtml
    )

    # split for the main content type
    $ContentType = Split-PodeContentType -ContentType $ContentType

    # if there is no content-type then convert straight to string
    if ([string]::IsNullOrWhiteSpace($ContentType)) {
        return ([string]$InputObject)
    }

    # run action for the content type
    switch ($ContentType) {
        { $_ -ilike '*/json' } {
            if ($InputObject -isnot [string]) {
                if ($Depth -le 0) {
                    return (ConvertTo-Json -InputObject $InputObject -Compress)
                } else {
                    return (ConvertTo-Json -InputObject $InputObject -Depth $Depth -Compress)
                }
            }

            if ([string]::IsNullOrWhiteSpace($InputObject)) {
                return '{}'
            }
        }

        { $_ -ilike '*/yaml' -or $_ -ilike '*/x-yaml' } {
            if ($InputObject -isnot [string]) {
                if ($Depth -le 0) {
                    return (ConvertTo-PodeYamlInternal -InputObject $InputObject )
                } else {
                    return (ConvertTo-PodeYamlInternal -InputObject $InputObject -Depth $Depth  )
                }
            }

            if ([string]::IsNullOrWhiteSpace($InputObject)) {
                return '[]'
            }
        }

        { $_ -ilike '*/xml' } {
            if ($InputObject -isnot [string]) {
                $temp = @(foreach ($item in $InputObject) {
                        New-Object psobject -Property $item
                    })

                return ($temp | ConvertTo-Xml -Depth $Depth -As String -NoTypeInformation)
            }

            if ([string]::IsNullOrWhiteSpace($InputObject)) {
                return [string]::Empty
            }
        }

        { $_ -ilike '*/csv' } {
            if ($InputObject -isnot [string]) {
                $temp = @(foreach ($item in $InputObject) {
                        New-Object psobject -Property $item
                    })

                if (Test-PodeIsPSCore) {
                    $temp = ($temp | ConvertTo-Csv -Delimiter $Delimiter -IncludeTypeInformation:$false)
                } else {
                    $temp = ($temp | ConvertTo-Csv -Delimiter $Delimiter -NoTypeInformation)
                }

                return ($temp -join ([environment]::NewLine))
            }

            if ([string]::IsNullOrWhiteSpace($InputObject)) {
                return [string]::Empty
            }
        }

        { $_ -ilike '*/html' } {
            if ($InputObject -isnot [string]) {
                return (($InputObject | ConvertTo-Html) -join ([environment]::NewLine))
            }

            if ([string]::IsNullOrWhiteSpace($InputObject)) {
                return [string]::Empty
            }
        }

        { $_ -ilike '*/markdown' } {
            if ($AsHtml -and ($PSVersionTable.PSVersion.Major -ge 7)) {
                return ($InputObject | ConvertFrom-Markdown).Html
            }
        }
    }

    return ([string]$InputObject)
}

function ConvertFrom-PodeRequestContent {
    param(
        [Parameter()]
        $Request,

        [Parameter()]
        [string]
        $ContentType,

        [Parameter()]
        [string]
        $TransferEncoding
    )

    # get the requests content type
    $ContentType = Split-PodeContentType -ContentType $ContentType

    # result object for data/files
    $Result = @{
        Data  = @{}
        Files = @{}
    }

    # if there is no content-type then do nothing
    if ([string]::IsNullOrWhiteSpace($ContentType)) {
        return $Result
    }

    # if the content-type is not multipart/form-data, get the string data
    if ($ContentType -ine 'multipart/form-data') {
        # get the content based on server type
        if ($PodeContext.Server.IsServerless) {
            switch ($PodeContext.Server.ServerlessType.ToLowerInvariant()) {
                'awslambda' {
                    $Content = $Request.body
                }

                'azurefunctions' {
                    $Content = $Request.RawBody
                }
            }
        } else {
            # if the request is compressed, attempt to uncompress it
            if (![string]::IsNullOrWhiteSpace($TransferEncoding)) {
                # create a compressed stream to decompress the req bytes
                $ms = New-Object -TypeName System.IO.MemoryStream
                $ms.Write($Request.RawBody, 0, $Request.RawBody.Length)
                $null = $ms.Seek(0, 0)
                $stream = New-Object "System.IO.Compression.$($TransferEncoding)Stream"($ms, [System.IO.Compression.CompressionMode]::Decompress)

                # read the decompressed bytes
                $Content = Read-PodeStreamToEnd -Stream $stream -Encoding $Request.ContentEncoding
            } else {
                $Content = $Request.Body
            }
        }

        # if there is no content then do nothing
        if ([string]::IsNullOrWhiteSpace($Content)) {
            return $Result
        }

        # check if there is a defined custom body parser
        if ($PodeContext.Server.BodyParsers.ContainsKey($ContentType)) {
            $parser = $PodeContext.Server.BodyParsers[$ContentType]
            $_args = @(Get-PodeScriptblockArguments -ArgumentList $Content -UsingVariables $parser.UsingVariables)
            $Result.Data = (Invoke-PodeScriptBlock -ScriptBlock $parser.ScriptBlock -Arguments $_args -Return)
            $Content = $null
            return $Result
        }
    }

    # run action for the content type
    switch ($ContentType) {
        { $_ -ilike '*/json' } {
            if (Test-PodeIsPSCore) {
                $Result.Data = ($Content | ConvertFrom-Json -AsHashtable)
            } else {
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
            # parse multipart form data
            $form = $null

            if ($PodeContext.Server.IsServerless) {
                switch ($PodeContext.Server.ServerlessType.ToLowerInvariant()) {
                    'awslambda' {
                        $Content = $Request.body
                    }

                    'azurefunctions' {
                        $Content = $Request.Body
                    }
                }

                $form = [PodeForm]::Parse($Content, $WebEvent.ContentType, [System.Text.Encoding]::UTF8)
            } else {
                $Request.ParseFormData()
                $form = $Request.Form
            }

            # set the files/data
            foreach ($file in $form.Files) {
                $Result.Files.Add($file.FileName, $file)
            }

            foreach ($item in $form.Data) {
                if ($item.IsSingular) {
                    $Result.Data.Add($item.Key, $item.Values[0])
                } else {
                    $Result.Data.Add($item.Key, $item.Values)
                }
            }

            $form = $null
        }

        default {
            $Result.Data = $Content
        }
    }

    $Content = $null
    return $Result
}

function Split-PodeContentType {
    param(
        [Parameter()]
        [string]
        $ContentType
    )

    if ([string]::IsNullOrWhiteSpace($ContentType)) {
        return [string]::Empty
    }

    return @($ContentType -isplit ';')[0].Trim()
}

function ConvertFrom-PodeNameValueToHashTable {
    param(
        [Parameter()]
        [System.Collections.Specialized.NameValueCollection]
        $Collection
    )

    if ((Get-PodeCount -Object $Collection) -eq 0) {
        return @{}
    }

    $ht = @{}
    foreach ($key in $Collection.Keys) {
        $htKey = $key
        if (!$key) {
            $htKey = ''
        }

        $ht[$htKey] = $Collection.Get($key)
    }

    return $ht
}

function Get-PodeCount {
    param(
        [Parameter()]
        $Object
    )

    if ($null -eq $Object) {
        return 0
    }

    if ($Object -is [string]) {
        return $Object.Length
    }

    if ($Object -is [System.Collections.Specialized.NameValueCollection] -and $Object.Count -eq 0) {
        return 0
    }

    return $Object.Count
}

function Test-PodePathAccess {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Path
    )

    try {
        $null = Get-Item $Path
    } catch [System.UnauthorizedAccessException] {
        return $false
    }

    return $true
}

function Test-PodePath {
    param(
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

function Test-PodePathIsFile {
    param(
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

function Test-PodePathIsWildcard {
    param(
        [Parameter()]
        [string]
        $Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $false
    }

    return $Path.Contains('*')
}

function Test-PodePathIsDirectory {
    param(
        [Parameter(Mandatory = $true)]
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

function Convert-PodePathSeparators {
    param(
        [Parameter()]
        $Paths
    )

    return @($Paths | ForEach-Object {
            if (![string]::IsNullOrWhiteSpace($_)) {
                $_ -ireplace '[\\/]', [System.IO.Path]::DirectorySeparatorChar
            }
        })
}

function Convert-PodePathPatternToRegex {
    param(
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

function Convert-PodePathPatternsToRegex {
    param(
        [Parameter()]
        [string[]]
        $Paths,

        [switch]
        $NotSlashes,

        [switch]
        $NotStrict
    )

    # replace certain chars
    $Paths = @(foreach ($path in $Paths) {
            if (![string]::IsNullOrEmpty($path)) {
                Convert-PodePathPatternToRegex -Path $path -NotStrict -NotSlashes:$NotSlashes
            }
        })

    # if no paths, return null
    if (($null -eq $Paths) -or ($Paths.Length -eq 0)) {
        return $null
    }

    # join them all together
    $joined = "($($Paths -join '|'))"

    if ($NotStrict) {
        return $joined
    }

    return "^$($joined)$"
}

function Get-PodeDefaultSslProtocols {
    if (Test-PodeIsMacOS) {
        return (ConvertTo-PodeSslProtocols -Protocols Tls12)
    }

    return (ConvertTo-PodeSslProtocols -Protocols Ssl3, Tls12)
}

function ConvertTo-PodeSslProtocols {
    param(
        [Parameter()]
        [ValidateSet('Ssl2', 'Ssl3', 'Tls', 'Tls11', 'Tls12', 'Tls13')]
        [string[]]
        $Protocols
    )

    $protos = 0
    foreach ($protocol in $Protocols) {
        $protos = [int]($protos -bor [System.Security.Authentication.SslProtocols]::$protocol)
    }

    return [System.Security.Authentication.SslProtocols]($protos)
}

function Get-PodeModuleDetails {
    # if there's 1 module imported already, use that
    $importedModule = @(Get-Module -Name Pode)
    if (($importedModule | Measure-Object).Count -eq 1) {
        return (Convert-PodeModuleDetails -Module @($importedModule)[0])
    }

    # if there's none or more, attempt to get the module used for 'engine'
    try {
        $usedModule = (Get-Command -Name 'Set-PodeViewEngine').Module
        if (($usedModule | Measure-Object).Count -eq 1) {
            return (Convert-PodeModuleDetails -Module $usedModule)
        }
    } catch {
    }

    # if there were multiple to begin with, use the newest version
    if (($importedModule | Measure-Object).Count -gt 1) {
        return (Convert-PodeModuleDetails -Module @($importedModule | Sort-Object -Property Version)[-1])
    }

    # otherwise there were none, use the latest installed
    return (Convert-PodeModuleDetails -Module @(Get-Module -ListAvailable -Name Pode | Sort-Object -Property Version)[-1])
}

function Convert-PodeModuleDetails {
    param(
        [Parameter(Mandatory = $true)]
        [psmoduleinfo]
        $Module
    )

    $details = @{
        Name         = $Module.Name
        Path         = $Module.Path
        BasePath     = $Module.ModuleBase
        DataPath     = (Find-PodeModuleFile -Module $Module -CheckVersion)
        InternalPath = $null
        InPath       = (Test-PodeModuleInPath -Module $Module)
    }

    $details.InternalPath = $details.DataPath -ireplace 'Pode\.(ps[md]1)', 'Pode.Internal.$1'
    return $details
}

function Test-PodeModuleInPath {
    param(
        [Parameter(Mandatory = $true)]
        [psmoduleinfo]
        $Module
    )

    $separator = ';'
    if (Test-PodeIsUnix) {
        $separator = ':'
    }

    $paths = @($env:PSModulePath -split $separator)

    foreach ($path in $paths) {
        if ($Module.Path.StartsWith($path)) {
            return $true
        }
    }

    return $false
}

function Get-PodeModuleDependencies {
    param(
        [Parameter(Mandatory = $true)]
        [psmoduleinfo]
        $Module
    )

    if (!$Module.RequiredModules) {
        return $Module
    }

    $mods = @()
    foreach ($mod in $Module.RequiredModules) {
        $mods += (Get-PodeModuleDependencies -Module $mod)
    }

    return ($mods + $module)
}

function Get-PodeModuleRootPath {
    return (Split-Path -Parent -Path $PodeContext.Server.PodeModule.Path)
}

function Get-PodeModuleMiscPath {
    return [System.IO.Path]::Combine((Get-PodeModuleRootPath), 'Misc')
}

function Get-PodeUrl {
    return "$($WebEvent.Endpoint.Protocol)://$($WebEvent.Endpoint.Address)$($WebEvent.Path)"
}

function Find-PodeErrorPage {
    param(
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
    if (!(Test-PodeIsEmpty $PodeContext.Server.Web.ErrorPages.Routes)) {
        # find type by pattern
        $matched = @(foreach ($key in $PodeContext.Server.Web.ErrorPages.Routes.Keys) {
                if ($WebEvent.Path -imatch $key) {
                    $key
                }
            })[0]

        # if we have a match, see if a page exists
        if (!(Test-PodeIsEmpty $matched)) {
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
    if (!(Test-PodeIsEmpty $PodeContext.Server.Web.ErrorPages.Default)) {
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

function Get-PodeErrorPage {
    param(
        [Parameter()]
        [int]
        $Code,

        [Parameter()]
        [string]
        $ContentType
    )

    # parse the passed content type
    $ContentType = Split-PodeContentType -ContentType $ContentType

    # object for the page path
    $path = $null

    # attempt to find a custom error page
    $path = Find-PodeCustomErrorPage -Code $Code -ContentType $ContentType

    # if there's no custom page found, attempt to find an inbuilt page
    if ([string]::IsNullOrWhiteSpace($path)) {
        $podeRoot = Get-PodeModuleMiscPath
        $path = Find-PodeFileForContentType -Path $podeRoot -Name 'default-error-page' -ContentType $ContentType -Engine 'pode'
    }

    # if there's no path found, or it's inaccessible, return null
    if (!(Test-PodePath $path -NoStatus)) {
        return $null
    }

    return $path
}

function Find-PodeCustomErrorPage {
    param(
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

function Find-PodeFileForContentType {
    param(
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
    $files = @(Get-ChildItem -Path ([System.IO.Path]::Combine($Path, "$($Name).*")))

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
    if ($null -ne $files -and $files.Length -gt 0) {
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
    if ($null -ne $engineFiles -and $engineFiles.Length -gt 0) {
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

function Get-PodeRelativePath {
    param(
        [Parameter(Mandatory = $true)]
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
    if ($JoinRoot -and ($Path -match '^\.{1,2}([\\\/]|$)')) {
        if ([string]::IsNullOrWhiteSpace($RootPath)) {
            $RootPath = $PodeContext.Server.Root
        }

        $Path = [System.IO.Path]::Combine($RootPath, $Path)
    }

    # if flagged, resolve the path
    if ($Resolve) {
        $_rawPath = $Path
        $Path = [System.IO.Path]::GetFullPath($Path.Replace('\', '/'))
    }

    # if flagged, test the path and throw error if it doesn't exist
    if ($TestPath -and !(Test-PodePath $Path -NoStatus)) {
        throw "The path does not exist: $(Protect-PodeValue -Value $Path -Default $_rawPath)"
    }

    return $Path
}

function Get-PodeWildcardFiles {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Path,

        [Parameter()]
        [string]
        $Wildcard = '*.*',

        [Parameter()]
        [string]
        $RootPath
    )

    # if the OriginalPath is a directory, add wildcard
    if (Test-PodePathIsDirectory -Path $Path) {
        $Path = [System.IO.Path]::Combine($Path, $Wildcard)
    }

    # if path has a *, assume wildcard
    if (Test-PodePathIsWildcard -Path $Path) {
        $Path = Get-PodeRelativePath -Path $Path -RootPath $RootPath -JoinRoot
        return @((Get-ChildItem $Path -Recurse -Force).FullName)
    }

    return $null
}

function Test-PodeIsServerless {
    param(
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

function Get-PodeEndpointUrl {
    param(
        [Parameter()]
        $Endpoint
    )

    # get the endpoint on which we're currently listening - use first http/https if there are many
    if ($null -eq $Endpoint) {
        $Endpoint = @($PodeContext.Server.Endpoints.Values | Where-Object { $_.Protocol -iin @('http', 'https') -and $_.Default })[0]
        if ($null -eq $Endpoint) {
            $Endpoint = @($PodeContext.Server.Endpoints.Values | Where-Object { $_.Protocol -iin @('http', 'https') })[0]
        }
    }

    $url = $Endpoint.Url
    if ([string]::IsNullOrWhiteSpace($url)) {
        $url = "$($Endpoint.Protocol)://$($Endpoint.FriendlyName):$($Endpoint.Port)"
    }

    return $url
}

function Get-PodeDefaultPort {
    param(
        [Parameter()]
        [ValidateSet('Http', 'Https', 'Smtp', 'Smtps', 'Tcp', 'Tcps', 'Ws', 'Wss')]
        [string]
        $Protocol,

        [Parameter()]
        [ValidateSet('Implicit', 'Explicit')]
        [string]
        $TlsMode = 'Implicit',

        [switch]
        $Real
    )

    # are we after the real default ports?
    if ($Real) {
        return (@{
                Http  = @{ Implicit = 80 }
                Https = @{ Implicit = 443 }
                Smtp  = @{ Implicit = 25 }
                Smtps = @{ Implicit = 465; Explicit = 587 }
                Tcp   = @{ Implicit = 9001 }
                Tcps  = @{ Implicit = 9002; Explicit = 9003 }
                Ws    = @{ Implicit = 80 }
                Wss   = @{ Implicit = 443 }
            })[$Protocol.ToLowerInvariant()][$TlsMode.ToLowerInvariant()]
    }

    # if we running as iis, return the ASPNET port
    if ($PodeContext.Server.IsIIS) {
        return [int]$env:ASPNETCORE_PORT
    }

    # if we running as heroku, return the port
    if ($PodeContext.Server.IsHeroku) {
        return [int]$env:PORT
    }

    # otherwise, get the port for the protocol
    return (@{
            Http  = @{ Implicit = 8080 }
            Https = @{ Implicit = 8443 }
            Smtp  = @{ Implicit = 25 }
            Smtps = @{ Implicit = 465; Explicit = 587 }
            Tcp   = @{ Implicit = 9001 }
            Tcps  = @{ Implicit = 9002; Explicit = 9003 }
            Ws    = @{ Implicit = 9080 }
            Wss   = @{ Implicit = 9443 }
        })[$Protocol.ToLowerInvariant()][$TlsMode.ToLowerInvariant()]
}

function Set-PodeServerHeader {
    param(
        [Parameter()]
        [string]
        $Type,

        [switch]
        $AllowEmptyType
    )

    $name = 'Pode'
    if (![string]::IsNullOrWhiteSpace($Type) -or $AllowEmptyType) {
        $name += " - $($Type)"
    }

    Set-PodeHeader -Name 'Server' -Value $name
}

function Get-PodeHandler {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Service', 'Smtp')]
        [string]
        $Type,

        [Parameter()]
        [string]
        $Name
    )

    if ([string]::IsNullOrWhiteSpace($Name)) {
        return $PodeContext.Server.Handlers[$Type]
    }

    return $PodeContext.Server.Handlers[$Type][$Name]
}

function Convert-PodeFileToScriptBlock {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $FilePath
    )

    # resolve for relative path
    $FilePath = Get-PodeRelativePath -Path $FilePath -JoinRoot

    # if file doesn't exist, error
    if (!(Test-PodePath -Path $FilePath -NoStatus)) {
        throw "The FilePath supplied does not exist: $($FilePath)"
    }

    # if the path is a wildcard or directory, error
    if (!(Test-PodePathIsFile -Path $FilePath -FailOnWildcard)) {
        throw "The FilePath supplied cannot be a wildcard or a directory: $($FilePath)"
    }

    return ([scriptblock](Use-PodeScript -Path $FilePath))
}

function Convert-PodeQueryStringToHashTable {
    param(
        [Parameter()]
        [string]
        $Uri
    )

    if ([string]::IsNullOrWhiteSpace($Uri)) {
        return @{}
    }

    $qmIndex = $Uri.IndexOf('?')
    if ($qmIndex -eq -1) {
        return @{}
    }

    if ($qmIndex -gt 0) {
        $Uri = $Uri.Substring($qmIndex)
    }

    $tmpQuery = [System.Web.HttpUtility]::ParseQueryString($Uri)
    return (ConvertFrom-PodeNameValueToHashTable -Collection $tmpQuery)
}

function Convert-PodeScopedVariables {
    param(
        [Parameter()]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [System.Management.Automation.SessionState]
        $PSSession,

        [Parameter()]
        [ValidateSet('State', 'Session', 'Secret', 'Using')]
        $Skip
    )

    # do nothing if no script
    if ($null -eq $ScriptBlock) {
        if (($null -ne $Skip) -and ($Skip -icontains 'Using')) {
            return $ScriptBlock
        } else {
            return @($ScriptBlock, $null)
        }
    }

    # conversions
    $usingVars = $null
    if (($null -eq $Skip) -or ($Skip -inotcontains 'Using')) {
        $ScriptBlock, $usingVars = Invoke-PodeUsingScriptConversion -ScriptBlock $ScriptBlock -PSSession $PSSession
    }

    if (($null -eq $Skip) -or ($Skip -inotcontains 'State')) {
        $ScriptBlock = Invoke-PodeStateScriptConversion -ScriptBlock $ScriptBlock
    }

    if (($null -eq $Skip) -or ($Skip -inotcontains 'Session')) {
        $ScriptBlock = Invoke-PodeSessionScriptConversion -ScriptBlock $ScriptBlock
    }

    if (($null -eq $Skip) -or ($Skip -inotcontains 'Secret')) {
        $ScriptBlock = Invoke-PodeSecretScriptConversion -ScriptBlock $ScriptBlock
    }

    # return
    if (($null -ne $Skip) -and ($Skip -icontains 'Using')) {
        return $ScriptBlock
    } else {
        return @($ScriptBlock, $usingVars)
    }
}

function Invoke-PodeStateScriptConversion {
    param(
        [Parameter()]
        [scriptblock]
        $ScriptBlock
    )

    # do nothing if no script
    if ($null -eq $ScriptBlock) {
        return $ScriptBlock
    }

    # rename any $state:<name> vars
    $scriptStr = "$($ScriptBlock)"
    $found = $false

    while ($scriptStr -imatch '(?<full>\$state\:(?<name>[a-z0-9_\?]+)\s*=)') {
        $found = $true
        $scriptStr = $scriptStr.Replace($Matches['full'], "Set-PodeState -Name '$($Matches['name'])' -Value ")
    }

    while ($scriptStr -imatch '(?<full>\$state\:(?<name>[a-z0-9_\?]+))') {
        $found = $true
        $scriptStr = $scriptStr.Replace($Matches['full'], "`$PodeContext.Server.State.'$($Matches['name'])'.Value")
    }

    if ($found) {
        $ScriptBlock = [scriptblock]::Create($scriptStr)
    }

    return $ScriptBlock
}

function Invoke-PodeSecretScriptConversion {
    param(
        [Parameter()]
        [scriptblock]
        $ScriptBlock
    )

    # do nothing if no script
    if ($null -eq $ScriptBlock) {
        return $ScriptBlock
    }

    # rename any $secret:<name> vars
    $scriptStr = "$($ScriptBlock)"
    $found = $false

    while ($scriptStr -imatch '(?<full>\$secret\:(?<name>[a-z0-9_\?]+)\s*=)') {
        $found = $true
        $scriptStr = $scriptStr.Replace($Matches['full'], "Update-PodeSecret -Name '$($Matches['name'])' -InputObject ")
    }

    while ($scriptStr -imatch '(?<full>\$secret\:(?<name>[a-z0-9_\?]+))') {
        $found = $true
        $scriptStr = $scriptStr.Replace($Matches['full'], "(Get-PodeSecret -Name '$($Matches['name'])')")
    }

    if ($found) {
        $ScriptBlock = [scriptblock]::Create($scriptStr)
    }

    return $ScriptBlock
}

function Invoke-PodeSessionScriptConversion {
    param(
        [Parameter()]
        [scriptblock]
        $ScriptBlock
    )

    # do nothing if no script
    if ($null -eq $ScriptBlock) {
        return $ScriptBlock
    }

    # rename any $session:<name> vars
    $scriptStr = "$($ScriptBlock)"
    $found = $false

    while ($scriptStr -imatch '(?<full>\$session\:(?<name>[a-z0-9_\?]+))') {
        $found = $true
        $scriptStr = $scriptStr.Replace($Matches['full'], "`$WebEvent.Session.Data.'$($Matches['name'])'")
    }

    if ($found) {
        $ScriptBlock = [scriptblock]::Create($scriptStr)
    }

    return $ScriptBlock
}

function Invoke-PodeUsingScriptConversion {
    param(
        [Parameter()]
        [scriptblock]
        $ScriptBlock,

        [Parameter(Mandatory = $true)]
        [System.Management.Automation.SessionState]
        $PSSession
    )

    # do nothing if no script
    if ($null -eq $ScriptBlock) {
        return @($ScriptBlock, $null)
    }

    # rename any __using_ vars for inner timers, etcs
    $scriptStr = "$($ScriptBlock)"
    $foundInnerUsing = $false

    while ($scriptStr -imatch '(?<full>\$__using_(?<name>[a-z0-9_\?]+))') {
        $foundInnerUsing = $true
        $scriptStr = $scriptStr.Replace($Matches['full'], "`$using:$($Matches['name'])")
    }

    if ($foundInnerUsing) {
        $ScriptBlock = [scriptblock]::Create($scriptStr)
    }

    # get any using variables
    $usingVars = Get-PodeScriptUsingVariables -ScriptBlock $ScriptBlock
    if (Test-PodeIsEmpty $usingVars) {
        return @($ScriptBlock, $null)
    }

    # convert any using vars to use new names
    $usingVars = ConvertTo-PodeUsingVariables -UsingVariables $usingVars -PSSession $PSSession

    # now convert the script
    $newScriptBlock = ConvertTo-PodeUsingScript -ScriptBlock $ScriptBlock -UsingVariables $usingVars

    # return converted script
    return @($newScriptBlock, $usingVars)
}

function Get-PodeScriptUsingVariables {
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]
        $ScriptBlock
    )

    return $ScriptBlock.Ast.FindAll({ $args[0] -is [System.Management.Automation.Language.UsingExpressionAst] }, $true)
}

function ConvertTo-PodeUsingVariables {
    param(
        [Parameter()]
        $UsingVariables,

        [Parameter(Mandatory = $true)]
        [System.Management.Automation.SessionState]
        $PSSession
    )

    if (Test-PodeIsEmpty $UsingVariables) {
        return $null
    }

    $mapped = @{}

    foreach ($usingVar in $UsingVariables) {
        # var name
        $varName = $usingVar.SubExpression.VariablePath.UserPath

        # only retrieve value if new var
        if (!$mapped.ContainsKey($varName)) {
            # get value, or get __using_ value for child scripts
            $value = $PSSession.PSVariable.Get($varName)
            if ([string]::IsNullOrEmpty($value)) {
                $value = $PSSession.PSVariable.Get("__using_$($varName)")
            }

            if ([string]::IsNullOrEmpty($value)) {
                throw "Value for `$using:$($varName) could not be found"
            }

            # add to mapped
            $mapped[$varName] = @{
                OldName           = $usingVar.SubExpression.Extent.Text
                NewName           = "__using_$($varName)"
                NewNameWithDollar = "`$__using_$($varName)"
                SubExpressions    = @()
                Value             = $value.Value
            }
        }

        # add the vars sub-expression for replacing later
        $mapped[$varName].SubExpressions += $usingVar.SubExpression
    }

    return @($mapped.Values)
}

function ConvertTo-PodeUsingScript {
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [hashtable[]]
        $UsingVariables
    )

    # return original script if no using vars
    if (Test-PodeIsEmpty $UsingVariables) {
        return $ScriptBlock
    }

    $varsList = New-Object 'System.Collections.Generic.List`1[System.Management.Automation.Language.VariableExpressionAst]'
    $newParams = New-Object System.Collections.ArrayList

    foreach ($usingVar in $UsingVariables) {
        foreach ($subExp in $usingVar.SubExpressions) {
            $null = $varsList.Add($subExp)
        }
    }

    $newParams.AddRange(@($UsingVariables.NewNameWithDollar))
    $newParams = ($newParams -join ', ')
    $tupleParams = [tuple]::Create($varsList, $newParams)

    $bindingFlags = [System.Reflection.BindingFlags]'Default, NonPublic, Instance'
    $_varReplacerMethod = $ScriptBlock.Ast.GetType().GetMethod('GetWithInputHandlingForInvokeCommandImpl', $bindingFlags)
    $convertedScriptBlockStr = $_varReplacerMethod.Invoke($ScriptBlock.Ast, @($tupleParams))

    if (!$ScriptBlock.Ast.ParamBlock) {
        $convertedScriptBlockStr = "param($($newParams))`n$($convertedScriptBlockStr)"
    }

    $convertedScriptBlock = [scriptblock]::Create($convertedScriptBlockStr)

    if ($convertedScriptBlock.Ast.EndBlock[0].Statements.Extent.Text.StartsWith('$input |')) {
        $convertedScriptBlockStr = ($convertedScriptBlockStr -ireplace '\$input \|')
        $convertedScriptBlock = [scriptblock]::Create($convertedScriptBlockStr)
    }

    return $convertedScriptBlock
}

function Get-PodeDotSourcedFiles {
    param(
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.Language.Ast]
        $Ast,

        [Parameter()]
        [string]
        $RootPath
    )

    # set default root path
    if ([string]::IsNullOrWhiteSpace($RootPath)) {
        $RootPath = $PodeContext.Server.Root
    }

    # get all dot-sourced files
    $cmdTypes = @('dot', 'ampersand')
    $files = ($Ast.FindAll({
        ($args[0] -is [System.Management.Automation.Language.CommandAst]) -and
        ($args[0].InvocationOperator -iin $cmdTypes) -and
        ($args[0].CommandElements.StaticType.Name -ieq 'string')
            }, $false)).CommandElements.Value

    $fileOrder = @()

    # no files found
    if (($null -eq $files) -or ($files.Length -eq 0)) {
        return $fileOrder
    }

    # get any sub sourced files
    foreach ($file in $files) {
        $file = Get-PodeRelativePath -Path $file -RootPath $RootPath -JoinRoot
        $fileOrder += $file

        $ast = Get-PodeAstFromFile -FilePath $file

        $result = Get-PodeDotSourcedFiles -Ast $ast -RootPath (Split-Path -Parent -Path $file)
        if (($null -ne $result) -and ($result.Length -gt 0)) {
            $fileOrder += $result
        }
    }

    # return all found files
    return $fileOrder
}

function Get-PodeAstFromFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $FilePath
    )

    if (!(Test-Path $FilePath)) {
        throw "Path to script file does not exist: $($FilePath)"
    }

    return [System.Management.Automation.Language.Parser]::ParseFile($FilePath, [ref]$null, [ref]$null)
}

function Get-PodeFunctionsFromFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $FilePath
    )

    $ast = Get-PodeAstFromFile -FilePath $FilePath
    return @(Get-PodeFunctionsFromAst -Ast $ast)
}

function Get-PodeFunctionsFromAst {
    param(
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.Language.Ast]
        $Ast
    )

    $funcs = @(($Ast.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false)))

    return @(foreach ($func in $funcs) {
            # skip null
            if ($null -eq $func) {
                continue
            }

            # skip pode funcs
            if ($func.Name -ilike '*-Pode*') {
                continue
            }

            # definition
            $def = "$($func.Body)".Trim('{}').Trim()
            if (($null -ne $func.Parameters) -and ($func.Parameters.Count -gt 0)) {
                $def = "param($($func.Parameters.Name -join ','))`n$($def)"
            }

            # the found func
            @{
                Name       = $func.Name
                Definition = $def
            }
        })
}

function Get-PodeFunctionsFromScriptBlock {
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]
        $ScriptBlock
    )

    # functions that have been found
    $foundFuncs = @()

    # get each function in the callstack
    $callstack = Get-PSCallStack
    if ($callstack.Count -gt 3) {
        $callstack = ($callstack | Select-Object -Skip 4)
        $bindingFlags = [System.Reflection.BindingFlags]'NonPublic, Instance, Static'

        foreach ($call in $callstack) {
            $_funcContext = $call.GetType().GetProperty('FunctionContext', $bindingFlags).GetValue($call, $null)
            $_scriptBlock = $_funcContext.GetType().GetField('_scriptBlock', $bindingFlags).GetValue($_funcContext)
            $foundFuncs += @(Get-PodeFunctionsFromAst -Ast $_scriptBlock.Ast)
        }
    }

    # get each function from the main script
    $foundFuncs += @(Get-PodeFunctionsFromAst -Ast $ScriptBlock.Ast)

    # return the found functions
    return $foundFuncs
}

function Read-PodeWebExceptionDetails {
    param(
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.ErrorRecord]
        $ErrorRecord
    )

    switch ($ErrorRecord) {
        { $_.Exception -is [System.Net.WebException] } {
            $stream = $_.Exception.Response.GetResponseStream()
            $stream.Position = 0

            $body = [System.IO.StreamReader]::new($stream).ReadToEnd()
            $code = [int]$_.Exception.Response.StatusCode
            $desc = $_.Exception.Response.StatusDescription
        }

        { $_.Exception -is [System.Net.Http.HttpRequestException] } {
            $body = $_.ErrorDetails.Message
            $code = [int]$_.Exception.Response.StatusCode
            $desc = $_.Exception.Response.ReasonPhrase
        }

        default {
            throw "Exception is of an invalid type, should be either WebException or HttpRequestException, but got: $($_.Exception.GetType().Name)"
        }
    }

    return @{
        Status = @{
            Code        = $code
            Description = $desc
        }
        Body   = $body
    }
}

function Use-PodeFolder {
    param(
        [Parameter()]
        [string]
        $Path,

        [Parameter(Mandatory = $true)]
        [string]
        $DefaultPath
    )

    # use default, or custom path
    if ([string]::IsNullOrWhiteSpace($Path)) {
        $Path = Join-PodeServerRoot -Folder $DefaultPath
    } else {
        $Path = Get-PodeRelativePath -Path $Path -JoinRoot
    }

    # fail if path not found
    if (!(Test-PodePath -Path $Path -NoStatus)) {
        throw "Path to load $($DefaultPath) not found: $($Path)"
    }

    # get .ps1 files and load them
    Get-ChildItem -Path $Path -Filter *.ps1 -Force -Recurse | ForEach-Object {
        Use-PodeScript -Path $_.FullName
    }
}

function Find-PodeModuleFile {
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'Name')]
        [string]
        $Name,

        [Parameter(Mandatory = $true, ParameterSetName = 'Module')]
        [psmoduleinfo]
        $Module,

        [switch]
        $ListAvailable,

        [switch]
        $DataOnly,

        [switch]
        $CheckVersion
    )

    # get module and check psd1, then psm1
    if ($null -eq $Module) {
        $Module = (Get-Module -Name $Name -ListAvailable:$ListAvailable | Sort-Object -Property Version -Descending | Select-Object -First 1)
    }

    # if the path isn't already a psd1 do this
    $path = Join-Path $Module.ModuleBase "$($Module.Name).psd1"
    if (!(Test-Path $path)) {
        # if we only want a psd1, return null
        if ($DataOnly) {
            $path = $null
        } else {
            $path = $Module.Path
        }
    }

    # check the Version of the psd1
    elseif ($CheckVersion) {
        $data = Import-PowerShellDataFile -Path $path -ErrorAction Stop

        $version = $null
        if (![version]::TryParse($data.ModuleVersion, [ref]$version)) {
            if ($DataOnly) {
                $path = $null
            } else {
                $path = $Module.Path
            }
        }
    }

    return $path
}

function Get-PodeScriptblockArguments {
    param(
        [Parameter()]
        [object[]]
        $ArgumentList,

        [Parameter()]
        [object[]]
        $UsingVariables
    )

    if ($null -eq $ArgumentList) {
        $ArgumentList = @()
    }

    if (($null -eq $UsingVariables) -or ($UsingVariables.Length -le 0)) {
        return $ArgumentList
    }

    $_vars = @()
    foreach ($_var in $UsingVariables) {
        $_vars += , $_var.Value
    }

    return ($_vars + $ArgumentList)
}

function Clear-PodeHashtableInnerKeys {
    param(
        [Parameter(ValueFromPipeline = $true)]
        [hashtable]
        $InputObject
    )

    if (Test-PodeIsEmpty $InputObject) {
        return
    }

    $InputObject.Keys.Clone() | ForEach-Object {
        $InputObject[$_].Clear()
    }
}

function Set-PodeCronInterval {
    param(
        [Parameter()]
        [hashtable]
        $Cron,

        [Parameter()]
        [string]
        $Type,

        [Parameter()]
        [int[]]
        $Value,

        [Parameter()]
        [int]
        $Interval
    )

    if ($Interval -le 0) {
        return $false
    }

    if ($Value.Length -gt 1) {
        throw "You can only supply a single $($Type) value when using intervals"
    }

    if ($Value.Length -eq 1) {
        $Cron[$Type] = "$(@($Value)[0])"
    }

    $Cron[$Type] += "/$($Interval)"
    return ($Value.Length -eq 1)
}

function Test-PodeModuleInstalled {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    return ($null -ne (Get-Module -Name $Name -ListAvailable -ErrorAction Ignore -Verbose:$false))
}

function Get-PodePlaceholderRegex {
    return '\:(?<tag>[\w]+)'
}

function Resolve-PodePlaceholders {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Path,

        [Parameter()]
        [string]
        $Pattern,

        [Parameter()]
        [string]
        $Prepend = '(?<',

        [Parameter()]
        [string]
        $Append = '>[^\/]+?)',

        [switch]
        $Slashes
    )

    if ([string]::IsNullOrWhiteSpace($Pattern)) {
        $Pattern = Get-PodePlaceholderRegex
    }

    if ($Path -imatch $Pattern) {
        $Path = [regex]::Escape($Path)
    }

    if ($Slashes) {
        $Path = ($Path.TrimEnd('\/') -replace '(\\\\|\/)', '[\\\/]')
        $Path = "$($Path)[\\\/]"
    }

    return (Convert-PodePlaceholders -Path $Path -Pattern $Pattern -Prepend $Prepend -Append $Append)
}

function Convert-PodePlaceholders {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Path,

        [Parameter()]
        [string]
        $Pattern,

        [Parameter()]
        [string]
        $Prepend = '(?<',

        [Parameter()]
        [string]
        $Append = '>[^\/]+?)'
    )

    if ([string]::IsNullOrWhiteSpace($Pattern)) {
        $Pattern = Get-PodePlaceholderRegex
    }

    while ($Path -imatch $Pattern) {
        $Path = ($Path -ireplace $Matches[0], "$($Prepend)$($Matches['tag'])$($Append)")
    }

    return $Path
}

function Test-PodePlaceholders {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Path,

        [Parameter()]
        [string]
        $Placeholder
    )

    if ([string]::IsNullOrWhiteSpace($Placeholder)) {
        $Placeholder = Get-PodePlaceholderRegex
    }

    return ($Path -imatch $Placeholder)
}

<#
.SYNOPSIS
creates a YAML description of the data in the object - based on https://github.com/Phil-Factor/PSYaml
.DESCRIPTION
This produces YAML from any object you pass to it. It isn't suitable for the huge objects produced by some of the cmdlets such as Get-Process, but fine for simple objects
.PARAMETER Object
the object that you want scripted out
.PARAMETER Depth
The depth that you want your object scripted to
.EXAMPLE
Get-PodeOpenApiDefinition|ConvertTo-PodeYaml
#>

function ConvertTo-PodeYaml {
    [OutputType('System.String')]

    [CmdletBinding()]
    param (
        [parameter(Position = 0, Mandatory = $true, ValueFromPipeline = $true)]
        [AllowNull()]
        $InputObject,
        [parameter() ]
        [int]$Depth = 16
    )

    if ($null -eq $PodeContext.Server.Cache.YamlModuleImported) {
        $PodeContext.Server.Cache.YamlModuleImported = ((Test-PodeModuleInstalled -Name 'PSYaml') -or (Test-PodeModuleInstalled -Name 'powershell-yaml'))
    }

    if ($PodeContext.Server.YamlModuleImported) {
        return ($InputObject | ConvertTo-Yaml)
    } else {
        return ConvertTo-PodeYamlInternal -InputObject $InputObject -Depth $Depth -NoNewLine
    }
}

function ConvertTo-PodeYamlInternal {

    [OutputType('System.String')]

    [CmdletBinding()]
    param (
        [parameter(  Mandatory = $true, ValueFromPipeline = $true)]
        [AllowNull()]
        $InputObject,

        [parameter()]
        [int]
        $Depth = 10,

        [parameter()]
        [int]
        $NestingLevel = 0,

        [parameter()]
        [switch]
        $NoNewLine
    )

    # if it is null return null
    If ( !($InputObject) ) {
        if ($InputObject -is [Object[]]) {
            return '[]'
        } else {
            return ''
        }
    }

    $padding = [string]::new(' ', $NestingLevel * 2) # lets just create our left-padding for the block
    try {
        $Type = $InputObject.GetType().Name # we start by getting the object's type
        if ($InputObject -is [object[]]) {
            #what it really is
            $Type = "$($InputObject.GetType().BaseType.Name)"
        }

        #report the leaves in terms of object type
        if ($Depth -ilt $NestingLevel) {
            $Type = 'OutOfDepth'
        }
        # prevent these values being identified as an object
        if ($InputObject -is [System.Collections.Specialized.OrderedDictionary]) {
            $Type = 'HashTable'
        } elseif ($Type -ieq 'List`1') {
            $Type = 'Array'
        } elseif ($InputObject -is [array]) {
            $Type = 'Array'
        } # whatever it thinks it is called
        elseif ($InputObject -is [hashtable]) {
            $Type = 'HashTable'
        } # for our purposes it is a hashtable

        $output += switch ($Type.ToLower()) { 
            'string' {
                $String = "$InputObject"
                if (($string -match '[\r\n]' -or $string.Length -gt 80) -and ($string -inotcontains 'http')) {
                    $folded = [System.Text.StringBuilder]::new(">`n") # signal that we are going to use the readable 'newlines-folded' format
                    foreach ($item in $string.Split("`n")) {
                        $workingString = $item -replace '\r$'
                        $length = $item.Length
                        $IndexIntoString = 0
                        $wrap = 80
                        while ($length -gt $IndexIntoString + $Wrap) {
                            $BreakPoint = $wrap
                            $earliest = $workingString.Substring($IndexIntoString, $wrap).LastIndexOf(' ')
                            $latest = $workingString.Substring($IndexIntoString + $wrap).IndexOf(' ')
                            if (($earliest -eq -1) -or ($latest -eq -1)) {
                                $BreakPoint = $wrap
                            } elseif ($wrap - $earliest -lt ($latest)) {
                                $BreakPoint = $earliest
                            } else {
                                $BreakPoint = $wrap + $latest
                            }
                            if (($wrap - $earliest) + $latest -gt 30) {
                                $BreakPoint = $wrap # in case it is a string without spaces
                            }

                            [void] $folded.Append( $padding).AppendLine( $workingString.Substring($IndexIntoString, $BreakPoint).Trim())
                            $IndexIntoString += $BreakPoint
                        }
                        if ($IndexIntoString -lt $length) {
                            [void] $folded.Append( $padding).AppendLine( $workingString.Substring($IndexIntoString).Trim())
                        } else {
                            [void] $folded.AppendLine()
                        }
                    }
                    $folded.ToString()
                    break
                } else {
                    if ($string.StartsWith('#')) {
                        "'$($string -replace '''', '''''')'"
                    } else {
                        $string
                    }
                    break
                }
                break
            }
            'hashtable' {
                if ($InputObject.Count -gt 0 ) {
                    $index = 0
                    <#   foreach ($item in $InputObject.Keys) {
                        if ($InputObject[$item] -is [string]) { $increment = 2 } else { $increment = 1 }
                        if ($NoNewLine -and $index++ -eq 0) { $NewPadding = '' } else { $NewPadding = "`n$padding" }
                        $ht = (ConvertTo-PodeYamlInternal -InputObject $InputObject[$item] -Depth $Depth -NestingLevel ($NestingLevel + $increment))
                        "$NewPadding$($item): $ht"
                    }#>
                    ("$($InputObject.GetEnumerator() | ForEach-Object {
                        if ($_.Value.GetType().Name -eq 'String'){$increment=2} else {$Increment=1}
                        if ($NoNewLine -and $index++ -eq 0){$NewPadding=''} else {$NewPadding="`n$padding"}
                        "$NewPadding$($_.Name): " +
                            (ConvertTo-PodeYamlInternal -InputObject $_.Value -depth $Depth -NestingLevel ($NestingLevel + $increment))
                            })")
                } else { '{}' }
                break
            }
            'boolean' {
                if ($InputObject -eq $true) { 'true' } else { 'false' }
                break
            }
            'array' {
                "$($InputObject | ForEach-Object {
                    "`n$padding- $(ConvertTo-PodeYamlInternal -InputObject $_ -depth $Depth -NestingLevel ($NestingLevel + 1) -NoNewLine)" })"
                break
            }
            default {
                "'$InputObject'"
            }
        }
        return $Output
    } catch {
        $_ | Write-PodeErrorLog
        $_.Exception | Write-PodeErrorLog -CheckInnerException
        throw "Error'$($_)' in script $($_.InvocationInfo.ScriptName) $($_.InvocationInfo.Line.Trim()) (line $($_.InvocationInfo.ScriptLineNumber)) char $($_.InvocationInfo.OffsetInLine) executing $($_.InvocationInfo.MyCommand) on $type object '$($InputObject)' Class: $($InputObject.GetType().Name) BaseClass: $($InputObject.GetType().BaseType.Name) "
    }
}