<#
.SYNOPSIS
Starts a Pode Server with the supplied ScriptBlock.

.DESCRIPTION
Starts a Pode Server with the supplied ScriptBlock.

.PARAMETER ScriptBlock
The main logic for the Server.

.PARAMETER FilePath
A literal, or relative, path to a file containing a ScriptBlock for the Server's logic.
The directory of this file will be used as the Server's root path - unless a specific -RootPath is supplied.

.PARAMETER Interval
For 'Service' type Servers, will invoke the ScriptBlock every X seconds.

.PARAMETER Name
An optional name for the Server (intended for future ideas).

.PARAMETER Threads
The numbers of threads to use for Web and TCP servers.

.PARAMETER RootPath
An override for the Server's root path.

.PARAMETER Request
Intended for Serverless environments, this is Requests details that Pode can parse and use.

.PARAMETER Type
The server type, to define how Pode should run and deal with incoming Requests.

.PARAMETER DisableTermination
Disables the ability to terminate the Server.

.PARAMETER Browse
Open the web Server's default endpoint in your defualt browser.

.PARAMETER CurrentPath
Sets the Server's root path to be the current working path - for -FilePath only.

.EXAMPLE
Start-PodeServer { /* logic */ }

.EXAMPLE
Start-PodeServer -Interval 10 { /* logic */ }

.EXAMPLE
Start-PodeServer -Request $LambdaInput -Type 'AwsLambda' { /* logic */ }
#>
function Start-PodeServer
{
    [CmdletBinding(DefaultParameterSetName='Script')]
    param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true, Position=0, ParameterSetName='Script')]
        [scriptblock]
        $ScriptBlock,

        [Parameter(Mandatory=$true, ParameterSetName='File')]
        [string]
        $FilePath,

        [Parameter()]
        [int]
        $Interval = 0,

        [Parameter()]
        [string]
        $Name,

        [Parameter()]
        [int]
        $Threads = 1,

        [Parameter()]
        [string]
        $RootPath,

        [Parameter()]
        $Request,

        [Parameter()]
        [ValidateSet('', 'AzureFunctions', 'AwsLambda', 'Pode')]
        [string]
        $Type = [string]::Empty,

        [switch]
        $DisableTermination,

        [switch]
        $Browse,

        [Parameter(ParameterSetName='File')]
        [switch]
        $CurrentPath
    )

    # ensure the session is clean
    $PodeContext = $null
    $ShowDoneMessage = $true

    try {
        # if we have a filepath, resolve it - and extract a root path from it
        if ($PSCmdlet.ParameterSetName -ieq 'file') {
            $FilePath = Get-PodeRelativePath -Path $FilePath -Resolve -TestPath

            # if not already supplied, set root path
            if ([string]::IsNullOrWhiteSpace($RootPath)) {
                if ($CurrentPath) {
                    $RootPath = $PWD.Path
                }
                else {
                    $RootPath = Split-Path -Parent -Path $FilePath
                }
            }
        }

        # configure the server's root path
        if (!(Test-IsEmpty $RootPath)) {
            $RootPath = Get-PodeRelativePath -Path $RootPath -RootPath $MyInvocation.PSScriptRoot -JoinRoot -Resolve -TestPath
        }

        # create main context object
        $PodeContext = New-PodeContext `
            -ScriptBlock $ScriptBlock `
            -FilePath $FilePath `
            -Threads $Threads `
            -Interval $Interval `
            -ServerRoot (Protect-PodeValue -Value $RootPath -Default $MyInvocation.PSScriptRoot) `
            -ServerType $Type

        # set it so ctrl-c can terminate, unless serverless
        if (!$PodeContext.Server.IsServerless) {
            [Console]::TreatControlCAsInput = $true
        }

        # start the file monitor for interally restarting
        Start-PodeFileMonitor

        # start the server
        Start-PodeInternalServer -Request $Request -Browse:$Browse

        # at this point, if it's just a one-one off script, return
        if ([string]::IsNullOrWhiteSpace($PodeContext.Server.Type) -or $PodeContext.Server.IsServerless) {
            return
        }

        # sit here waiting for termination/cancellation, or to restart the server
        while (!(Test-PodeTerminationPressed -Key $key) -and !($PodeContext.Tokens.Cancellation.IsCancellationRequested)) {
            Start-Sleep -Seconds 1

            # get the next key presses
            $key = Get-PodeConsoleKey

            # check for internal restart
            if (($PodeContext.Tokens.Restart.IsCancellationRequested) -or (Test-PodeRestartPressed -Key $key)) {
                Restart-PodeInternalServer
            }
        }

        Write-Host 'Terminating...' -NoNewline -ForegroundColor Yellow
        $PodeContext.Tokens.Cancellation.Cancel()
    }
    catch {
        $ShowDoneMessage = $false
        throw
    }
    finally {
        # clean the runspaces and tokens
        Close-PodeServer -ShowDoneMessage:$ShowDoneMessage

        # clean the session
        $PodeContext = $null
    }
}

