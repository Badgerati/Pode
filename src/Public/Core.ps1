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
The numbers of threads to use for Web, SMTP, and TCP servers.

.PARAMETER RootPath
An override for the Server's root path.

.PARAMETER Request
Intended for Serverless environments, this is Requests details that Pode can parse and use.

.PARAMETER ServerlessType
Optional, this is the serverless type, to define how Pode should run and deal with incoming Requests.

.PARAMETER StatusPageExceptions
An optional value of Show/Hide to control where Stacktraces are shown in the Status Pages.
If supplied this value will override the ShowExceptions setting in the server.psd1 file.

.PARAMETER DisableTermination
Disables the ability to terminate the Server.

.PARAMETER Quiet
Disables any output from the Server.

.PARAMETER Browse
Open the web Server's default endpoint in your default browser.

.PARAMETER CurrentPath
Sets the Server's root path to be the current working path - for -FilePath only.

.PARAMETER EnablePool
Tells Pode to configure certain RunspacePools when they're being used adhoc, such as Timers or Schedules.

.EXAMPLE
Start-PodeServer { /* logic */ }

.EXAMPLE
Start-PodeServer -Interval 10 { /* logic */ }

.EXAMPLE
Start-PodeServer -Request $LambdaInput -ServerlessType AwsLambda { /* logic */ }
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
        [ValidateSet('', 'AzureFunctions', 'AwsLambda')]
        [string]
        $ServerlessType = [string]::Empty,

        [Parameter()]
        [ValidateSet('', 'Hide', 'Show')]
        [string]
        $StatusPageExceptions = [string]::Empty,

        [Parameter()]
        [string]
        $ListenerType = [string]::Empty,

        [Parameter()]
        [ValidateSet('Timers', 'Schedules', 'Tasks', 'WebSockets')]
        [string[]]
        $EnablePool,

        [switch]
        $DisableTermination,

        [switch]
        $Quiet,

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
            $FilePath = Get-PodeRelativePath -Path $FilePath -Resolve -TestPath -JoinRoot -RootPath $MyInvocation.PSScriptRoot

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
        if (!(Test-PodeIsEmpty $RootPath)) {
            $RootPath = Get-PodeRelativePath -Path $RootPath -RootPath $MyInvocation.PSScriptRoot -JoinRoot -Resolve -TestPath
        }

        # check for state vars
        $ScriptBlock = Invoke-PodeStateScriptConversion -ScriptBlock $ScriptBlock

        # create main context object
        $PodeContext = New-PodeContext `
            -ScriptBlock $ScriptBlock `
            -FilePath $FilePath `
            -Threads $Threads `
            -Interval $Interval `
            -ServerRoot (Protect-PodeValue -Value $RootPath -Default $MyInvocation.PSScriptRoot) `
            -ServerlessType $ServerlessType `
            -ListenerType $ListenerType `
            -EnablePool $EnablePool `
            -StatusPageExceptions $StatusPageExceptions `
            -DisableTermination:$DisableTermination `
            -Quiet:$Quiet

        # set it so ctrl-c can terminate, unless serverless/iis, or disabled
        if (!$PodeContext.Server.DisableTermination -and ($null -eq $psISE)) {
            [Console]::TreatControlCAsInput = $true
        }

        # start the file monitor for interally restarting
        Start-PodeFileMonitor

        # start the server
        Start-PodeInternalServer -Request $Request -Browse:$Browse

        # at this point, if it's just a one-one off script, return
        if (!$PodeContext.Server.IsService -and (($PodeContext.Server.Types.Length -eq 0) -or $PodeContext.Server.IsServerless)) {
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

            # check for open browser
            if (Test-PodeOpenBrowserPressed -Key $key) {
                Invoke-PodeEvent -Type Browser
                Start-Process (Get-PodeEndpointUrl)
            }
        }

        if ($PodeContext.Server.IsIIS -and $PodeContext.Server.IIS.Shutdown) {
            Write-PodeHost '(IIS Shutdown) ' -NoNewline -ForegroundColor Yellow
        }

        Write-PodeHost 'Terminating...' -NoNewline -ForegroundColor Yellow
        Invoke-PodeEvent -Type Terminate
        $PodeContext.Tokens.Cancellation.Cancel()
    }
    catch {
        Invoke-PodeEvent -Type Crash
        $ShowDoneMessage = $false
        throw
    }
    finally {
        Invoke-PodeEvent -Type Stop

        # set output values
        Set-PodeOutputVariables

        # clean the runspaces and tokens
        Close-PodeServerInternal -ShowDoneMessage:$ShowDoneMessage

        # clean the session
        $PodeContext = $null
    }
}

<#
.SYNOPSIS
Closes the Pode server.

.DESCRIPTION
Closes the Pode server.

.EXAMPLE
Close-PodeServer
#>
function Close-PodeServer
{
    [CmdletBinding()]
    param()

    $PodeContext.Tokens.Cancellation.Cancel()
}

<#
.SYNOPSIS
Restarts the Pode server.

.DESCRIPTION
Restarts the Pode server.

.EXAMPLE
Restart-PodeServer
#>
function Restart-PodeServer
{
    [CmdletBinding()]
    param()

    $PodeContext.Tokens.Restart.Cancel()
}

<#
.SYNOPSIS
Helper wrapper function to start a Pode web server for a static website at the current directory.

.DESCRIPTION
Helper wrapper function to start a Pode web server for a static website at the current directory.

.PARAMETER Threads
The numbers of threads to use for requests.

.PARAMETER RootPath
An override for the Server's root path.

.PARAMETER Address
The IP/Hostname of the endpoint.

.PARAMETER Port
The Port number of the endpoint.

.PARAMETER Https
Start the server using HTTPS, if no certificate details are supplied a self-signed certificate will be generated.

.PARAMETER Certificate
The path to a certificate that can be use to enable HTTPS.

.PARAMETER CertificatePassword
The password for the certificate referenced in CertificateFile.

.PARAMETER CertificateKey
A key file to be paired with a PEM certificate referenced in CertificateFile

.PARAMETER X509Certificate
The raw X509 certificate that can be use to enable HTTPS.

.PARAMETER Path
The URI path for the static Route.

.PARAMETER Defaults
An array of default pages to display, such as 'index.html'.

.PARAMETER DownloadOnly
When supplied, all static content on this Route will be attached as downloads - rather than rendered.

.PARAMETER Browse
Open the web server's default endpoint in your default browser.

.EXAMPLE
Start-PodeStaticServer

.EXAMPLE
Start-PodeStaticServer -Address '127.0.0.3' -Port 8000

.EXAMPLE
Start-PodeStaticServer -Path '/installers' -DownloadOnly
#>
function Start-PodeStaticServer
{
    [CmdletBinding()]
    param(
        [Parameter()]
        [int]
        $Threads = 3,

        [Parameter()]
        [string]
        $RootPath = $PWD,

        [Parameter()]
        [string]
        $Address = 'localhost',

        [Parameter()]
        [int]
        $Port = 0,

        [Parameter()]
        [switch]
        $Https,

        [Parameter()]
        [string]
        $Certificate = $null,

        [Parameter()]
        [string]
        $CertificatePassword = $null,

        [Parameter()]
        [string]
        $CertificateKey = $null,

        [Parameter()]
        [X509Certificate]
        $X509Certificate = $null,

        [Parameter()]
        [string]
        $Path = '/',

        [Parameter()]
        [string[]]
        $Defaults,

        [switch]
        $DownloadOnly,

        [switch]
        $Browse
    )

    Start-PodeServer -RootPath $RootPath -Threads $Threads -Browse:$Browse -ScriptBlock {
        # add either an http or https endpoint
        if ($Https) {
            if ($null -ne $X509Certificate) {
                Add-PodeEndpoint -Address $Address -Port $Port -Protocol Https -X509Certificate $X509Certificate
            }
            elseif (![string]::IsNullOrWhiteSpace($Certificate)) {
                Add-PodeEndpoint -Address $Address -Port $Port -Protocol Https -Certificate $Certificate -CertificatePassword $CertificatePassword -CertificateKey $CertificateKey
            }
            else {
                Add-PodeEndpoint -Address $Address -Port $Port -Protocol Https -SelfSigned
            }
        }
        else {
            Add-PodeEndpoint -Address $Address -Port $Port -Protocol Http
        }

        # add the static route
        Add-PodeStaticRoute -Path $Path -Source (Get-PodeServerPath) -Defaults $Defaults -DownloadOnly:$DownloadOnly
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
    if ((Test-PodeIsPSCore) -and ($PSVersionTable.PSVersion.Major -eq 6)) {
        throw 'Show-PodeGui is currently only available for Windows PowerShell, and PowerShell 7+ on Windows'
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

    if (![string]::IsNullOrWhiteSpace($EndpointName)) {
        if (!$PodeContext.Server.Endpoints.ContainsKey($EndpointName)) {
            throw "Endpoint with name '$($EndpointName)' does not exist"
        }

        $PodeContext.Server.Gui.Endpoint = $PodeContext.Server.Endpoints[$EndpointName]
    }
}

<#
.SYNOPSIS
Bind an endpoint to listen for incoming Requests.

.DESCRIPTION
Bind an endpoint to listen for incoming Requests. The endpoints can be HTTP, HTTPS, TCP or SMTP, with the option to bind certificates.

.PARAMETER Address
The IP/Hostname of the endpoint (Default: localhost).

.PARAMETER Port
The Port number of the endpoint.

.PARAMETER Hostname
An optional hostname for the endpoint, specifying a hostname restricts access to just the hostname.

.PARAMETER Protocol
The protocol of the supplied endpoint.

.PARAMETER Certificate
The path to a certificate that can be use to enable HTTPS

.PARAMETER CertificatePassword
The password for the certificate file referenced in Certificate

.PARAMETER CertificateKey
A key file to be paired with a PEM certificate file referenced in Certificate

.PARAMETER CertificateThumbprint
A certificate thumbprint to bind onto HTTPS endpoints (Windows).

.PARAMETER CertificateName
A certificate subject name to bind onto HTTPS endpoints (Windows).

.PARAMETER CertificateStoreName
The name of a certifcate store where a certificate can be found (Default: My) (Windows).

.PARAMETER CertificateStoreLocation
The location of a certifcate store where a certificate can be found (Default: CurrentUser) (Windows).

.PARAMETER X509Certificate
The raw X509 certificate that can be use to enable HTTPS

.PARAMETER TlsMode
The TLS mode to use on secure connections, options are Implicit or Explicit (SMTP only) (Default: Implicit).

.PARAMETER Name
An optional name for the endpoint, that can be used with other functions (Default: GUID).

.PARAMETER RedirectTo
The Name of another Endpoint to automatically generate a redirect route for all traffic.

.PARAMETER Description
A quick description of the Endpoint - normally used in OpenAPI.

.PARAMETER Acknowledge
An optional Acknowledge message to send to clients when they first connect, for TCP and SMTP endpoints only.

.PARAMETER CRLFMessageEnd
If supplied, TCP endpoints will expect incoming data to end with CRLF.

.PARAMETER Force
Ignore Adminstrator checks for non-localhost endpoints.

.PARAMETER SelfSigned
Create and bind a self-signed certifcate for HTTPS endpoints.

.PARAMETER AllowClientCertificate
Allow for client certificates to be sent on requests.

.PARAMETER PassThru
If supplied, the endpoint created will be returned.

.PARAMETER LookupHostname
If supplied, a supplied Hostname will have its IP Address looked up from host file or DNS.

.PARAMETER Default
If supplied, this endpoint will be the default one used for internally generating URLs.

.EXAMPLE
Add-PodeEndpoint -Address localhost -Port 8090 -Protocol Http

.EXAMPLE
Add-PodeEndpoint -Address localhost -Protocol Smtp

.EXAMPLE
Add-PodeEndpoint -Address dev.pode.com -Port 8443 -Protocol Https -SelfSigned

.EXAMPLE
Add-PodeEndpoint -Address 127.0.0.2 -Hostname dev.pode.com -Port 8443 -Protocol Https -SelfSigned

.EXAMPLE
Add-PodeEndpoint -Address live.pode.com -Protocol Https -CertificateThumbprint '2A9467F7D3940243D6C07DE61E7FCCE292'
#>
function Add-PodeEndpoint
{
    [CmdletBinding(DefaultParameterSetName='Default')]
    param (
        [Parameter()]
        [string]
        $Address = 'localhost',

        [Parameter()]
        [int]
        $Port = 0,

        [Parameter()]
        [string]
        $Hostname,

        [Parameter()]
        [ValidateSet('Http', 'Https', 'Smtp', 'Smtps', 'Tcp', 'Tcps', 'Ws', 'Wss', 'Ftp', 'Ftps')]
        [string]
        $Protocol,

        [Parameter(Mandatory=$true, ParameterSetName='CertFile')]
        [string]
        $Certificate = $null,

        [Parameter(ParameterSetName='CertFile')]
        [string]
        $CertificatePassword = $null,

        [Parameter(ParameterSetName='CertFile')]
        [string]
        $CertificateKey = $null,

        [Parameter(Mandatory=$true, ParameterSetName='CertThumb')]
        [string]
        $CertificateThumbprint,

        [Parameter(Mandatory=$true, ParameterSetName='CertName')]
        [string]
        $CertificateName,

        [Parameter(ParameterSetName='CertName')]
        [Parameter(ParameterSetName='CertThumb')]
        [System.Security.Cryptography.X509Certificates.StoreName]
        $CertificateStoreName = 'My',

        [Parameter(ParameterSetName='CertName')]
        [Parameter(ParameterSetName='CertThumb')]
        [System.Security.Cryptography.X509Certificates.StoreLocation]
        $CertificateStoreLocation = 'CurrentUser',

        [Parameter(Mandatory=$true, ParameterSetName='CertRaw')]
        [X509Certificate]
        $X509Certificate = $null,

        [Parameter(ParameterSetName='CertFile')]
        [Parameter(ParameterSetName='CertThumb')]
        [Parameter(ParameterSetName='CertName')]
        [Parameter(ParameterSetName='CertRaw')]
        [Parameter(ParameterSetName='CertSelf')]
        [ValidateSet('Implicit', 'Explicit')]
        [string]
        $TlsMode = 'Implicit',

        [Parameter()]
        [string]
        $Name = $null,

        [Parameter()]
        [string]
        $RedirectTo = $null,

        [Parameter()]
        [string]
        $Description,

        [Parameter()]
        [string]
        $Acknowledge,

        [switch]
        $CRLFMessageEnd,

        [switch]
        $Force,

        [Parameter(ParameterSetName='CertSelf')]
        [switch]
        $SelfSigned,

        [switch]
        $AllowClientCertificate,

        [switch]
        $PassThru,

        [switch]
        $LookupHostname,

        [switch]
        $Default
    )

    # error if serverless
    Test-PodeIsServerless -FunctionName 'Add-PodeEndpoint' -ThrowError

    # if RedirectTo is supplied, then a Name is mandatory
    if (![string]::IsNullOrWhiteSpace($RedirectTo) -and [string]::IsNullOrWhiteSpace($Name)) {
        throw "A Name is required for the endpoint if the RedirectTo parameter is supplied"
    }

    # get the type of endpoint
    $type = Get-PodeEndpointType -Protocol $Protocol

    # are we running as IIS for HTTP/HTTPS? (if yes, force the port, address and protocol)
    $isIIS = ((Test-PodeIsIIS) -and (@('Http', 'Ws') -icontains $type))
    if ($isIIS) {
        $Port = [int]$env:ASPNETCORE_PORT
        $Address = '127.0.0.1'
        $Hostname = [string]::Empty
        $Protocol = $type
    }

    # are we running as Heroku for HTTP/HTTPS? (if yes, force the port, address and protocol)
    $isHeroku = ((Test-PodeIsHeroku) -and (@('Http') -icontains $type))
    if ($isHeroku) {
        $Port = [int]$env:PORT
        $Address = '0.0.0.0'
        $Hostname = [string]::Empty
        $Protocol = $type
    }

    # parse the endpoint for host/port info
    if (![string]::IsNullOrWhiteSpace($Hostname) -and !(Test-PodeHostname -Hostname $Hostname)) {
        throw "Invalid hostname supplied: $($Hostname)"
    }

    if ((Test-PodeHostname -Hostname $Address) -and ($Address -inotin @('localhost', 'all'))) {
        $Hostname = $Address
        $Address = 'localhost'
    }

    if (![string]::IsNullOrWhiteSpace($Hostname) -and $LookupHostname) {
        $Address = (Get-PodeIPAddressesForHostname -Hostname $Hostname -Type All | Select-Object -First 1)
    }

    $_endpoint = Get-PodeEndpointInfo -Address "$($Address):$($Port)"

    # if no name, set to guid, then check uniqueness
    if ([string]::IsNullOrWhiteSpace($Name)) {
        $Name = New-PodeGuid -Secure
    }

    if ($PodeContext.Server.Endpoints.ContainsKey($Name)) {
        throw "An endpoint with the name '$($Name)' has already been defined"
    }

    # protocol must be https for client certs, or hosted behind a proxy like iis
    if (($Protocol -ine 'https') -and !(Test-PodeIsHosted) -and $AllowClientCertificate) {
        throw "Client certificates are only supported on HTTPS endpoints"
    }

    # explicit tls is only supported for smtp/tcp/ftp
    if (($type -inotin @('smtp', 'tcp', 'ftp')) -and ($TlsMode -ieq 'explicit')) {
        throw "The Explicit TLS mode is only supported on SMTPS, FTPS and TCPS endpoints"
    }

    # ack message is only for smtp/tcp/ftp
    if (($type -inotin @('smtp', 'tcp', 'ftp')) -and ![string]::IsNullOrEmpty($Acknowledge)) {
        throw "The Acknowledge message is only supported on SMTP, FTP and TCP endpoints"
    }

    # crlf message end is only for tcp
    if (($type -ine 'tcp') -and $CRLFMessageEnd) {
        throw "The CRLF message end check is only supported on TCP endpoints"
    }

    # new endpoint object
    $obj = @{
        Name = $Name
        Description = $Description
        Address = $null
        RawAddress = $null
        Port = $null
        IsIPAddress = $true
        HostName = $Hostname
        FriendlyName = $Hostname
        Url = $null
        Ssl = (@('https', 'wss', 'smtps', 'tcps', 'ftps') -icontains $Protocol)
        Protocol = $Protocol.ToLowerInvariant()
        Type = $type.ToLowerInvariant()
        Runspace = @{
            PoolName = (Get-PodeEndpointRunspacePoolName -Protocol $Protocol)
        }
        Default = $Default.IsPresent
        Certificate = @{
            Raw = $X509Certificate
            SelfSigned = $SelfSigned
            AllowClientCertificate = $AllowClientCertificate
            TlsMode = $TlsMode
        }
        Tcp = @{
            Acknowledge = $Acknowledge
            CRLFMessageEnd = $CRLFMessageEnd
        }
    }

    # set the ip for the context (force to localhost for IIS)
    $obj.Address = (Get-PodeIPAddress $_endpoint.Host)
    $obj.IsIPAddress = [string]::IsNullOrWhiteSpace($obj.HostName)

    if ($obj.IsIPAddress) {
        $obj.FriendlyName = 'localhost'
        if (!(Test-PodeIPAddressLocalOrAny -IP $obj.Address)) {
            $obj.FriendlyName = "$($obj.Address)"
        }
    }

    # set the port for the context, if 0 use a default port for protocol
    $obj.Port = $_endpoint.Port
    if (([int]$obj.Port) -eq 0) {
        $obj.Port = Get-PodeDefaultPort -Protocol $Protocol -TlsMode $TlsMode
    }

    if ($obj.IsIPAddress) {
        $obj.RawAddress = "$($obj.Address):$($obj.Port)"
    }
    else {
        $obj.RawAddress = "$($obj.FriendlyName):$($obj.Port)"
    }

    # set the url of this endpoint
    $obj.Url = "$($obj.Protocol)://$($obj.FriendlyName):$($obj.Port)/"

    # if the address is non-local, then check admin privileges
    if (!$Force -and !(Test-PodeIPAddressLocal -IP $obj.Address) -and !(Test-PodeIsAdminUser)) {
        throw 'Must be running with administrator priviledges to listen on non-localhost addresses'
    }

    # has this endpoint been added before? (for http/https we can just not add it again)
    $exists = ($PodeContext.Server.Endpoints.Values | Where-Object {
        ($_.FriendlyName -ieq $obj.FriendlyName) -and ($_.Port -eq $obj.Port) -and ($_.Ssl -eq $obj.Ssl) -and ($_.Type -ieq $obj.Type)
    } | Measure-Object).Count

    # if we're dealing with a certificate, attempt to import it
    if (!(Test-PodeIsHosted) -and ($PSCmdlet.ParameterSetName -ilike 'cert*')) {
        # fail if protocol is not https
        if (!$obj.Ssl) {
            throw "Certificate supplied for non-SSL endpoint"
        }

        switch ($PSCmdlet.ParameterSetName.ToLowerInvariant())
        {
            'certfile' {
                $obj.Certificate.Raw = Get-PodeCertificateByFile -Certificate $Certificate -Password $CertificatePassword -Key $CertificateKey
            }

            'certthumb' {
                $obj.Certificate.Raw = Get-PodeCertificateByThumbprint -Thumbprint $CertificateThumbprint -StoreName $CertificateStoreName -StoreLocation $CertificateStoreLocation
            }

            'certname' {
                $obj.Certificate.Raw = Get-PodeCertificateByName -Name $CertificateName -StoreName $CertificateStoreName -StoreLocation $CertificateStoreLocation
            }

            'certself' {
                $obj.Certificate.Raw = New-PodeSelfSignedCertificate
            }
        }

        # fail if the cert is expired
        if ($obj.Certificate.Raw.NotAfter -lt [datetime]::Now) {
            throw "The certificate '$($obj.Certificate.Raw.Subject)' has expired: $($obj.Certificate.Raw.NotAfter)"
        }
    }

    if (!$exists) {
        # set server type
        $_type = $type
        if ($_type -iin @('http', 'ws')) {
            $_type = 'http'
        }

        if ($PodeContext.Server.Types -inotcontains $_type) {
            $PodeContext.Server.Types += $_type
        }

        # add the new endpoint
        $PodeContext.Server.Endpoints[$Name] = $obj
        $PodeContext.Server.EndpointsMap["$($obj.Protocol)|$($obj.RawAddress)"] = $Name
    }

    # if RedirectTo is set, attempt to build a redirecting route
    if (!(Test-PodeIsHosted) -and ![string]::IsNullOrWhiteSpace($RedirectTo)) {
        $redir_endpoint = $PodeContext.Server.Endpoints[$RedirectTo]

        # ensure the name exists
        if (Test-PodeIsEmpty $redir_endpoint) {
            throw "An endpoint with the name '$($RedirectTo)' has not been defined for redirecting"
        }

        # build the redirect route
        Add-PodeRoute -Method * -Path * -EndpointName $obj.Name -ArgumentList $redir_endpoint -ScriptBlock {
            param($endpoint)
            Move-PodeResponseUrl -EndpointName $endpoint.Name
        }
    }

    # return the endpoint?
    if ($PassThru) {
        return $obj
    }
}

<#
.SYNOPSIS
Get an Endpoint(s).

.DESCRIPTION
Get an Endpoint(s).

.PARAMETER Address
An Address to filter the endpoints.

.PARAMETER Port
A Port to filter the endpoints.

.PARAMETER Hostname
A Hostname to filter the endpoints.

.PARAMETER Protocol
A Protocol to filter the endpoints.

.PARAMETER Name
Any endpoints Names to filter endpoints.

.EXAMPLE
Get-PodeEndpoint -Address 127.0.0.1

.EXAMPLE
Get-PodeEndpoint -Protocol Http

.EXAMPLE
Get-PodeEndpoint -Name Admin, User
#>
function Get-PodeEndpoint
{
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Address,

        [Parameter()]
        [int]
        $Port = 0,

        [Parameter()]
        [string]
        $Hostname,

        [Parameter()]
        [ValidateSet('', 'Http', 'Https', 'Smtp', 'Smtps', 'Tcp', 'Tcps', 'Ws', 'Wss', 'Ftp', 'Ftps')]
        [string]
        $Protocol,

        [Parameter()]
        [string[]]
        $Name
    )

    if ((Test-PodeHostname -Hostname $Address) -and ($Address -inotin @('localhost', 'all'))) {
        $Hostname = $Address
        $Address = 'localhost'
    }

    $endpoints = $PodeContext.Server.Endpoints.Values

    # if we have an address, filter
    if (![string]::IsNullOrWhiteSpace($Address)) {
        if (($Address -eq '*') -or $PodeContext.Server.IsHeroku) {
            $Address = '0.0.0.0'
        }

        if ($PodeContext.Server.IsIIS -or ($Address -ieq 'localhost')) {
            $Address = '127.0.0.1'
        }

        $endpoints = @(foreach ($endpoint in $endpoints) {
            if ($endpoint.Address.ToString() -ine $Address) {
                continue
            }

            $endpoint
        })
    }

    # if we have a hostname, filter
    if (![string]::IsNullOrWhiteSpace($Hostname)) {
        $endpoints = @(foreach ($endpoint in $endpoints) {
            if ($endpoint.Hostname.ToString() -ine $Hostname) {
                continue
            }

            $endpoint
        })
    }

    # if we have a port, filter
    if ($Port -gt 0) {
        if ($PodeContext.Server.IsIIS) {
            $Port = [int]$env:ASPNETCORE_PORT
        }

        if ($PodeContext.Server.IsHeroku) {
            $Port = [int]$env:PORT
        }

        $endpoints = @(foreach ($endpoint in $endpoints) {
            if ($endpoint.Port -ne $Port) {
                continue
            }

            $endpoint
        })
    }

    # if we have a protocol, filter
    if (![string]::IsNullOrWhiteSpace($Protocol)) {
        if ($PodeContext.Server.IsIIS -or $PodeContext.Server.IsHeroku) {
            $Protocol = 'Http'
        }

        $endpoints = @(foreach ($endpoint in $endpoints) {
            if ($endpoint.Protocol -ine $Protocol) {
                continue
            }

            $endpoint
        })
    }

    # further filter by endpoint names
    if (($null -ne $Name) -and ($Name.Length -gt 0)) {
        $endpoints = @(foreach ($_name in $Name) {
            foreach ($endpoint in $endpoints) {
                if ($endpoint.Name -ine $_name) {
                    continue
                }

                $endpoint
            }
        })
    }

    # return
    return $endpoints
}