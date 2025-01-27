<#
.SYNOPSIS
    Starts a Pode server with the supplied script block or file containing the server logic.

.DESCRIPTION
    This function initializes and starts a Pode server based on the provided configuration.
    It supports both inline script blocks and external files for defining server logic.
    The server's behavior, console output, and various features can be customized using parameters.
    Additionally, it manages server termination, cancellation, and cleanup processes.

.PARAMETER ScriptBlock
    The main logic for the server, provided as a script block.

.PARAMETER FilePath
    A literal or relative path to a file containing the server's logic.
    The directory of this file will be used as the server's root path unless a specific -RootPath is supplied.

.PARAMETER Interval
    Specifies the interval in seconds for invoking the script block in 'Service' type servers.

.PARAMETER Name
    An optional name for the server, useful for identification in logs and future extensions.

.PARAMETER Threads
    The number of threads to allocate for Web, SMTP, and TCP servers. Defaults to 1.

.PARAMETER RootPath
    Overrides the server's root path. If not provided, the root path will be derived from the file path or the current working directory.

.PARAMETER Request
    Provides request details for serverless environments that Pode can parse and use.

.PARAMETER ServerlessType
    Specifies the serverless type for Pode. Valid values are:
    - AzureFunctions
    - AwsLambda

.PARAMETER StatusPageExceptions
    Controls the visibility of stack traces on status pages. Valid values are:
    - Show
    - Hide

.PARAMETER ListenerType
    Specifies a custom socket listener. Defaults to Pode's inbuilt listener.

.PARAMETER EnablePool
    Configures specific runspace pools (e.g., Timers, Schedules, Tasks, WebSockets, Files) for ad-hoc usage.

.PARAMETER Browse
    Opens the default web endpoint in the browser upon server start.

.PARAMETER CurrentPath
    Sets the server's root path to the current working directory. Only applicable when -FilePath is used.

.PARAMETER EnableBreakpoints
    Enables breakpoints created using `Wait-PodeDebugger`.

.PARAMETER DisableTermination
    Prevents termination, suspension, or resumption of the server via console commands.

.PARAMETER DisableConsoleInput
    Disables all console interactions for the server.

.PARAMETER ClearHost
    Clears the console screen whenever the server state changes (e.g., running → suspend → resume).

.PARAMETER Quiet
    Suppresses all output from the server.

.PARAMETER HideOpenAPI
    Hides OpenAPI details such as specification and documentation URLs from the console output.

.PARAMETER HideEndpoints
    Hides the list of active endpoints from the console output.

.PARAMETER ShowHelp
    Displays a help menu in the console with available control commands.

.PARAMETER IgnoreServerConfig
    Prevents the server from loading settings from the server.psd1 configuration file.

.PARAMETER ConfigFile
    Specifies a custom configuration file instead of using the default `server.psd1`.

.PARAMETER Daemon
    Configures the server to run as a daemon with minimal console interaction and output.

.EXAMPLE
    Start-PodeServer { /* server logic */ }
    Starts a Pode server using the supplied script block.

.EXAMPLE
    Start-PodeServer -FilePath './server.ps1' -Browse
    Starts a Pode server using the logic defined in an external file and opens the default endpoint in the browser.

.EXAMPLE
    Start-PodeServer -ServerlessType AwsLambda -Request $LambdaInput { /* server logic */ }
    Starts a Pode server in a serverless environment, using AWS Lambda input.

.EXAMPLE
    Start-PodeServer -HideOpenAPI -ClearHost { /* server logic */ }
    Starts a Pode server with console output configured to hide OpenAPI details and clear the console on state changes.

.NOTES
    This function is part of the Pode framework and is responsible for server initialization, configuration,
    request handling, and cleanup. It supports both standalone and serverless deployments, and provides
    extensive customization options for developers.