<#
.SYNOPSIS
The CLI for Pode, to initialise, build and start your Server.

.DESCRIPTION
The CLI for Pode, to initialise, build and start your Server.

.PARAMETER Action
The action to invoke on your Server.

.PARAMETER Dev
Supply when running "pode install", this will install any dev packages defined in your package.json.

.EXAMPLE
pode install -dev

.EXAMPLE
pode build

.EXAMPLE
pode start
#>
function Pode
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet('init', 'test', 'start', 'install', 'build')]
        [Alias('a')]
        [string]
        $Action,

        [switch]
        [Alias('d')]
        $Dev
    )

    # default config file name and content
    $file = './package.json'
    $name = Split-Path -Leaf -Path $pwd
    $data = $null

    # default config data that's used to populate on init
    $map = @{
        'name' = $name;
        'version' = '1.0.0';
        'description' = '';
        'main' = './server.ps1';
        'scripts' = @{
            'start' = './server.ps1';
            'install' = 'yarn install --force --ignore-scripts --modules-folder pode_modules';
            "build" = 'psake';
            'test' = 'invoke-pester ./tests/*.ps1'
        };
        'author' = '';
        'license' = 'MIT';
    }

    # check and load config if already exists
    if (Test-Path $file) {
        $data = (Get-Content $file | ConvertFrom-Json)
    }

    # quick check to see if the data is required
    if ($Action -ine 'init') {
        if ($null -eq $data) {
            Write-Host 'package.json file not found' -ForegroundColor Red
            return
        }
        else {
            $actionScript = $data.scripts.$Action

            if ([string]::IsNullOrWhiteSpace($actionScript) -and $Action -ieq 'start') {
                $actionScript = $data.main
            }

            if ([string]::IsNullOrWhiteSpace($actionScript) -and $Action -ine 'install') {
                Write-Host "package.json does not contain a script for the $($Action) action" -ForegroundColor Yellow
                return
            }
        }
    }
    else {
        if ($null -ne $data) {
            Write-Host 'package.json already exists' -ForegroundColor Yellow
            return
        }
    }

    switch ($Action.ToLowerInvariant())
    {
        'init' {
            $v = Read-Host -Prompt "name ($($map.name))"
            if (![string]::IsNullOrWhiteSpace($v)) { $map.name = $v }

            $v = Read-Host -Prompt "version ($($map.version))"
            if (![string]::IsNullOrWhiteSpace($v)) { $map.version = $v }

            $map.description = Read-Host -Prompt "description"

            $v = Read-Host -Prompt "entry point ($($map.main))"
            if (![string]::IsNullOrWhiteSpace($v)) { $map.main = $v; $map.scripts.start = $v }

            $map.author = Read-Host -Prompt "author"

            $v = Read-Host -Prompt "license ($($map.license))"
            if (![string]::IsNullOrWhiteSpace($v)) { $map.license = $v }

            $map | ConvertTo-Json -Depth 10 | Out-File -FilePath $file -Encoding utf8 -Force
            Write-Host 'Success, saved package.json' -ForegroundColor Green
        }

        'test' {
            Invoke-PodePackageScript -ActionScript $actionScript
        }

        'start' {
            Invoke-PodePackageScript -ActionScript $actionScript
        }

        'install' {
            if ($Dev) {
                Install-PodeLocalModules -Modules $data.devModules
            }

            Install-PodeLocalModules -Modules $data.modules
            Invoke-PodePackageScript -ActionScript $actionScript
        }

        'build' {
            Invoke-PodePackageScript -ActionScript $actionScript
        }
    }
}

<#
.SYNOPSIS
Opens a Web Server up as a Desktop Application.

.DESCRIPTION
Opens a Web Server up as a Desktop Application.

.PARAMETER Title
The title of the Application's window.

.PARAMETER Icon
A path to an icon image for the Application.

.PARAMETER WindowState
The state the Application's window starts, such as Minimized.

.PARAMETER WindowStyle
The border style of the Application's window.

.PARAMETER ResizeMode
Specifies if the Application's window is resizable.

.PARAMETER Height
The height of the window.

.PARAMETER Width
The width of the window.

.PARAMETER EndpointName
The specific endpoint name to use, if you are listening on multiple endpoints.

.PARAMETER HideFromTaskbar
Stops the Application from appearing on the taskbar.

