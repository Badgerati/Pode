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

.PARAMETER ListenerType
An optional value to use a custom Socket Listener. The default is Pode's inbuilt listener.
There's the Pode.Kestrel module, so the value here should be "Kestrel" if using that.

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

.PARAMETER EnableBreakpoints
If supplied, any breakpoints created by using Wait-PodeDebugger will be enabled - or disabled if false passed explicitly, or not supplied.

.EXAMPLE
Start-PodeServer { /* logic */ }

.EXAMPLE
Start-PodeServer -Interval 10 { /* logic */ }

.EXAMPLE
Start-PodeServer -Request $LambdaInput -ServerlessType AwsLambda { /* logic */ }
#>
function Start-PodeServer {
    [CmdletBinding(DefaultParameterSetName = 'Script')]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0, ParameterSetName = 'Script')]
        [scriptblock]
        $ScriptBlock,

        [Parameter(Mandatory = $true, ParameterSetName = 'File')]
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
        [ValidateSet('Timers', 'Schedules', 'Tasks', 'WebSockets', 'Files')]
        [string[]]
        $EnablePool,

        [switch]
        $DisableTermination,

        [switch]
        $Quiet,

        [switch]
        $Browse,

        [Parameter(ParameterSetName = 'File')]
        [switch]
        $CurrentPath,

        [switch]
        $EnableBreakpoints
    )
    begin {
        $pipelineItemCount = 0
    }

    process {
        $pipelineItemCount++
    }

    end {
        if ($pipelineItemCount -gt 1) {
            throw ($PodeLocale.fnDoesNotAcceptArrayAsPipelineInputExceptionMessage -f $($MyInvocation.MyCommand.Name))
        }    # Store the name of the current runspace
        $previousRunspaceName = Get-PodeCurrentRunspaceName
        # Sets the name of the current runspace
        Set-PodeCurrentRunspaceName -Name 'PodeServer'

        # Compile the Debug Handler
        Initialize-PodeDebugHandler

        # ensure the session is clean
        $Script:PodeContext = $null
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
                -Quiet:$Quiet `
                -EnableBreakpoints:$EnableBreakpoints

            # set it so ctrl-c can terminate, unless serverless/iis, or disabled
            if (!$PodeContext.Server.DisableTermination -and ($null -eq $psISE)) {
                [Console]::TreatControlCAsInput = $true
            }

            # start the file monitor for interally restarting
            Start-PodeFileMonitor

            # start the server
            Start-PodeInternalServer -Request $Request -Browse:$Browse

            # at this point, if it's just a one-one off script, return
            if (!(Test-PodeServerKeepOpen)) {
                return
            }

            # sit here waiting for termination/cancellation, or to restart the server
            while (  !($PodeContext.Tokens.Cancellation.IsCancellationRequested)) {
                try {
                    Start-Sleep -Seconds 1

                    if (!$PodeContext.Server.DisableTermination) {
                        # get the next key presses
                        $key = Get-PodeConsoleKey
                    }

                    # check for internal restart
                    if (($PodeContext.Tokens.Restart.IsCancellationRequested) -or (Test-PodeRestartPressed -Key $key)) {
                        Restart-PodeInternalServer
                    }

                    if (($PodeContext.Tokens.Dump.IsCancellationRequested) -or (Test-PodeDumpPressed -Key $key) ) {
                        Invoke-PodeDumpInternal
                        if ($PodeContext.Server.Debug.Dump.Param.Halt) {
                            Write-PodeHost -ForegroundColor Red 'Halt switch detected. Closing the application.'
                            break
                        }
                    }

                    if (($PodeContext.Tokens.Suspend.SuspendResume) -or (Test-PodeSuspendPressed -Key $key)) {
                        if ( $PodeContext.Server.Suspended) {
                            Resume-PodeServerInternal
                        }
                        else {
                            Suspend-PodeServerInternal
                        }
                    }

                    # check for open browser
                    if (Test-PodeOpenBrowserPressed -Key $key) {
                        $url = Get-PodeEndpointUrl
                        if ($null -ne $url) {
                            Invoke-PodeEvent -Type Browser
                            Start-Process $url
                        }
                    }

                    if (Test-PodeTerminationPressed -Key $key) {
                        break
                    }
                }
                finally {
                    Clear-PodeKeyPressed
                }
            }

            if ($PodeContext.Server.IsIIS -and $PodeContext.Server.IIS.Shutdown) {
                # (IIS Shutdown)
                Write-PodeHost $PodeLocale.iisShutdownMessage -NoNewLine -ForegroundColor Yellow
                Write-PodeHost ' ' -NoNewLine
            }
            # Terminating...
            Write-PodeHost $PodeLocale.terminatingMessage -NoNewLine -ForegroundColor Yellow
            Invoke-PodeEvent -Type Terminate
            $PodeContext.Tokens.Cancellation.Cancel()
        }
        catch {
            $_ | Write-PodeErrorLog

            if ($PodeContext.Server.Debug.Dump.Enable) {
                Invoke-PodeDumpInternal -ErrorRecord $_
            }

            Invoke-PodeEvent -Type Crash
            $ShowDoneMessage = $false
            throw
        }
        finally {
            Invoke-PodeEvent -Type Stop

            # set output values
            Set-PodeOutputVariable

            # unregister secret vaults
            Unregister-PodeSecretVaultsInternal

            # clean the runspaces and tokens
            Close-PodeServerInternal -ShowDoneMessage:$ShowDoneMessage

            # clean the session
            $PodeContext = $null

            # Restore the name of the current runspace
            Set-PodeCurrentRunspaceName -Name $previousRunspaceName
        }
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
function Close-PodeServer {
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
function Restart-PodeServer {
    [CmdletBinding()]
    param()

    $PodeContext.Tokens.Restart.Cancel()
}


<#
.SYNOPSIS
    Resumes the Pode server from a suspended state.

.DESCRIPTION
    This function resumes the Pode server, ensuring all associated runspaces are restored to their normal execution state.
    It triggers the 'Resume' event, updates the server's suspended status, and clears the host for a refreshed console view.

.EXAMPLE
    Resume-PodeServer
    # Resumes the Pode server after a suspension.

#>
function Resume-PodeServer {
    [CmdletBinding()]
    param()
    if ( $PodeContext.Server.Suspended) {
        $PodeContext.Tokens.SuspendResume.Cancel()
    }
}


<#
.SYNOPSIS
    Suspends the Pode server and its runspaces.

.DESCRIPTION
    This function suspends the Pode server by pausing all associated runspaces and ensuring they enter a debug state.
    It triggers the 'Suspend' event, updates the server's suspended status, and provides feedback during the suspension process.

.PARAMETER Timeout
    The maximum time, in seconds, to wait for each runspace to be suspended before timing out. Default is 30 seconds.

.EXAMPLE
    Suspend-PodeServerInternal -Timeout 60
    # Suspends the Pode server with a timeout of 60 seconds.

#>
function Suspend-PodeServer {
    [CmdletBinding()]
    param()
    if (! $PodeContext.Server.Suspended) {
        $PodeContext.Tokens.SuspendResume.Cancel()
    }
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

.PARAMETER FileBrowser
When supplied, If the path is a folder, instead of returning 404, will return A browsable content of the directory.

.PARAMETER Browse
Open the web server's default endpoint in your default browser.

.EXAMPLE
Start-PodeStaticServer

.EXAMPLE
Start-PodeStaticServer -Address '127.0.0.3' -Port 8000

.EXAMPLE
Start-PodeStaticServer -Path '/installers' -DownloadOnly
#>
function Start-PodeStaticServer {
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
        $FileBrowser,

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
        Add-PodeStaticRoute -Path $Path -Source (Get-PodeServerPath) -Defaults $Defaults -DownloadOnly:$DownloadOnly -FileBrowser:$FileBrowser
    }
}

<#
.SYNOPSIS
A default server secret that can be for signing values like Session, Cookies, or SSE IDs.

.DESCRIPTION
A default server secret that can be for signing values like Session, Cookies, or SSE IDs. This secret is regenerated
on every server start and restart.

.EXAMPLE
$secret = Get-PodeServerDefaultSecret
#>
function Get-PodeServerDefaultSecret {
    [CmdletBinding()]
    param()

    return $PodeContext.Server.DefaultSecret
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
function Pode {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
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
        'name'        = $name
        'version'     = '1.0.0'
        'description' = ''
        'main'        = './server.ps1'
        'scripts'     = @{
            'start'   = './server.ps1'
            'install' = 'yarn install --force --ignore-scripts --modules-folder pode_modules'
            'build'   = 'psake'
            'test'    = 'invoke-pester ./tests/*.ps1'
        }
        'author'      = ''
        'license'     = 'MIT'
    }

    # check and load config if already exists
    if (Test-Path $file) {
        $data = (Get-Content $file | ConvertFrom-Json)
    }

    # quick check to see if the data is required
    if ($Action -ine 'init') {
        if ($null -eq $data) {
            Write-PodeHost 'package.json file not found' -ForegroundColor Red
            return
        }
        else {
            $actionScript = $data.scripts.$Action

            if ([string]::IsNullOrWhiteSpace($actionScript) -and $Action -ieq 'start') {
                $actionScript = $data.main
            }

            if ([string]::IsNullOrWhiteSpace($actionScript) -and $Action -ine 'install') {
                Write-PodeHost "package.json does not contain a script for the $($Action) action" -ForegroundColor Yellow
                return
            }
        }
    }
    else {
        if ($null -ne $data) {
            Write-PodeHost 'package.json already exists' -ForegroundColor Yellow
            return
        }
    }

    switch ($Action.ToLowerInvariant()) {
        'init' {
            $v = Read-Host -Prompt "name ($($map.name))"
            if (![string]::IsNullOrWhiteSpace($v)) { $map.name = $v }

            $v = Read-Host -Prompt "version ($($map.version))"
            if (![string]::IsNullOrWhiteSpace($v)) { $map.version = $v }

            $map.description = Read-Host -Prompt 'description'

            $v = Read-Host -Prompt "entry point ($($map.main))"
            if (![string]::IsNullOrWhiteSpace($v)) { $map.main = $v; $map.scripts.start = $v }

            $map.author = Read-Host -Prompt 'author'

            $v = Read-Host -Prompt "license ($($map.license))"
            if (![string]::IsNullOrWhiteSpace($v)) { $map.license = $v }

            $map | ConvertTo-Json -Depth 10 | Out-File -FilePath $file -Encoding utf8 -Force
            Write-PodeHost 'Success, saved package.json' -ForegroundColor Green
        }

        'test' {
            Invoke-PodePackageScript -ActionScript $actionScript
        }

        'start' {
            Invoke-PodePackageScript -ActionScript $actionScript
        }

        'install' {
            if ($Dev) {
                Install-PodeLocalModule -Module $data.devModules
            }

            Install-PodeLocalModule -Module $data.modules
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
function Show-PodeGui {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
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
    begin {
        $pipelineItemCount = 0
    }

    process {

        $pipelineItemCount++
    }

    end {
        if ($pipelineItemCount -gt 1) {
            throw ($PodeLocale.fnDoesNotAcceptArrayAsPipelineInputExceptionMessage -f $($MyInvocation.MyCommand.Name))
        }
        # error if serverless
        Test-PodeIsServerless -FunctionName 'Show-PodeGui' -ThrowError

        # only valid for Windows PowerShell
        if ((Test-PodeIsPSCore) -and ($PSVersionTable.PSVersion.Major -eq 6)) {
            # Show-PodeGui is currently only available for Windows PowerShell and PowerShell 7+ on Windows
            throw ($PodeLocale.showPodeGuiOnlyAvailableOnWindowsExceptionMessage)
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
            $PodeContext.Server.Gui.Icon = Get-PodeRelativePath -Path $Icon -JoinRoot -Resolve
            if (!(Test-Path $PodeContext.Server.Gui.Icon)) {
                # Path to icon for GUI does not exist
                throw ($PodeLocale.pathToIconForGuiDoesNotExistExceptionMessage -f $PodeContext.Server.Gui.Icon)
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
                # Endpoint with name '$EndpointName' does not exist.
                throw ($PodeLocale.endpointNameNotExistExceptionMessage -f $EndpointName)
            }

            $PodeContext.Server.Gui.Endpoint = $PodeContext.Server.Endpoints[$EndpointName]
        }
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

.PARAMETER SslProtocol
One or more optional SSL Protocols this endpoints supports. (Default: SSL3/TLS12 - Just TLS12 on MacOS).

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

.PARAMETER DualMode
If supplied, this endpoint will listen on both the IPv4 and IPv6 versions of the supplied -Address.
For IPv6, this will only work if the IPv6 address can convert to a valid IPv4 address.

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
function Add-PodeEndpoint {
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    [OutputType([hashtable])]
    param(
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
        [ValidateSet('Http', 'Https', 'Smtp', 'Smtps', 'Tcp', 'Tcps', 'Ws', 'Wss')]
        [string]
        $Protocol,

        [Parameter(Mandatory = $true, ParameterSetName = 'CertFile')]
        [string]
        $Certificate = $null,

        [Parameter(ParameterSetName = 'CertFile')]
        [string]
        $CertificatePassword = $null,

        [Parameter(ParameterSetName = 'CertFile')]
        [string]
        $CertificateKey = $null,

        [Parameter(Mandatory = $true, ParameterSetName = 'CertThumb')]
        [string]
        $CertificateThumbprint,

        [Parameter(Mandatory = $true, ParameterSetName = 'CertName')]
        [string]
        $CertificateName,

        [Parameter(ParameterSetName = 'CertName')]
        [Parameter(ParameterSetName = 'CertThumb')]
        [System.Security.Cryptography.X509Certificates.StoreName]
        $CertificateStoreName = 'My',

        [Parameter(ParameterSetName = 'CertName')]
        [Parameter(ParameterSetName = 'CertThumb')]
        [System.Security.Cryptography.X509Certificates.StoreLocation]
        $CertificateStoreLocation = 'CurrentUser',

        [Parameter(Mandatory = $true, ParameterSetName = 'CertRaw')]
        [X509Certificate]
        $X509Certificate = $null,

        [Parameter(ParameterSetName = 'CertFile')]
        [Parameter(ParameterSetName = 'CertThumb')]
        [Parameter(ParameterSetName = 'CertName')]
        [Parameter(ParameterSetName = 'CertRaw')]
        [Parameter(ParameterSetName = 'CertSelf')]
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

        [Parameter()]
        [ValidateSet('Ssl2', 'Ssl3', 'Tls', 'Tls11', 'Tls12', 'Tls13')]
        [string[]]
        $SslProtocol = $null,

        [switch]
        $CRLFMessageEnd,

        [switch]
        $Force,

        [Parameter(ParameterSetName = 'CertSelf')]
        [switch]
        $SelfSigned,

        [switch]
        $AllowClientCertificate,

        [switch]
        $PassThru,

        [switch]
        $LookupHostname,

        [switch]
        $DualMode,

        [switch]
        $Default
    )

    # error if serverless
    Test-PodeIsServerless -FunctionName 'Add-PodeEndpoint' -ThrowError

    # if RedirectTo is supplied, then a Name is mandatory
    if (![string]::IsNullOrWhiteSpace($RedirectTo) -and [string]::IsNullOrWhiteSpace($Name)) {
        # A Name is required for the endpoint if the RedirectTo parameter is supplied
        throw ($PodeLocale.nameRequiredForEndpointIfRedirectToSuppliedExceptionMessage)
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
        # Invalid hostname supplied
        throw ($PodeLocale.invalidHostnameSuppliedExceptionMessage -f $Hostname)
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
        # An endpoint named has already been defined
        throw ($PodeLocale.endpointAlreadyDefinedExceptionMessage -f $Name)
    }

    # protocol must be https for client certs, or hosted behind a proxy like iis
    if (($Protocol -ine 'https') -and !(Test-PodeIsHosted) -and $AllowClientCertificate) {
        # Client certificates are only supported on HTTPS endpoints
        throw ($PodeLocale.clientCertificatesOnlySupportedOnHttpsEndpointsExceptionMessage)
    }

    # explicit tls is only supported for smtp/tcp
    if (($type -inotin @('smtp', 'tcp')) -and ($TlsMode -ieq 'explicit')) {
        # The Explicit TLS mode is only supported on SMTPS and TCPS endpoints
        throw ($PodeLocale.explicitTlsModeOnlySupportedOnSmtpsTcpsEndpointsExceptionMessage)
    }

    # ack message is only for smtp/tcp
    if (($type -inotin @('smtp', 'tcp')) -and ![string]::IsNullOrEmpty($Acknowledge)) {
        # The Acknowledge message is only supported on SMTP and TCP endpoints
        throw ($PodeLocale.acknowledgeMessageOnlySupportedOnSmtpTcpEndpointsExceptionMessage)
    }

    # crlf message end is only for tcp
    if (($type -ine 'tcp') -and $CRLFMessageEnd) {
        # The CRLF message end check is only supported on TCP endpoints
        throw ($PodeLocale.crlfMessageEndCheckOnlySupportedOnTcpEndpointsExceptionMessage)
    }

    # new endpoint object
    $obj = @{
        Name         = $Name
        Description  = $Description
        DualMode     = $DualMode
        Address      = $null
        RawAddress   = $null
        Port         = $null
        IsIPAddress  = $true
        HostName     = $Hostname
        FriendlyName = $Hostname
        Url          = $null
        Ssl          = @{
            Enabled   = (@('https', 'wss', 'smtps', 'tcps') -icontains $Protocol)
            Protocols = $PodeContext.Server.Sockets.Ssl.Protocols
        }
        Protocol     = $Protocol.ToLowerInvariant()
        Type         = $type.ToLowerInvariant()
        Runspace     = @{
            PoolName = (Get-PodeEndpointRunspacePoolName -Protocol $Protocol)
        }
        Default      = $Default.IsPresent
        Certificate  = @{
            Raw                    = $X509Certificate
            SelfSigned             = $SelfSigned
            AllowClientCertificate = $AllowClientCertificate
            TlsMode                = $TlsMode
        }
        Tcp          = @{
            Acknowledge    = $Acknowledge
            CRLFMessageEnd = $CRLFMessageEnd
        }
    }

    # set ssl protocols
    if (!(Test-PodeIsEmpty $SslProtocol)) {
        $obj.Ssl.Protocols = (ConvertTo-PodeSslProtocol -Protocol $SslProtocol)
    }

    # set the ip for the context (force to localhost for IIS)
    $obj.Address = Get-PodeIPAddress $_endpoint.Host -DualMode:$DualMode
    $obj.IsIPAddress = [string]::IsNullOrWhiteSpace($obj.HostName)

    if ($obj.IsIPAddress) {
        if (!(Test-PodeIPAddressLocalOrAny -IP $obj.Address)) {
            $obj.FriendlyName = "$($obj.Address)"
        }
        else {
            $obj.FriendlyName = 'localhost'
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
        # Must be running with administrator privileges to listen on non-localhost addresses
        throw ($PodeLocale.mustBeRunningWithAdminPrivilegesExceptionMessage)
    }

    # has this endpoint been added before? (for http/https we can just not add it again)
    $exists = ($PodeContext.Server.Endpoints.Values | Where-Object {
        ($_.FriendlyName -ieq $obj.FriendlyName) -and ($_.Port -eq $obj.Port) -and ($_.Ssl.Enabled -eq $obj.Ssl.Enabled) -and ($_.Type -ieq $obj.Type)
        } | Measure-Object).Count

    # if we're dealing with a certificate, attempt to import it
    if (!(Test-PodeIsHosted) -and ($PSCmdlet.ParameterSetName -ilike 'cert*')) {
        # fail if protocol is not https
        if (@('https', 'wss', 'smtps', 'tcps') -inotcontains $Protocol) {
            # Certificate supplied for non-HTTPS/WSS endpoint
            throw ($PodeLocale.certificateSuppliedForNonHttpsWssEndpointExceptionMessage)
        }

        switch ($PSCmdlet.ParameterSetName.ToLowerInvariant()) {
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
            # The certificate has expired
            throw ($PodeLocale.certificateExpiredExceptionMessage -f $obj.Certificate.Raw.Subject, $obj.Certificate.Raw.NotAfter)
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
            # An endpoint named has not been defined for redirecting
            throw ($PodeLocale.endpointNotDefinedForRedirectingExceptionMessage -f $RedirectTo)
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
function Get-PodeEndpoint {
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
        [ValidateSet('', 'Http', 'Https', 'Smtp', 'Smtps', 'Tcp', 'Tcps', 'Ws', 'Wss')]
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

<#
.SYNOPSIS
Sets the path for a specified default folder type in the Pode server context.

.DESCRIPTION
This function configures the path for one of the Pode server's default folder types: Views, Public, or Errors.
It updates the server's configuration to reflect the new path for the specified folder type.
The function first checks if the provided path exists and is a directory;
if so, it updates the `Server.DefaultFolders` dictionary with the new path.
If the path does not exist or is not a directory, the function throws an error.

The purpose of this function is to allow dynamic configuration of the server's folder paths, which can be useful during server setup or when altering the server's directory structure at runtime.

.PARAMETER Type
The type of the default folder to set the path for. Must be one of 'Views', 'Public', or 'Errors'.
This parameter determines which default folder's path is being set.

.PARAMETER Path
The new file system path for the specified default folder type. This path must exist and be a directory; otherwise, an exception is thrown.

.EXAMPLE
Set-PodeDefaultFolder -Type 'Views' -Path 'C:\Pode\Views'

This example sets the path for the server's default 'Views' folder to 'C:\Pode\Views', assuming this path exists and is a directory.

.EXAMPLE
Set-PodeDefaultFolder -Type 'Public' -Path 'C:\Pode\Public'

This example sets the path for the server's default 'Public' folder to 'C:\Pode\Public'.

#>
function Set-PodeDefaultFolder {

    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateSet('Views', 'Public', 'Errors')]
        [string]
        $Type,

        [Parameter()]
        [string]
        $Path
    )
    if (Test-Path -Path $Path -PathType Container) {
        $PodeContext.Server.DefaultFolders[$Type] = $Path
    }
    else {
        # Path does not exist
        throw ($PodeLocale.pathNotExistExceptionMessage -f $Path)
    }
}

<#
.SYNOPSIS
Retrieves the path of a specified default folder type from the Pode server context.

.DESCRIPTION
This function returns the path for one of the Pode server's default folder types: Views, Public, or Errors. It accesses the server's configuration stored in the `$PodeContext` variable and retrieves the path for the specified folder type from the `DefaultFolders` dictionary. This function is useful for scripts or modules that need to dynamically access server resources based on the server's current configuration.

.PARAMETER Type
The type of the default folder for which to retrieve the path. The valid options are 'Views', 'Public', or 'Errors'. This parameter determines which folder's path will be returned by the function.

.EXAMPLE
$path = Get-PodeDefaultFolder -Type 'Views'

This example retrieves the current path configured for the server's 'Views' folder and stores it in the `$path` variable.

.EXAMPLE
$path = Get-PodeDefaultFolder -Type 'Public'

This example retrieves the current path configured for the server's 'Public' folder.

.OUTPUTS
String. The file system path of the specified default folder.
#>
function Get-PodeDefaultFolder {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter()]
        [ValidateSet('Views', 'Public', 'Errors')]
        [string]
        $Type
    )

    return $PodeContext.Server.DefaultFolders[$Type]
}

<#
.SYNOPSIS
Attaches a breakpoint which can be used for debugging.

.DESCRIPTION
Attaches a breakpoint which can be used for debugging.

.EXAMPLE
Wait-PodeDebugger
#>
function Wait-PodeDebugger {
    [CmdletBinding()]
    param()

    if (!$PodeContext.Server.Debug.Breakpoints.Enabled) {
        return
    }

    Wait-Debugger
}