#>
function Start-PodeServer {
    [CmdletBinding(DefaultParameterSetName = 'Script')]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0, ParameterSetName = 'Script')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ScriptDaemon')]
        [scriptblock]
        $ScriptBlock,

        [Parameter(Mandatory = $true, ParameterSetName = 'File')]
        [Parameter(Mandatory = $true, ParameterSetName = 'FileDaemon')]
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

        [Parameter(ParameterSetName = 'File')]
        [Parameter(ParameterSetName = 'Script')]
        [switch]
        $Browse,

        [Parameter(Mandatory = $true, ParameterSetName = 'FileDaemon')]
        [Parameter(ParameterSetName = 'File')]
        [switch]
        $CurrentPath,

        [Parameter(ParameterSetName = 'File')]
        [Parameter(ParameterSetName = 'Script')]
        [switch]
        $EnableBreakpoints,

        [Parameter(ParameterSetName = 'File')]
        [Parameter(ParameterSetName = 'Script')]
        [switch]
        $DisableTermination,

        [Parameter(ParameterSetName = 'File')]
        [Parameter(ParameterSetName = 'Script')]
        [switch]
        $Quiet,

        [Parameter(ParameterSetName = 'File')]
        [Parameter(ParameterSetName = 'Script')]
        [switch]
        $DisableConsoleInput,

        [switch]
        $ClearHost,

        [switch]
        $HideOpenAPI,

        [switch]
        $HideEndpoints,

        [switch]
        $ShowHelp,

        [switch]
        $IgnoreServerConfig,

        [string]
        $ConfigFile,

        [Parameter(Mandatory = $true, ParameterSetName = 'FileDaemon')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ScriptDaemon')]
        [switch]
        $Daemon
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

        # Store the name of the current runspace
        $previousRunspaceName = Get-PodeCurrentRunspaceName
        # Sets the name of the current runspace
        Set-PodeCurrentRunspaceName -Name 'PodeServer'

        # ensure the session is clean
        $Script:PodeContext = $null
        $ShowDoneMessage = $true

        # check if podeWatchdog is configured
        if ($PodeService) {
            if ($null -ne $PodeService.DisableTermination -or
                $null -ne $PodeService.Quiet -or
                $null -ne $PodeService.PipeName -or
                $null -ne $PodeService.DisableConsoleInput
            ) {
                $DisableTermination = [switch]$PodeService.DisableTermination
                $Quiet = [switch]$PodeService.Quiet
                $DisableConsoleInput = [switch]$PodeService.DisableConsoleInput
                $IgnoreServerConfig = [switch]$PodeService.IgnoreServerConfig

                if (!([string]::IsNullOrEmpty($PodeService.ConfigFile)) -and !$PodeService.IgnoreServerConfig) {
                    $ConfigFile = $PodeService.ConfigFile
                }

                $monitorService = @{
                    DisableTermination  = $PodeService.DisableTermination
                    Quiet               = $PodeService.Quiet
                    PipeName            = $PodeService.PipeName
                    DisableConsoleInput = $PodeService.DisableConsoleInput
                    ConfigFile          = $PodeService.ConfigFile
                    IgnoreServerConfig  = $PodeService.IgnoreServerConfig
                }
                Write-PodeHost $PodeService -Explode -Force            }
        }

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


            # Define parameters for the context creation
            $ContextParams = @{
                ScriptBlock          = $ScriptBlock
                FilePath             = $FilePath
                Threads              = $Threads
                Interval             = $Interval
                ServerRoot           = Protect-PodeValue -Value $RootPath -Default $MyInvocation.PSScriptRoot
                ServerlessType       = $ServerlessType
                ListenerType         = $ListenerType
                EnablePool           = $EnablePool
                StatusPageExceptions = $StatusPageExceptions
                Console              = Get-PodeDefaultConsole
                EnableBreakpoints    = $EnableBreakpoints
                IgnoreServerConfig   = $IgnoreServerConfig
                ConfigFile           = $ConfigFile
                Service              = $monitorService
            }


            # Create main context object
            $PodeContext = New-PodeContext @ContextParams

            # Define parameter values with comments explaining each one
            $ConfigParameters = @{
                DisableTermination  = $DisableTermination   # Disable termination of the Pode server from the console
                DisableConsoleInput = $DisableConsoleInput  # Disable input from the console for the Pode server
                Quiet               = $Quiet                # Enable quiet mode, suppressing console output
                ClearHost           = $ClearHost            # Clear the host on startup
                HideOpenAPI         = $HideOpenAPI          # Hide the OpenAPI documentation display
                HideEndpoints       = $HideEndpoints        # Hide the endpoints list display
                ShowHelp            = $ShowHelp             # Show help information in the console
                Daemon              = $Daemon               # Enable daemon mode, combining multiple configurations
            }

            # Call the function using splatting
            Set-PodeConsoleOverrideConfiguration @ConfigParameters

            # start the file monitor for interally restarting
            Start-PodeFileMonitor

            # start the server
            Start-PodeInternalServer -Request $Request -Browse:$Browse

            # at this point, if it's just a one-one off script, return
            if (!(Test-PodeServerKeepOpen)) {
                return
            }

            # Sit in a loop waiting for server termination/cancellation or a restart request.
            while (!(Test-PodeCancellationTokenRequest -Type Terminate)) {
                # Retrieve the current state of the server (e.g., Running, Suspended).
                $serverState = Get-PodeServerState

                # If console input is not disabled, invoke any actions based on console commands.
                if (!$PodeContext.Server.Console.DisableConsoleInput) {
                    Invoke-PodeConsoleAction -ServerState $serverState
                }

                # Resolve cancellation token requests (e.g., Restart, Enable/Disable, Suspend/Resume).
                Resolve-PodeCancellationToken

                # Pause for 1 second before re-checking the state and processing the next action.
                Start-Sleep -Seconds 1
            }


            if ($PodeContext.Server.IsIIS -and $PodeContext.Server.IIS.Shutdown) {
                # (IIS Shutdown)
                Write-PodeHost $PodeLocale.iisShutdownMessage -NoNewLine -ForegroundColor Yellow
                Write-PodeHost ' ' -NoNewLine
            }

            # Terminating...
            Invoke-PodeEvent -Type Terminate
            Close-PodeServer
            Show-PodeConsoleInfo
        }
        catch {
            $_ | Write-PodeErrorLog

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
            Close-PodeServerInternal

            Show-PodeConsoleInfo

            # Restore the name of the current runspace
            Set-PodeCurrentRunspaceName -Name $previousRunspaceName

            if (($ShowDoneMessage -and ($PodeContext.Server.Types.Length -gt 0) -and !$PodeContext.Server.IsServerless)) {
                Write-PodeHost $PodeLocale.doneMessage -ForegroundColor Green
            }

            # clean the session
            $PodeContext = $null
            $PodeLocale = $null
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

    Close-PodeCancellationTokenRequest -Type Cancellation, Terminate
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

    # Only if the Restart feature is anabled
    if ($PodeContext.Server.AllowedActions.Restart) {
        Close-PodeCancellationTokenRequest -Type Restart
    }
}