.EXAMPLE
Show-PodeGui -Title 'MyApplication' -WindowState 'Maximized'
#>
function Show-PodeGui
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [string]
        $Title,

        [Parameter()]
        [string]
        $Icon,

        [Parameter()]
        [ValidateSet('Normal', 'Maximized', 'Minimized')]
        [string]
        $WindowState = 'Normal',

        [Parameter()]
        [ValidateSet('None', 'SingleBorderWindow', 'ThreeDBorderWindow', 'ToolWindow')]
        [string]
        $WindowStyle = 'SingleBorderWindow',

        [Parameter()]
        [ValidateSet('CanResize', 'CanMinimize', 'NoResize')]
        [string]
        $ResizeMode = 'CanResize',

        [Parameter()]
        [int]
        $Height = 0,

        [Parameter()]
        [int]
        $Width = 0,

        [Parameter()]
        [string]
        $EndpointName,

        [switch]
        $HideFromTaskbar
    )

    # error if serverless
    Test-PodeIsServerless -FunctionName 'Show-PodeGui' -ThrowError

    # only valid for Windows PowerShell
    if ((Test-IsPSCore) -and ($PSVersionTable.PSVersion.Major -eq 6)) {
        throw 'Show-PodeGui is currently only available for Windows PowerShell, and PowerShell 7 on Windows'
    }

    # enable the gui and set general settings
    $PodeContext.Server.Gui.Enabled = $true
    $PodeContext.Server.Gui.Title = $Title
    $PodeContext.Server.Gui.ShowInTaskbar = !$HideFromTaskbar
    $PodeContext.Server.Gui.WindowState = $WindowState
    $PodeContext.Server.Gui.WindowStyle = $WindowStyle
    $PodeContext.Server.Gui.ResizeMode = $ResizeMode

    # set the window's icon path
    if (![string]::IsNullOrWhiteSpace($Icon)) {
        $PodeContext.Server.Gui.Icon = (Resolve-Path $Icon).Path
        if (!(Test-Path $PodeContext.Server.Gui.Icon)) {
            throw "Path to icon for GUI does not exist: $($PodeContext.Server.Gui.Icon)"
        }
    }

    # set the height of the window
    $PodeContext.Server.Gui.Height = $Height
    if ($PodeContext.Server.Gui.Height -le 0) {
        $PodeContext.Server.Gui.Height = 'auto'
    }

    # set the width of the window
    $PodeContext.Server.Gui.Width = $Width
    if ($PodeContext.Server.Gui.Width -le 0) {
        $PodeContext.Server.Gui.Width = 'auto'
    }

    # set the gui to use a specific listener
    $PodeContext.Server.Gui.EndpointName = $EndpointName

    if (![string]::IsNullOrWhiteSpace($PodeContext.Server.Gui.EndpointName)) {
        $found = ($PodeContext.Server.Endpoints | Where-Object {
            $_.Name -eq $PodeContext.Server.Gui.EndpointName
        } | Select-Object -First 1)

        if ($null -eq $found) {
            throw "Endpoint with name '$($EndpointName)' does not exist"
        }

        $PodeContext.Server.Gui.Endpoint = $found
    }
}

<#
.SYNOPSIS
Bind an endpoint to listen for incoming Requests.

.DESCRIPTION
Bind an endpoint to listen for incoming Requests. The endpoints can be HTTP, HTTPS, TCP or SMTP, with the option to bind certificates.

.PARAMETER Address
The IP/Hostname of the endpoint.

.PARAMETER Port
The Port number of the endpoint.

.PARAMETER Protocol
The protocol of the supplied endpoint.

.PARAMETER Certificate
A certificate name to find and bind onto HTTPS endpoints (Windows only).

.PARAMETER CertificateThumbprint
A certificate thumbprint to bind onto HTTPS endpoints (Windows only).

.PARAMETER CertificateFile
The path to a certificate that can be use to enable HTTPS (Cross-platform)

.PARAMETER CertificatePassword
The password for the certificate referenced in CertificateFile (Cross-platform)

.PARAMETER RawCertificate
The raw X509 certificate that can be use to enable HTTPS (Cross-platform)

.PARAMETER Name
An optional name for the endpoint, that can be used with other functions.

.PARAMETER RedirectTo
The Name of another Endpoint to automatically generate a redirect route for all traffic.

.PARAMETER Force
Ignore Adminstrator checks for non-localhost endpoints.

.PARAMETER SelfSigned
Create and bind a self-signed certifcate onto HTTPS endpoints (Windows only).

.EXAMPLE
Add-PodeEndpoint -Address localhost -Port 8090 -Protocol Http

.EXAMPLE
Add-PodeEndpoint -Address localhost -Protocol Smtp

.EXAMPLE
Add-PodeEndpoint -Address dev.pode.com -Port 8443 -Protocol Https -SelfSigned

.EXAMPLE
Add-PodeEndpoint -Address live.pode.com -Protocol Https -CertificateThumbprint '2A9467F7D3940243D6C07DE61E7FCCE292'
#>
function Add-PodeEndpoint
{
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $Address = 'localhost',

        [Parameter()]
        [int]
        $Port = 0,

        [Parameter()]
        [ValidateSet('Http', 'Https', 'Smtp', 'Tcp', 'Ws', 'Wss')]
        [string]
        $Protocol,

        [Parameter(Mandatory=$true, ParameterSetName='CertName')]
        [string]
        $Certificate = $null,

        [Parameter(Mandatory=$true, ParameterSetName='CertThumb')]
        [string]
        $CertificateThumbprint = $null,

        [Parameter(Mandatory=$true, ParameterSetName='CertFile')]
        [string]
        $CertificateFile = $null,

        [Parameter(ParameterSetName='CertFile')]
        [string]
        $CertificatePassword = $null,

        [Parameter(Mandatory=$true, ParameterSetName='CertRaw')]
        [Parameter()]
        [X509Certificate]
        $RawCertificate = $null,

        [Parameter()]
        [string]
        $Name = $null,

        [Parameter()]
        [string]
        $RedirectTo = $null,

        [switch]
        $Force,

        [Parameter(ParameterSetName='CertSelf')]
        [switch]
        $SelfSigned
    )

    # error if serverless
    Test-PodeIsServerless -FunctionName 'Add-PodeEndpoint' -ThrowError

    # parse the endpoint for host/port info
    $FullAddress = "$($Address):$($Port)"
    $_endpoint = Get-PodeEndpointInfo -Endpoint $FullAddress

    # if a name was supplied, check it is unique
    if (!(Test-IsEmpty $Name) -and
        (Get-PodeCount ($PodeContext.Server.Endpoints | Where-Object { $_.Name -eq $Name })) -ne 0)
    {
        throw "An endpoint with the name '$($Name)' has already been defined"
    }

    # new endpoint object
    $obj = @{
        Name = $Name
        Address = $null
        RawAddress = $FullAddress
        Port = $null
        IsIPAddress = $true
        HostName = 'localhost'
        Ssl = (@('https', 'wss') -icontains $Protocol)
        Protocol = $Protocol
        Certificate = @{
            Name = $Certificate
            Thumbprint = $CertificateThumbprint
            Raw = $RawCertificate
            SelfSigned = $SelfSigned
        }
    }

    # set the ip for the context
    $obj.Address = (Get-PodeIPAddress $_endpoint.Host)
    if (!(Test-PodeIPAddressLocalOrAny -IP $obj.Address)) {
        $obj.HostName = "$($obj.Address)"
    }

    $obj.IsIPAddress = (Test-PodeIPAddress -IP $obj.Address -IPOnly)

    # set the port for the context
    $obj.Port = $_endpoint.Port

    # if the address is non-local, then check admin privileges
    if (!$Force -and !(Test-PodeIPAddressLocal -IP $obj.Address) -and !(Test-IsAdminUser)) {
        throw 'Must be running with administrator priviledges to listen on non-localhost addresses'
    }

    # has this endpoint been added before? (for http/https we can just not add it again)
    $exists = ($PodeContext.Server.Endpoints | Where-Object {
        ($_.Address -eq $obj.Address) -and ($_.Port -eq $obj.Port) -and ($_.Ssl -eq $obj.Ssl)
    } | Measure-Object).Count

    # if we're dealing with a certificate file, attempt to import it
    if ($PSCmdlet.ParameterSetName -ieq 'certfile') {
        # fail if protocol is not https
        if (@('https', 'wss') -inotcontains $Protocol) {
            throw "Certificate supplied for non-HTTPS/WSS endpoint"
        }

        $_path = Get-PodeRelativePath -Path $CertificateFile -JoinRoot -Resolve

        if ([string]::IsNullOrWhiteSpace($CertificatePassword)) {
            $obj.Certificate.Raw = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($_path)
        }
        else {
            $obj.Certificate.Raw = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($_path, $CertificatePassword)
        }

        # fail if the cert is expired
        if ($obj.Certificate.Raw.NotAfter -lt [datetime]::Now) {
            throw "The certificate '$($CertificateFile)' has expired: $($obj.Certificate.Raw.NotAfter)"
        }
    }

    if (!$exists) {
        # has an endpoint already been defined for smtp/tcp?
        if ((@('smtp', 'tcp') -icontains $Protocol) -and ($Protocol -ieq $PodeContext.Server.Type)) {
            throw "An endpoint for $($Protocol.ToUpperInvariant()) has already been defined"
        }

        # set server type, ensure we aren't trying to change the server's type
        if (@('ws', 'wss') -icontains $Protocol) {
            $PodeContext.Server.WebSockets.Enabled = $true
        }
        else {
            $_type = (Resolve-PodeValue -Check ($Protocol -ieq 'https') -TrueValue 'http' -FalseValue $Protocol)
            if (($_type -ieq 'http') -and ($PodeContext.Server.Type -ieq 'pode')) {
                $_type = 'pode'
            }

            if ([string]::IsNullOrWhiteSpace($PodeContext.Server.Type)) {
                $PodeContext.Server.Type = $_type
            }
            elseif ($PodeContext.Server.Type -ine $_type) {
                throw "Cannot add $($Protocol.ToUpperInvariant()) endpoint when already listening to $($PodeContext.Server.Type.ToUpperInvariant()) endpoints"
            }
        }

        # add the new endpoint
        $PodeContext.Server.Endpoints += $obj
    }

    # if RedirectTo is set, attempt to build a redirecting route
    if (![string]::IsNullOrWhiteSpace($RedirectTo)) {
        $redir_endpoint = ($PodeContext.Server.Endpoints | Where-Object { $_.Name -eq $RedirectTo } | Select-Object -First 1)

        # ensure the name exists
        if (Test-IsEmpty $redir_endpoint) {
            throw "An endpoint with the name '$($RedirectTo)' has not been defined for redirecting"
        }

        # build the redirect route
        Add-PodeRoute -Method * -Path * -Endpoint $obj.RawAddress -Protocol $obj.Protocol -ArgumentList $redir_endpoint -ScriptBlock {
            param($e, $endpoint)

            $addr = Resolve-PodeValue -Check (Test-PodeIPAddressAny -IP $endpoint.Address) -TrueValue 'localhost' -FalseValue $endpoint.Address
            Move-PodeResponseUrl -Address $addr -Port $endpoint.Port -Protocol $endpoint.Protocol
        }
    }
}