<#
.SYNOPSIS
    Resumes the Pode server from a suspended state.

.DESCRIPTION
    This function resumes the Pode server, ensuring all associated runspaces are restored to their normal execution state.
    It triggers the 'Resume' event, updates the server's suspended status, and clears the host for a refreshed console view.

.PARAMETER Timeout
    The maximum time, in seconds, to wait for each runspace to be recovered before timing out. Default is 30 seconds.

.EXAMPLE
    Resume-PodeServer
    # Resumes the Pode server after a suspension.

#>
function Resume-PodeServer {
    [CmdletBinding()]
    param(
        [int]
        $Timeout
    )
    # Only if the Suspend feature is anabled
    if ($PodeContext.Server.AllowedActions.Suspend) {
        if ($Timeout) {
            $PodeContext.Server.AllowedActions.Timeout.Resume = $Timeout
        }

        if ((Test-PodeServerState -State Suspended)) {
            Set-PodeResumeToken
        }
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
    Suspend-PodeServer
    # Suspends the Pode server with a timeout of 60 seconds.

#>
function Suspend-PodeServer {
    [CmdletBinding()]
    param(
        [int]
        $Timeout
    )
    # Only if the Suspend feature is anabled
    if ($PodeContext.Server.AllowedActions.Suspend) {
        if ($Timeout) {
            $PodeContext.Server.AllowedActions.Timeout.Suspend = $Timeout
        }
        if (!(Test-PodeServerState -State Suspended)) {
            Set-PodeSuspendToken
        }
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


<#
.SYNOPSIS
    Retrieves the current state of the Pode server.

.DESCRIPTION
    The Get-PodeServerState function evaluates the internal state of the Pode server based on the cancellation tokens available
    in the $PodeContext. The function determines if the server is running, terminating, restarting, suspending, resuming, or
    in any other predefined state.

.OUTPUTS
    [string] - The state of the Pode server as one of the following values:
               'Terminated', 'Terminating', 'Resuming', 'Suspending', 'Suspended', 'Restarting', 'Starting', 'Running'.

.EXAMPLE
    Get-PodeServerState

    Retrieves the current state of the Pode server and returns it as a string.
#>
function Get-PodeServerState {
    [CmdletBinding()]
    [OutputType([Pode.PodeServerState])]
    param()
    # Check if PodeContext or its Tokens property is null; if so, consider the server terminated
    if ($null -eq $PodeContext -or $null -eq $PodeContext.Tokens) {
        return [Pode.PodeServerState]::Terminated
    }

    # Check if the server is in the process of terminating
    if (Test-PodeCancellationTokenRequest -Type Terminate) {
        return [Pode.PodeServerState]::Terminating
    }

    # Check if the server is resuming from a suspended state
    if (Test-PodeCancellationTokenRequest -Type Resume) {
        return [Pode.PodeServerState]::Resuming
    }

    # Check if the server is in the process of restarting
    if (Test-PodeCancellationTokenRequest -Type Restart) {
        return [Pode.PodeServerState]::Restarting
    }

    # Check if the server is suspending or already suspended
    if (Test-PodeCancellationTokenRequest -Type Suspend) {
        if (Test-PodeCancellationTokenRequest -Type Cancellation) {
            return [Pode.PodeServerState]::Suspending
        }
        return [Pode.PodeServerState]::Suspended
    }

    # Check if the server is starting
    if (!(Test-PodeCancellationTokenRequest -Type Start)) {
        return [Pode.PodeServerState]::Starting
    }

    # If none of the above, assume the server is running
    return [Pode.PodeServerState]::Running
}

<#
.SYNOPSIS
    Tests whether the Pode server is in a specified state.

.DESCRIPTION
    The `Test-PodeServerState` function checks the current state of the Pode server
    by calling `Get-PodeServerState` and comparing the result to the specified state.
    The function returns `$true` if the server is in the specified state and `$false` otherwise.

.PARAMETER State
    Specifies the server state to test. Allowed values are:
    - `Terminated`: The server is not running, and the context is null.
    - `Terminating`: The server is in the process of shutting down.
    - `Resuming`: The server is resuming from a suspended state.
    - `Suspending`: The server is in the process of entering a suspended state.
    - `Suspended`: The server is fully suspended.
    - `Restarting`: The server is restarting.
    - `Starting`: The server is in the process of starting up.
    - `Running`: The server is actively running.

.EXAMPLE
    Test-PodeServerState -State 'Running'

    Returns `$true` if the server is currently running, otherwise `$false`.

.EXAMPLE
    Test-PodeServerState -State 'Suspended'

    Returns `$true` if the server is fully suspended, otherwise `$false`.

.NOTES
    This function is part of Pode's server state management utilities.
    It relies on the `Get-PodeServerState` function to determine the current state.
#>
function Test-PodeServerState {
    param(
        [Parameter(Mandatory = $true)]
        [Pode.PodeServerState]
        $State
    )

    # Call Get-PodeServerState to retrieve the current server state
    $currentState = Get-PodeServerState

    # Return true if the current state matches the provided state, otherwise false
    return $currentState -eq $State
}

<#
.SYNOPSIS
	Enables new incoming requests by removing the middleware that blocks requests when the Pode Watchdog client is active.

.DESCRIPTION
	This function resets the cancellation token for the Disable action, allowing the Pode server to accept new incoming requests.
#>
function Enable-PodeServer {
    if (Test-PodeCancellationTokenRequest -Type Disable) {
        Reset-PodeCancellationToken -Type Disable
    }
}

<#
.SYNOPSIS
	Blocks new incoming requests by adding middleware that returns a 503 Service Unavailable status when the Pode Watchdog client is active.

.DESCRIPTION
	This function integrates middleware into the Pode server, preventing new incoming requests while the Pode Watchdog client is active.
	All requests receive a 503 Service Unavailable response, including a 'Retry-After' header that specifies when the service will become available.

.PARAMETER RetryAfter
	Specifies the time in seconds clients should wait before retrying their requests. Default is 3600 seconds (1 hour).
#>
function Disable-PodeServer {
    param (
        [Parameter(Mandatory = $false)]
        [int]$RetryAfter = 3600
    )

    $PodeContext.Server.AllowedActions.DisableSettings.RetryAfter = $RetryAfter
    if (! (Test-PodeCancellationTokenRequest -Type Disable)) {
        Close-PodeCancellationTokenRequest -Type Disable
    }
}