<#
.SYNOPSIS
Adds a new Timer with logic to periodically invoke.

.DESCRIPTION
Adds a new Timer with logic to periodically invoke, with options to only run a specific number of times.

.PARAMETER Name
The Name of the Timer.

.PARAMETER Interval
The number of seconds to periodically invoke the Timer's ScriptBlock.

.PARAMETER ScriptBlock
The script for the Timer.

.PARAMETER Limit
The number of times the Timer should be invoked before being removed. (If 0, it will run indefinitely)

.PARAMETER Skip
The number of "invokes" to skip before the Timer actually runs.

.PARAMETER ArgumentList
An array of arguments to supply to the Timer's ScriptBlock.

.PARAMETER FilePath
A literal, or relative, path to a file containing a ScriptBlock for the Timer's logic.

.PARAMETER OnStart
If supplied, the timer will trigger when the server starts.

.EXAMPLE
Add-PodeTimer -Name 'Hello' -Interval 10 -ScriptBlock { 'Hello, world!' | Out-Default }

.EXAMPLE
Add-PodeTimer -Name 'RunOnce' -Interval 1 -Limit 1 -ScriptBlock { /* logic */ }

.EXAMPLE
Add-PodeTimer -Name 'RunAfter60secs' -Interval 10 -Skip 6 -ScriptBlock { /* logic */ }

.EXAMPLE
Add-PodeTimer -Name 'Args' -Interval 2 -ScriptBlock { /* logic */ } -ArgumentList 'arg1', 'arg2'
#>
function Add-PodeTimer
{
    [CmdletBinding(DefaultParameterSetName='Script')]
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Name,

        [Parameter(Mandatory=$true)]
        [int]
        $Interval,

        [Parameter(Mandatory=$true, ParameterSetName='Script')]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [int]
        $Limit = 0,

        [Parameter()]
        [int]
        $Skip = 0,

        [Parameter(Mandatory=$true, ParameterSetName='File')]
        [string]
        $FilePath,

        [Parameter()]
        [object[]]
        $ArgumentList,

        [switch]
        $OnStart
    )

    # error if serverless
    Test-PodeIsServerless -FunctionName 'Add-PodeTimer' -ThrowError

    # ensure the timer doesn't already exist
    if ($PodeContext.Timers.ContainsKey($Name)) {
        throw "[Timer] $($Name): Timer already defined"
    }

    # is the interval valid?
    if ($Interval -le 0) {
        throw "[Timer] $($Name): Interval must be greater than 0"
    }

    # is the limit valid?
    if ($Limit -lt 0) {
        throw "[Timer] $($Name): Cannot have a negative limit"
    }

    # is the skip valid?
    if ($Skip -lt 0) {
        throw "[Timer] $($Name): Cannot have a negative skip value"
    }

    # if we have a file path supplied, load that path as a scriptblock
    if ($PSCmdlet.ParameterSetName -ieq 'file') {
        $ScriptBlock = Convert-PodeFileToScriptBlock -FilePath $FilePath
    }

    # calculate the next tick time (based on Skip)
    $NextTick = [DateTime]::Now.AddSeconds($Interval)
    if ($Skip -gt 1) {
        $NextTick = $NextTick.AddSeconds($Interval * $Skip)
    }

    # add the timer
    $PodeContext.Timers[$Name] = @{
        Name = $Name
        Interval = $Interval
        Limit = $Limit
        Count = 0
        Skip = $Skip
        Countable = ($Limit -gt 0)
        NextTick = $NextTick
        Script = $ScriptBlock
        Arguments = $ArgumentList
        OnStart = $OnStart
        Completed = $false
    }
}

<#
.SYNOPSIS
Adhoc invoke a Timer's logic.

.DESCRIPTION
Adhoc invoke a Timer's logic outside of its defined interval. This invocation doesn't count towards the Timer's limit.

.PARAMETER Name
The Name of the Timer.

.EXAMPLE
Invoke-PodeTimer -Name 'timer-name'
#>
function Invoke-PodeTimer
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [string]
        $Name
    )

    # ensure the timer exists
    if (!$PodeContext.Timers.ContainsKey($Name)) {
        throw "Timer '$($Name)' does not exist"
    }

    # run timer logic
    Invoke-PodeInternalTimer -Timer ($PodeContext.Timers[$Name])
}

<#
.SYNOPSIS
Removes a specific Timer.

.DESCRIPTION
Removes a specific Timer.

.PARAMETER Name
The Name of Timer to be removed.

.EXAMPLE
Remove-PodeTimer -Name 'SaveState'
#>
function Remove-PodeTimer
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [string]
        $Name
    )

    $PodeContext.Timers.Remove($Name) | Out-Null
}

<#
.SYNOPSIS
Removes all Timers.

.DESCRIPTION
Removes all Timers.

.EXAMPLE
Clear-PodeTimers
#>
function Clear-PodeTimers
{
    [CmdletBinding()]
    param()

    $PodeContext.Timers.Clear()
}

<#
.SYNOPSIS
Edits an existing Timer.

.DESCRIPTION
Edits an existing Timer's properties, such as interval or scriptblock.

.PARAMETER Name
The Name of the Timer.

.PARAMETER Interval
The new Interval for the Timer in seconds.

.PARAMETER ScriptBlock
The new ScriptBlock for the Timer.

.PARAMETER ArgumentList
Any new Arguments for the Timer.

.EXAMPLE
Edit-PodeTimer -Name 'Hello' -Interval 10
#>
function Edit-PodeTimer
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [string]
        $Name,

        [Parameter()]
        [int]
        $Interval = 0,

        [Parameter()]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [object[]]
        $ArgumentList
    )

    # ensure the timer exists
    if (!$PodeContext.Timers.ContainsKey($Name)) {
        throw "Timer '$($Name)' does not exist"
    }

    # edit interval if supplied
    if ($Interval -gt 0) {
        $PodeContext.Timers[$Name].Interval = $Interval
    }

    # edit scriptblock if supplied
    if (!(Test-IsEmpty $ScriptBlock)) {
        $PodeContext.Timers[$Name].Script = $ScriptBlock
    }

    # edit arguments if supplied
    if (!(Test-IsEmpty $ArgumentList)) {
        $PodeContext.Timers[$Name].Arguments = $ArgumentList
    }
}

<#
.SYNOPSIS
Adds a new Schedule with logic to periodically invoke, defined using Cron Expressions.

.DESCRIPTION
Adds a new Schedule with logic to periodically invoke, defined using Cron Expressions.

.PARAMETER Name
The Name of the Schedule.

.PARAMETER Cron
One, or an Array, of Cron Expressions to define when the Schedule should trigger.

.PARAMETER ScriptBlock
The script defining the Schedule's logic.

.PARAMETER Limit
The number of times the Schedule should trigger before being removed.

.PARAMETER StartTime
A DateTime for when the Schedule should start triggering.

.PARAMETER EndTime
A DateTime for when the Schedule should stop triggering, and be removed.

.PARAMETER ArgumentList
A hashtable of arguments to supply to the Schedule's ScriptBlock.

.PARAMETER FilePath
A literal, or relative, path to a file containing a ScriptBlock for the Schedule's logic.

.PARAMETER OnStart
If supplied, the schedule will trigger when the server starts, regardless if the cron-expression matches the current time.

.EXAMPLE
Add-PodeSchedule -Name 'RunEveryMinute' -Cron '@minutely' -ScriptBlock { /* logic */ }

.EXAMPLE
Add-PodeSchedule -Name 'RunEveryTuesday' -Cron '0 0 * * TUE' -ScriptBlock { /* logic */ }

.EXAMPLE
Add-PodeSchedule -Name 'StartAfter2days' -Cron '@hourly' -StartTime [DateTime]::Now.AddDays(2) -ScriptBlock { /* logic */ }

.EXAMPLE
Add-PodeSchedule -Name 'Args' -Cron '@minutely' -ScriptBlock { /* logic */ } -ArgumentList @{ Arg1 = 'value' }
#>
function Add-PodeSchedule
{
    [CmdletBinding(DefaultParameterSetName='Script')]
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Name,

        [Parameter(Mandatory=$true)]
        [string[]]
        $Cron,

        [Parameter(Mandatory=$true, ParameterSetName='Script')]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [int]
        $Limit = 0,

        [Parameter()]
        [DateTime]
        $StartTime,

        [Parameter()]
        [DateTime]
        $EndTime,

        [Parameter(Mandatory=$true, ParameterSetName='File')]
        [string]
        $FilePath,

        [Parameter()]
        [hashtable]
        $ArgumentList,

        [switch]
        $OnStart
    )

    # error if serverless
    Test-PodeIsServerless -FunctionName 'Add-PodeSchedule' -ThrowError

    # ensure the schedule doesn't already exist
    if ($PodeContext.Schedules.ContainsKey($Name)) {
        throw "[Schedule] $($Name): Schedule already defined"
    }

    # ensure the limit is valid
    if ($Limit -lt 0) {
        throw "[Schedule] $($Name): Cannot have a negative limit"
    }

    # ensure the start/end dates are valid
    if (($null -ne $EndTime) -and ($EndTime -lt [DateTime]::Now)) {
        throw "[Schedule] $($Name): The EndTime value must be in the future"
    }

    if (($null -ne $StartTime) -and ($null -ne $EndTime) -and ($EndTime -lt $StartTime)) {
        throw "[Schedule] $($Name): Cannot have a StartTime after the EndTime"
    }

    # if we have a file path supplied, load that path as a scriptblock
    if ($PSCmdlet.ParameterSetName -ieq 'file') {
        $ScriptBlock = Convert-PodeFileToScriptBlock -FilePath $FilePath
    }

    # add the schedule
    $PodeContext.Schedules[$Name] = @{
        Name = $Name
        StartTime = $StartTime
        EndTime = $EndTime
        Crons = (ConvertFrom-PodeCronExpressions -Expressions @($Cron))
        Limit = $Limit
        Count = 0
        Countable = ($Limit -gt 0)
        Script = $ScriptBlock
        Arguments = (Protect-PodeValue -Value $ArgumentList -Default @{})
        OnStart = $OnStart
        Completed = $false
    }
}

<#
.SYNOPSIS
Set the maximum number of concurrent schedules.

.DESCRIPTION
Set the maximum number of concurrent schedules.

.PARAMETER Maximum
The Maximum number of schdules to run.

.EXAMPLE
Set-PodeScheduleConcurrency -Maximum 25
#>
function Set-PodeScheduleConcurrency
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [int]
        $Maximum
    )

    # error if <=0
    if ($Maximum -le 0) {
        throw "Maximum concurrent schedules must be >=1 but got: $($Maximum)"
    }

    # ensure max > min
    $_min = $PodeContext.RunspacePools.Schedules.GetMinRunspaces()
    if ($_min -gt $Maximum) {
        throw "Maximum concurrent schedules cannot be less than the minimum of $($_min) but got: $($Maximum)"
    }

    # set the max schedules
    $PodeContext.RunspacePools.Schedules.SetMaxRunspaces($Maximum)
}

<#
.SYNOPSIS
Adhoc invoke a Schedule's logic.

.DESCRIPTION
Adhoc invoke a Schedule's logic outside of its defined cron-expression. This invocation doesn't count towards the Schedule's limit.

.PARAMETER Name
The Name of the Schedule.

.EXAMPLE
Invoke-PodeSchedule -Name 'schedule-name'
#>
function Invoke-PodeSchedule
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [string]
        $Name
    )

    # ensure the schedule exists
    if (!$PodeContext.Schedules.ContainsKey($Name)) {
        throw "Schedule '$($Name)' does not exist"
    }

    # run schedule logic
    Invoke-PodeInternalScheduleLogic -Schedule ($PodeContext.Schedules[$Name])
}

<#
.SYNOPSIS
Removes a specific Schedule.

.DESCRIPTION
Removes a specific Schedule.

.PARAMETER Name
The Name of the Schedule to be removed.

.EXAMPLE
Remove-PodeSchedule -Name 'RenewToken'
#>
function Remove-PodeSchedule
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [string]
        $Name
    )

    $PodeContext.Schedules.Remove($Name) | Out-Null
}

<#
.SYNOPSIS
Removes all Schedules.

.DESCRIPTION
Removes all Schedules.

.EXAMPLE
Clear-PodeSchedules
#>
function Clear-PodeSchedules
{
    [CmdletBinding()]
    param()

    $PodeContext.Schedules.Clear()
}

<#
.SYNOPSIS
Edits an existing Schedule.

.DESCRIPTION
Edits an existing Schedule's properties, such an cron expressions or scriptblock.

.PARAMETER Name
The Name of the Schedule.

.PARAMETER Cron
Any new Cron Expressions for the Schedule.

.PARAMETER ScriptBlock
The new ScriptBlock for the Schedule.

.PARAMETER ArgumentList
Any new Arguments for the Schedule.

.EXAMPLE
Edit-PodeSchedule -Name 'Hello' -Cron '@minutely'

.EXAMPLE
Edit-PodeSchedule -Name 'Hello' -Cron @('@hourly', '0 0 * * TUE')
#>
function Edit-PodeSchedule
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [string]
        $Name,

        [Parameter()]
        [string[]]
        $Cron,

        [Parameter()]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [hashtable]
        $ArgumentList
    )

    # ensure the schedule exists
    if (!$PodeContext.Schedules.ContainsKey($Name)) {
        throw "Schedule '$($Name)' does not exist"
    }

    # edit cron if supplied
    if (!(Test-IsEmpty $Cron)) {
        $PodeContext.Schedules[$Name].Crons = (ConvertFrom-PodeCronExpressions -Expressions @($Cron))
    }

    # edit scriptblock if supplied
    if (!(Test-IsEmpty $ScriptBlock)) {
        $PodeContext.Schedules[$Name].Script = $ScriptBlock
    }

    # edit arguments if supplied
    if (!(Test-IsEmpty $ArgumentList)) {
        $PodeContext.Schedules[$Name].Arguments = $ArgumentList
    }
}

<#
.SYNOPSIS
Adds a new Middleware to be invoked before every Route, or certain Routes.

.DESCRIPTION
Adds a new Middleware to be invoked before every Route, or certain Routes.

.PARAMETER Name
The Name of the Middleware.

.PARAMETER ScriptBlock
The Script defining the logic of the Middleware.

.PARAMETER InputObject
A Middleware HashTable from New-PodeMiddleware, or from certain other functions that return Middleware as a HashTable.

.PARAMETER Route
A Route path for which Routes this Middleware should only be invoked against.

.PARAMETER ArgumentList
An array of arguments to supply to the Middleware's ScriptBlock.

.EXAMPLE
Add-PodeMiddleware -Name 'BlockAgents' -ScriptBlock { /* logic */ }

.EXAMPLE
Add-PodeMiddleware -Name 'CheckEmailOnApi' -Route '/api/*' -ScriptBlock { /* logic */ }
#>
function Add-PodeMiddleware
{
    [CmdletBinding(DefaultParameterSetName='Script')]
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Name,

        [Parameter(Mandatory=$true, ParameterSetName='Script')]
        [scriptblock]
        $ScriptBlock,

        [Parameter(Mandatory=$true, ParameterSetName='Input', ValueFromPipeline=$true)]
        [hashtable]
        $InputObject,

        [Parameter()]
        [string]
        $Route,

        [Parameter()]
        [object[]]
        $ArgumentList
    )

    # ensure name doesn't already exist
    if (($PodeContext.Server.Middleware | Where-Object { $_.Name -ieq $Name } | Measure-Object).Count -gt 0) {
        throw "[Middleware] $($Name): Middleware already defined"
    }

    # if it's a script - call New-PodeMiddleware
    if ($PSCmdlet.ParameterSetName -ieq 'script') {
        $InputObject = New-PodeMiddleware -ScriptBlock $ScriptBlock -Route $Route -ArgumentList $ArgumentList
    }
    else {
        if (![string]::IsNullOrWhiteSpace($Route)) {
            $Route = ConvertTo-PodeRouteRegex -Path $Route
        }

        $InputObject.Route = Protect-PodeValue -Value $Route -Default $InputObject.Route
        $InputObject.Options = Protect-PodeValue -Value $Options -Default $InputObject.Options
    }

    # ensure we have a script to run
    if (Test-IsEmpty $InputObject.Logic) {
        throw "[Middleware]: No logic supplied in ScriptBlock"
    }

    # set name, and override route/args
    $InputObject.Name = $Name

    # add the logic to array of middleware that needs to be run
    $PodeContext.Server.Middleware += $InputObject
}

<#
.SYNOPSIS
Creates a new Middleware HashTable object, that can be piped/used in Add-PodeMiddleware or in Routes.

.DESCRIPTION
Creates a new Middleware HashTable object, that can be piped/used in Add-PodeMiddleware or in Routes.

.PARAMETER ScriptBlock
The Script that defines the logic of the Middleware.

.PARAMETER Route
A Route path for which Routes this Middleware should only be invoked against.

.PARAMETER ArgumentList
An array of arguments to supply to the Middleware's ScriptBlock.

.EXAMPLE
New-PodeMiddleware -ScriptBlock { /* logic */ } -ArgumentList 'Email' | Add-PodeMiddleware -Name 'CheckEmail'
#>
function New-PodeMiddleware
{
    [CmdletBinding()]
    [OutputType([hashtable])]
    param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [string]
        $Route,

        [Parameter()]
        [object[]]
        $ArgumentList
    )

    # if route is empty, set it to root
    $Route = ConvertTo-PodeRouteRegex -Path $Route

    # create the middleware hashtable from a scriptblock
    $HashTable = @{
        Route = $Route
        Logic = $ScriptBlock
        Arguments = $ArgumentList
    }

    if (Test-IsEmpty $HashTable.Logic) {
        throw "[Middleware]: No logic supplied in ScriptBlock"
    }

    # return the middleware, so it can be cached/added at a later date
    return $HashTable
}

<#
.SYNOPSIS
Removes a specific user defined Middleware.

.DESCRIPTION
Removes a specific user defined Middleware.

.PARAMETER Name
The Name of the Middleware to be removed.

.EXAMPLE
Remove-PodeMiddleware -Name 'Sessions'
#>
function Remove-PodeMiddleware
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Name
    )

    $PodeContext.Server.Middleware = @($PodeContext.Server.Middleware | Where-Object { $_.Name -ine $Name })
}

<#
.SYNOPSIS
Removes all user defined Middleware.

.DESCRIPTION
Removes all user defined Middleware.

.EXAMPLE
Clear-PodeMiddleware
#>
function Clear-PodeMiddleware
{
    [CmdletBinding()]
    param()

    $PodeContext.Server.Middleware = @()
}