using namespace Pode

function New-PodeContext {
    [CmdletBinding()]
    param(
        [Parameter()]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [string]
        $FilePath,

        [Parameter()]
        [int]
        $Threads = 1,

        [Parameter()]
        [int]
        $Interval = 0,

        [Parameter()]
        [string]
        $ServerRoot,

        [Parameter()]
        [string]
        $Name = $null,

        [Parameter()]
        [string]
        $ServerlessType,

        [Parameter()]
        [string]
        $StatusPageExceptions,

        [Parameter()]
        [string]
        $ListenerType,

        [Parameter()]
        [string[]]
        $EnablePool,

        [hashtable]
        $Console,

        [switch]
        $EnableBreakpoints,

        [switch]
        $IgnoreServerConfig,

        [string]
        $ConfigFile
    )

    # set a random server name if one not supplied
    if (Test-PodeIsEmpty $Name) {
        $Name = Get-PodeRandomName
    }

    # are we running in a serverless context
    $isServerless = ![string]::IsNullOrWhiteSpace($ServerlessType)

    # ensure threads are always >0, for to 1 if we're serverless
    if (($Threads -le 0) -or $isServerless) {
        $Threads = 1
    }

    # basic context object
    $ctx = [PSCustomObject]@{
        Threads       = @{}
        Timers        = @{}
        Schedules     = @{}
        Tasks         = @{}
        RunspacePools = $null
        Runspaces     = $null
        RunspaceState = $null
        Tokens        = @{}
        LogsToProcess = $null
        Threading     = @{}
        Server        = @{}
        Metrics       = @{}
        Listeners     = @()
        Receivers     = @()
        Watchers      = @()
        Fim           = @{}
    }

    # set the server name, logic and root, and other basic properties
    $ctx.Server.Name = $Name
    $ctx.Server.Logic = $ScriptBlock
    $ctx.Server.LogicPath = $FilePath
    $ctx.Server.Interval = $Interval
    $ctx.Server.PodeModule = (Get-PodeModuleInfo)
    $ctx.Server.Console = $Console
    $ctx.Server.ComputerName = [System.Net.DNS]::GetHostName()

    # list of created listeners/receivers
    $ctx.Listeners = @()
    $ctx.Receivers = @()
    $ctx.Watchers = @()

    # default secret that can used when needed, and a secret isn't supplied
    $ctx.Server.DefaultSecret = New-PodeGuid -Secure

    # list of timers/schedules/tasks/fim
    $ctx.Timers = @{
        Enabled = ($EnablePool -icontains 'timers')
        Items   = @{}
    }

    $ctx.Schedules = @{
        Enabled   = ($EnablePool -icontains 'schedules')
        Items     = @{}
        Processes = @{}
    }

    $ctx.Tasks = @{
        Enabled   = ($EnablePool -icontains 'tasks')
        Items     = @{}
        Processes = @{}
    }

    $ctx.Fim = @{
        Enabled = ($EnablePool -icontains 'files')
        Items   = @{}
    }

    # auto importing (modules, funcs, snap-ins)
    $ctx.Server.AutoImport = Initialize-PodeAutoImportConfiguration

    # basic logging setup
    $ctx.Server.Logging = @{
        Enabled = $true
        Types   = @{}
    }

    # set thread counts
    $ctx.Threads = @{
        General    = $Threads
        Schedules  = 10
        Files      = 1
        Tasks      = 2
        WebSockets = 2
        Timers     = 1
    }

    # set socket details for pode server
    $ctx.Server.Sockets = @{
        Ssl            = @{
            Protocols = Get-PodeDefaultSslProtocol
        }
        ReceiveTimeout = 100
    }

    $ctx.Server.Signals = @{
        Enabled  = $false
        Listener = $null
    }

    $ctx.Server.Http = @{
        Listener = $null
    }

    $ctx.Server.Sse = @{
        Signed         = $false
        Secret         = $null
        Strict         = $false
        DefaultScope   = 'Global'
        BroadcastLevel = @{}
    }

    $ctx.Server.WebSockets = @{
        Enabled     = ($EnablePool -icontains 'websockets')
        Receiver    = $null
        Connections = @{}
    }

    # set default request config
    $ctx.Server.Request = @{
        Timeout  = 30
        BodySize = 100MB
    }

    # default Folders
    $ctx.Server.DefaultFolders = @{
        Views  = 'views'
        Public = 'public'
        Errors = 'errors'
    }

    $ctx.Server.Debug = @{
        Breakpoints = @{
            Enabled = $false
        }
    }

    $ctx.Server.AllowedActions = @{
        Suspend         = $true
        Restart         = $true
        Disable         = $true
        DisableSettings = @{
            RetryAfter    = 3600
            LimitRuleName = '__Pode_Disable_Code_503__'
        }
        Timeout         = @{
            Suspend = 30
            Resume  = 30
        }
    }

    # Load the server configuration based on the provided parameters.
    # If $IgnoreServerConfig is set, an empty configuration (@{}) is assigned; otherwise, the configuration is loaded using Open-PodeConfiguration.
    $ctx.Server.Configuration = if ($IgnoreServerConfig) { @{} }
    else {
        Open-PodeConfiguration -ServerRoot $ServerRoot -Context $ctx -ConfigFile $ConfigFile
    }

    # Set the 'Enabled' property of the server configuration.
    # This is based on whether $IgnoreServerConfig is explicitly present (false if present, true otherwise).
    $ctx.Server.Configuration.Enabled = ! $IgnoreServerConfig.IsPresent

    # Assign the specified configuration file path (if any) to the 'ConfigFile' property of the server configuration.
    # This allows tracking which configuration file was used, even if overridden.
    $ctx.Server.Configuration.ConfigFile = $ConfigFile

    # over status page exceptions
    if (!(Test-PodeIsEmpty $StatusPageExceptions)) {
        if ($null -eq $ctx.Server.Web) {
            $ctx.Server.Web = @{ ErrorPages = @{} }
        }

        $ctx.Server.Web.ErrorPages.ShowExceptions = ($StatusPageExceptions -eq 'show')
    }

    # configure the server's root path
    $ctx.Server.Root = $ServerRoot
    if (!(Test-PodeIsEmpty $ctx.Server.Configuration.Server.Root)) {
        $ctx.Server.Root = Get-PodeRelativePath -Path $ctx.Server.Configuration.Server.Root -RootPath $ctx.Server.Root -JoinRoot -Resolve -TestPath
    }

    if (Test-PodeIsEmpty $ctx.Server.Root) {
        $ctx.Server.Root = $PWD.Path
    }

    # debugging
    if ($EnableBreakpoints) {
        $ctx.Server.Debug.Breakpoints.Enabled = $EnableBreakpoints.IsPresent
    }

    # set the server's listener type
    $ctx.Server.ListenerType = $ListenerType

    # set serverless info
    $ctx.Server.ServerlessType = $ServerlessType
    $ctx.Server.IsServerless = $isServerless
    if ($isServerless) {
        $ctx.Server.Console.DisableTermination = $true
    }

    # set the server types
    $ctx.Server.IsService = ($Interval -gt 0)
    $ctx.Server.Types = @()

    # is the server running under IIS? (also, disable termination)
    $ctx.Server.IsIIS = (!$isServerless -and (!(Test-PodeIsEmpty $env:ASPNETCORE_PORT)) -and (!(Test-PodeIsEmpty $env:ASPNETCORE_TOKEN)))
    if ($ctx.Server.IsIIS) {
        # set iis token/settings
        $ctx.Server.IIS = @{
            Token    = $env:ASPNETCORE_TOKEN
            Port     = $env:ASPNETCORE_PORT
            Path     = @{
                Raw       = '/'
                Pattern   = '^/'
                IsNonRoot = $false
            }
            Shutdown = $false
        }

        if (![string]::IsNullOrWhiteSpace($env:ASPNETCORE_APPL_PATH) -and ($env:ASPNETCORE_APPL_PATH -ne '/')) {
            $ctx.Server.IIS.Path.Raw = $env:ASPNETCORE_APPL_PATH
            $ctx.Server.IIS.Path.Pattern = "^$($env:ASPNETCORE_APPL_PATH)"
            $ctx.Server.IIS.Path.IsNonRoot = $true
        }
    }

    # is the server running under Heroku?
    $ctx.Server.IsHeroku = (!$isServerless -and (!(Test-PodeIsEmpty $env:PORT)) -and (!(Test-PodeIsEmpty $env:DYNO)))

    # Check if the current session is running in a console-like environment
    if (Test-PodeHasConsole) {
        try {
            if (! (Test-PodeIsISEHost)) {
                # If the session is not configured for quiet mode, modify console behavior
                if (!$ctx.Server.Console.Quiet) {
                    # Hide the cursor to improve the console appearance
                    [System.Console]::CursorVisible = $false

                    # If the divider line should be shown, configure UTF-8 output encoding
                    if ($ctx.Server.Console.ShowDivider) {
                        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
                    }
                }
                if (Test-PodeIsConsoleHost) {
                    # Treat Ctrl+C as input instead of terminating the process
                    [Console]::TreatControlCAsInput = $true
                }
            }
        }
        catch {
            $_ | Write-PodeErrorLog
            # Console support is partial , configure the context for non-console behavior
            $ctx.Server.Console.DisableTermination = $true  # Prevent termination
            $ctx.Server.Console.DisableConsoleInput = $true # Disable console input
            $ctx.Server.Console.Quiet = $true               # Silence the console
            $ctx.Server.Console.ShowDivider = $false        # Disable divider display
        }

    }
    else {
        # If not running in a console-like environment, configure the context for non-console behavior
        $ctx.Server.Console.DisableTermination = $true  # Prevent termination
        $ctx.Server.Console.DisableConsoleInput = $true # Disable console input
        $ctx.Server.Console.Quiet = $true               # Silence the console
        $ctx.Server.Console.ShowDivider = $false        # Disable divider display
    }

    # set the IP address details
    $ctx.Server.Endpoints = @{}
    $ctx.Server.EndpointsMap = @{}

    # general encoding for the server
    $ctx.Server.Encoding = [System.Text.UTF8Encoding]::new()

    # setup gui details
    $ctx.Server.Gui = @{}

    # shared temp drives
    $ctx.Server.Drives = @{}
    $ctx.Server.InbuiltDrives = @{}

    # shared state between runspaces
    $ctx.Server.State = @{}

    # setup caching
    $ctx.Server.Cache = @{
        Items          = @{}
        Storage        = @{}
        DefaultStorage = $null
        DefaultTtl     = 3600 # 1hr
    }

    # output details, like variables, to be set once the server stops
    $ctx.Server.Output = @{
        Variables = @{}
    }

    # view engine for rendering pages
    $ctx.Server.ViewEngine = @{
        Type           = 'html'
        Extension      = 'html'
        ScriptBlock    = $null
        UsingVariables = $null
        IsDynamic      = $false
    }

    # pode default preferences
    $ctx.Server.Preferences = @{
        Routes = @{
            IfExists = $null
        }
    }

    # routes for pages and api
    $ctx.Server.Routes = [ordered]@{
        # common methods
        'get'     = [ordered]@{}
        'post'    = [ordered]@{}
        'put'     = [ordered]@{}
        'patch'   = [ordered]@{}
        'delete'  = [ordered]@{}
        # other methods
        'connect' = [ordered]@{}
        'head'    = [ordered]@{}
        'merge'   = [ordered]@{}
        'options' = [ordered]@{}
        'trace'   = [ordered]@{}
        'static'  = [ordered]@{}
        'signal'  = [ordered]@{}
        '*'       = [ordered]@{}
    }

    # verbs for tcp
    $ctx.Server.Verbs = @{}

    # secrets
    $ctx.Server.Secrets = @{
        Vaults = @{}
        Keys   = @{}
    }

    # custom view paths
    $ctx.Server.Views = @{}

    # handlers for tcp
    $ctx.Server.Handlers = @{
        smtp    = @{}
        service = @{}
    }

    # setup basic access placeholders
    $ctx.Server.Access = @{
        Allow = @{}
        Deny  = @{}
    }

    # setup basic limit rules
    $ctx.Server.Limits = @{
        Rate   = @{
            Rules        = [ordered]@{}
            RuleOrder    = @()
            RulesAltered = $false
        }
        Access = @{
            Rules         = [ordered]@{}
            RuleOrder     = @()
            RulesAltered  = $false
            HaveAllowRule = $false
        }
    }

    # cookies and session logic
    $ctx.Server.Cookies = @{
        Csrf    = @{}
        Secrets = @{}
    }

    # sessions
    $ctx.Server.Sessions = @{}

    #OpenApi Definition Tag
    $ctx.Server.OpenAPI = Initialize-PodeOpenApiTable -DefaultDefinitionTag $ctx.Server.Web.OpenApi.DefaultDefinitionTag


    # server metrics
    $ctx.Metrics = @{
        Server   = @{
            InitialLoadTime = [datetime]::UtcNow
            StartTime       = [datetime]::UtcNow
            RestartCount    = 0
        }
        Requests = @{
            Total       = 0
            StatusCodes = @{}
        }
        Signals  = @{
            Total = 0
        }
    }

    # authentication and authorisation methods
    $ctx.Server.Authentications = @{
        Methods = @{}
    }

    $ctx.Server.Authorisations = @{
        Methods = @{}
    }

    # create new cancellation tokens
    $ctx.Tokens = Initialize-PodeCancellationToken

    # requests that should be logged
    $ctx.LogsToProcess = [System.Collections.ArrayList]::new()

    # middleware that needs to run
    $ctx.Server.Middleware = @()
    $ctx.Server.BodyParsers = @{}

    # common support values
    $ctx.Server.Compression = @{
        Encodings = @('gzip', 'deflate', 'x-gzip')
    }

    # endware that needs to run
    $ctx.Server.Endware = @()

    # runspace pools
    $ctx.RunspacePools = @{
        Main      = $null
        Web       = $null
        Smtp      = $null
        Tcp       = $null
        Signals   = $null
        Schedules = $null
        Gui       = $null
        Tasks     = $null
        Files     = $null
        Timers    = $null
    }

    # threading locks, etc.
    $ctx.Threading.Lockables = @{
        Global = [hashtable]::Synchronized(@{})
        Cache  = [hashtable]::Synchronized(@{})
        Custom = @{}
    }

    $ctx.Threading.Mutexes = @{}
    $ctx.Threading.Semaphores = @{}

    # setup runspaces
    $ctx.Runspaces = @()

    # setup events
    $ctx.Server.Events = @{
        Start     = [ordered]@{}
        Terminate = [ordered]@{}
        Restart   = [ordered]@{}
        Browser   = [ordered]@{}
        Crash     = [ordered]@{}
        Stop      = [ordered]@{}
        Running   = [ordered]@{}
    }

    # modules
    $ctx.Server.Modules = [ordered]@{}

    # setup security
    $ctx.Server.Security = @{
        ServerDetails = $true
        Headers       = @{}
        Cache         = @{
            ContentSecurity   = @{}
            PermissionsPolicy = @{}
        }
    }

    # scoped variables
    $ctx.Server.ScopedVariables = [ordered]@{}

    # an internal cache for adhoc values, such as module importing checks
    $ctx.Server.InternalCache = @{
        YamlModuleImported = $null
    }

    # return the new context
    return $ctx
}

function New-PodeRunspaceState {
    # create the state, and add the pode modules
    $state = [initialsessionstate]::CreateDefault()
    $state.ImportPSModule($PodeContext.Server.PodeModule.DataPath)
    $state.ImportPSModule($PodeContext.Server.PodeModule.InternalPath)

    # load the vars into the share state
    $session = New-PodeStateContext -Context $PodeContext

    $variables = @(
        [System.Management.Automation.Runspaces.SessionStateVariableEntry]::new('PodeLocale', $PodeLocale, $null),
        [System.Management.Automation.Runspaces.SessionStateVariableEntry]::new('PodeContext', $session, $null),
        [System.Management.Automation.Runspaces.SessionStateVariableEntry]::new('Console', $Host, $null),
        [System.Management.Automation.Runspaces.SessionStateVariableEntry]::new('PODE_SCOPE_RUNSPACE', $true, $null)
    )

    foreach ($var in $variables) {
        $state.Variables.Add($var)
    }

    $PodeContext.RunspaceState = $state
}

<#
.SYNOPSIS
    Creates and initializes runspace pools for various Pode components.

.DESCRIPTION
    This function sets up runspace pools for different Pode components, such as timers, schedules, web endpoints, web sockets, SMTP, TCP, and more. It dynamically adjusts the thread counts based on the presence of specific components and their configuration.

.OUTPUTS
    Initializes and configures runspace pools for various Pode components.
#>
function New-PodeRunspacePool {
    if ($PodeContext.Server.IsServerless) {
        return
    }

    # setup main runspace pool
    $threadsCounts = @{
        Default  = 3
        Log      = 1
        Schedule = 1
        Misc     = 1
    }

    if (!(Test-PodeSchedulesExist)) {
        $threadsCounts.Schedule = 0
    }

    if (!(Test-PodeLoggersExist)) {
        $threadsCounts.Log = 0
    }

    # main runspace - for timers, schedules, etc
    $totalThreadCount = ($threadsCounts.Values | Measure-Object -Sum).Sum
    $PodeContext.RunspacePools.Main = @{
        Pool   = [runspacefactory]::CreateRunspacePool(1, $totalThreadCount, $PodeContext.RunspaceState, $Host)
        State  = 'Waiting'
        LastId = 0
    }

    # web runspace - if we have any http/s endpoints
    if (Test-PodeEndpointByProtocolType -Type Http) {
        $PodeContext.RunspacePools.Web = @{
            Pool   = [runspacefactory]::CreateRunspacePool(1, ($PodeContext.Threads.General + 1), $PodeContext.RunspaceState, $Host)
            State  = 'Waiting'
            LastId = 0
        }
    }

    # smtp runspace - if we have any smtp endpoints
    if (Test-PodeEndpointByProtocolType -Type Smtp) {
        $PodeContext.RunspacePools.Smtp = @{
            Pool   = [runspacefactory]::CreateRunspacePool(1, ($PodeContext.Threads.General + 1), $PodeContext.RunspaceState, $Host)
            State  = 'Waiting'
            LastId = 0
        }
    }

    # tcp runspace - if we have any tcp endpoints
    if (Test-PodeEndpointByProtocolType -Type Tcp) {
        $PodeContext.RunspacePools.Tcp = @{
            Pool   = [runspacefactory]::CreateRunspacePool(1, ($PodeContext.Threads.General + 1), $PodeContext.RunspaceState, $Host)
            State  = 'Waiting'
            LastId = 0
        }
    }

    # signals runspace - if we have any ws/s endpoints
    if (Test-PodeEndpointByProtocolType -Type Ws) {
        $PodeContext.RunspacePools.Signals = @{
            Pool   = [runspacefactory]::CreateRunspacePool(1, ($PodeContext.Threads.General + 2), $PodeContext.RunspaceState, $Host)
            State  = 'Waiting'
            LastId = 0
        }
    }

    # web socket connections runspace - for receiving data for external sockets
    if (Test-PodeWebSocketsExist) {
        $PodeContext.RunspacePools.WebSockets = @{
            Pool   = [runspacefactory]::CreateRunspacePool(1, $PodeContext.Threads.WebSockets + 1, $PodeContext.RunspaceState, $Host)
            State  = 'Waiting'
            LastId = 0
        }

        New-PodeWebSocketReceiver
    }

    # setup timer runspace pool -if we have any timers
    if (Test-PodeTimersExist) {
        $PodeContext.RunspacePools.Timers = @{
            Pool   = [runspacefactory]::CreateRunspacePool(1, $PodeContext.Threads.Timers, $PodeContext.RunspaceState, $Host)
            State  = 'Waiting'
            LastId = 0
        }
    }

    # setup schedule runspace pool -if we have any schedules
    if (Test-PodeSchedulesExist) {
        $PodeContext.RunspacePools.Schedules = @{
            Pool   = [runspacefactory]::CreateRunspacePool(1, $PodeContext.Threads.Schedules, $PodeContext.RunspaceState, $Host)
            State  = 'Waiting'
            LastId = 0
        }
    }

    # setup tasks runspace pool -if we have any tasks
    if (Test-PodeTasksExist) {
        $PodeContext.RunspacePools.Tasks = @{
            Pool   = [runspacefactory]::CreateRunspacePool(1, $PodeContext.Threads.Tasks, $PodeContext.RunspaceState, $Host)
            State  = 'Waiting'
            LastId = 0
        }
    }

    # setup files runspace pool -if we have any file watchers
    if (Test-PodeFileWatchersExist) {
        $PodeContext.RunspacePools.Files = @{
            Pool   = [runspacefactory]::CreateRunspacePool(1, $PodeContext.Threads.Files + 1, $PodeContext.RunspaceState, $Host)
            State  = 'Waiting'
            LastId = 0
        }
    }

    # setup gui runspace pool (only for non-ps-core) - if gui enabled
    if (Test-PodeGuiEnabled) {
        $PodeContext.RunspacePools.Gui = @{
            Pool   = [runspacefactory]::CreateRunspacePool(1, 1, $PodeContext.RunspaceState, $Host)
            State  = 'Waiting'
            LastId = 0
        }

        $PodeContext.RunspacePools.Gui.Pool.ApartmentState = 'STA'
    }
}

<#
.SYNOPSIS
    Opens and initializes runspace pools for various Pode components.

.DESCRIPTION
    This function opens and initializes runspace pools for different Pode components, such as timers, schedules, web endpoints, web sockets, SMTP, TCP, and more. It asynchronously opens the pools and waits for them to be in the 'Opened' state. If any pool fails to open, it reports an error.

.OUTPUTS
    Opens and initializes runspace pools for various Pode components.
#>
function Open-PodeRunspacePool {
    if ($PodeContext.Server.IsServerless) {
        return
    }

    $start = [datetime]::Now
    Write-Verbose 'Opening RunspacePools'

    # open pools async
    foreach ($key in $PodeContext.RunspacePools.Keys) {
        $item = $PodeContext.RunspacePools[$key]
        if ($null -eq $item) {
            continue
        }

        $item.Pool.ThreadOptions = [System.Management.Automation.Runspaces.PSThreadOptions]::ReuseThread
        $item.Pool.CleanupInterval = [timespan]::FromMinutes(5)
        $item.Result = $item.Pool.BeginOpen($null, $null)
    }

    # wait for them all to open
    $queue = @($PodeContext.RunspacePools.Keys)

    while ($queue.Length -gt 0) {
        foreach ($key in $queue) {
            $item = $PodeContext.RunspacePools[$key]
            if ($null -eq $item) {
                $queue = ($queue | Where-Object { $_ -ine $key })
                continue
            }

            if ($item.Pool.RunspacePoolStateInfo.State -iin @('Opened', 'Broken')) {
                $queue = ($queue | Where-Object { $_ -ine $key })
                Write-Verbose "RunspacePool for $($key): $($item.Pool.RunspacePoolStateInfo.State) [duration: $(([datetime]::Now - $start).TotalSeconds)s]"
            }
        }

        if ($queue.Length -gt 0) {
            Start-Sleep -Milliseconds 100
        }
    }

    # report errors for failed pools
    foreach ($key in $PodeContext.RunspacePools.Keys) {
        $item = $PodeContext.RunspacePools[$key]
        if ($null -eq $item) {
            continue
        }

        if ($item.Pool.RunspacePoolStateInfo.State -ieq 'broken') {
            $item.Pool.EndOpen($item.Result) | Out-Default
            throw ($PodeLocale.failedToOpenRunspacePoolExceptionMessage -f $key) #"Failed to open RunspacePool: $($key)"
        }
    }

    Write-Verbose "RunspacePools opened [duration: $(([datetime]::Now - $start).TotalSeconds)s]"
}

<#
.SYNOPSIS
    Closes and disposes runspace pools for various Pode components.

.DESCRIPTION
    This function closes and disposes runspace pools for different Pode components, such as timers, schedules, web endpoints, web sockets, SMTP, TCP, and more. It asynchronously closes the pools and waits for them to be in the 'Closed' state. If any pool fails to close, it reports an error.

.OUTPUTS
    Closes and disposes runspace pools for various Pode components.
#>
function Close-PodeRunspacePool {
    if ($PodeContext.Server.IsServerless -or ($null -eq $PodeContext.RunspacePools)) {
        return
    }

    $start = [datetime]::Now
    Write-Verbose 'Closing RunspacePools'

    # close pools async
    foreach ($key in $PodeContext.RunspacePools.Keys) {
        $item = $PodeContext.RunspacePools[$key]
        if (($null -eq $item) -or ($item.Pool.IsDisposed)) {
            continue
        }

        $item.Result = $item.Pool.BeginClose($null, $null)
    }

    # wait for them all to close
    $queue = @($PodeContext.RunspacePools.Keys)

    while ($queue.Length -gt 0) {
        foreach ($key in $queue) {
            $item = $PodeContext.RunspacePools[$key]
            if ($null -eq $item) {
                $queue = ($queue | Where-Object { $_ -ine $key })
                continue
            }

            if ($item.Pool.RunspacePoolStateInfo.State -iin @('Closed', 'Broken')) {
                $queue = ($queue | Where-Object { $_ -ine $key })
                Write-Verbose "RunspacePool for $($key): $($item.Pool.RunspacePoolStateInfo.State) [duration: $(([datetime]::Now - $start).TotalSeconds)s]"
            }
        }

        if ($queue.Length -gt 0) {
            Start-Sleep -Milliseconds 100
        }
    }

    # report errors for failed pools
    foreach ($key in $PodeContext.RunspacePools.Keys) {
        $item = $PodeContext.RunspacePools[$key]
        if ($null -eq $item) {
            continue
        }

        if ($item.Pool.RunspacePoolStateInfo.State -ieq 'broken') {
            $item.Pool.EndClose($item.Result) | Out-Default
            # Failed to close RunspacePool
            throw ($PodeLocale.failedToCloseRunspacePoolExceptionMessage -f $key)
        }
    }

    # dispose pools
    foreach ($key in $PodeContext.RunspacePools.Keys) {
        $item = $PodeContext.RunspacePools[$key]
        if (($null -eq $item) -or ($item.Pool.IsDisposed)) {
            continue
        }

        Close-PodeDisposable -Disposable $item.Pool
    }

    Write-Verbose "RunspacePools closed [duration: $(([datetime]::Now - $start).TotalSeconds)s]"
}

function New-PodeStateContext {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        $Context
    )

    return [PSCustomObject]@{
        Threads       = $Context.Threads
        Timers        = $Context.Timers
        Schedules     = $Context.Schedules
        Tasks         = $Context.Tasks
        Fim           = $Context.Fim
        RunspacePools = $Context.RunspacePools
        Tokens        = $Context.Tokens
        Metrics       = $Context.Metrics
        LogsToProcess = $Context.LogsToProcess
        Threading     = $Context.Threading
        Server        = $Context.Server
    }
}
<#
.SYNOPSIS
    Opens and processes the Pode server configuration.

.DESCRIPTION
    This function handles loading the Pode server configuration file. It supports custom configurations specified by environment variables,
    a provided file path, or falls back to the default `server.psd1` file. The function sets the configuration for both the server and web contexts.

.PARAMETER ServerRoot
    Specifies the root directory of the server. Defaults to `$null` if not provided.

.PARAMETER Context
    Specifies the context to set configurations for Pode server and web.

.PARAMETER ConfigFile
    Allows specifying a custom configuration file path. If provided, it overrides any other configuration file.

.OUTPUTS
    Hashtable representing the loaded configuration.

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function Open-PodeConfiguration {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter()]
        [string]
        $ServerRoot = $null,

        [Parameter()]
        $Context,

        [Parameter()]
        [string]
        $ConfigFile
    )

    # Initialize an empty configuration hashtable
    $config = @{}

    # Set the path to the default root configuration file
    $configPath = (Join-PodeServerRoot -Folder '.' -FilePath 'server.psd1' -Root $ServerRoot)

    # Check for an environment-specific configuration file if the environment variable is set
    if (!(Test-PodeIsEmpty $env:PODE_ENVIRONMENT)) {
        $_path = (Join-PodeServerRoot -Folder '.' -FilePath "server.$($env:PODE_ENVIRONMENT).psd1" -Root $ServerRoot)
        if (Test-PodePath -Path $_path -NoStatus) {
            $configPath = $_path
        }
    }

    # Override the configuration path if a valid ConfigFile parameter is provided
    if (!([string]::IsNullOrEmpty($ConfigFile))) {
        #-and (Test-Path -Path $ConfigFile -PathType Leaf)) {
        $configPath = Get-PodeRelativePath -Path $ConfigFile -JoinRoot -Resolve -RootPath $ServerRoot -TestPath
    }

    # check the path exists, and load the config
    if (Test-PodePath -Path $configPath -NoStatus) {
        # Import the configuration from the file
        $config = Import-PowerShellDataFile -Path $configPath -ErrorAction Stop

        # Set the server and web configurations in the provided context
        Set-PodeServerConfiguration -Configuration $config.Server -Context $Context
        Set-PodeWebConfiguration -Configuration $config.Web -Context $Context
    }

    # Return the loaded configuration
    return $config
}

function Set-PodeServerConfiguration {
    param(
        [Parameter()]
        [hashtable]
        $Configuration,

        [Parameter()]
        $Context
    )

    # file monitoring
    $Context.Server.FileMonitor = @{
        Enabled   = [bool]$Configuration.FileMonitor.Enable
        Exclude   = (Convert-PodePathPatternsToRegex -Paths @($Configuration.FileMonitor.Exclude))
        Include   = (Convert-PodePathPatternsToRegex -Paths @($Configuration.FileMonitor.Include))
        ShowFiles = [bool]$Configuration.FileMonitor.ShowFiles
        Files     = @()
    }

    # logging
    $Context.Server.Logging = @{
        Enabled = (($null -eq $Configuration.Logging.Enable) -or [bool]$Configuration.Logging.Enable)
        Masking = @{
            Patterns = (Remove-PodeEmptyItemsFromArray -Array @($Configuration.Logging.Masking.Patterns))
            Mask     = (Protect-PodeValue -Value $Configuration.Logging.Masking.Mask -Default '********')
        }
        Types   = @{}
    }

    # sockets
    if (!(Test-PodeIsEmpty $Configuration.Ssl.Protocols)) {
        $Context.Server.Sockets.Ssl.Protocols = (ConvertTo-PodeSslProtocol -Protocol $Configuration.Ssl.Protocols)
    }

    if ([int]$Configuration.ReceiveTimeout -gt 0) {
        $Context.Server.Sockets.ReceiveTimeout = (Protect-PodeValue -Value $Configuration.ReceiveTimeout $Context.Server.Sockets.ReceiveTimeout)
    }

    # auto-import
    $Context.Server.AutoImport = Read-PodeAutoImportConfiguration -Configuration $Configuration

    # request
    if ([int]$Configuration.Request.Timeout -gt 0) {
        $Context.Server.Request.Timeout = [int]$Configuration.Request.Timeout
    }

    if ([long]$Configuration.Request.BodySize -gt 0) {
        $Context.Server.Request.BodySize = [long]$Configuration.Request.BodySize
    }

    # default folders
    if ($Configuration.DefaultFolders) {
        if ($Configuration.DefaultFolders.Public) {
            $Context.Server.DefaultFolders.Public = $Configuration.DefaultFolders.Public
        }
        if ($Configuration.DefaultFolders.Views) {
            $Context.Server.DefaultFolders.Views = $Configuration.DefaultFolders.Views
        }
        if ($Configuration.DefaultFolders.Errors) {
            $Context.Server.DefaultFolders.Errors = $Configuration.DefaultFolders.Errors
        }
    }

    # debug
    $Context.Server.Debug = @{
        Breakpoints = @{
            Enabled = [bool](Protect-PodeValue -Value  $Configuration.Debug.Breakpoints.Enable -Default $Context.Server.Debug.Breakpoints.Enable)
        }
    }

    $Context.Server.AllowedActions = @{
        Suspend         = [bool](Protect-PodeValue -Value  $Configuration.AllowedActions.Suspend -Default $Context.Server.AllowedActions.Suspend)
        Restart         = [bool](Protect-PodeValue -Value  $Configuration.AllowedActions.Restart -Default $Context.Server.AllowedActions.Restart)
        Disable         = [bool](Protect-PodeValue -Value  $Configuration.AllowedActions.Disable -Default $Context.Server.AllowedActions.Disable)
        DisableSettings = @{
            RetryAfter    = [int](Protect-PodeValue -Value  $Configuration.AllowedActions.DisableSettings.RetryAfter -Default $Context.Server.AllowedActions.DisableSettings.RetryAfter)
            LimitRuleName = (Protect-PodeValue -Value  $Configuration.AllowedActions.DisableSettings.LimitRuleName -Default $Context.Server.AllowedActions.DisableSettings.LimitRuleName)
        }
        Timeout         = @{
            Suspend = [int](Protect-PodeValue -Value  $Configuration.AllowedActions.Timeout.Suspend -Default $Context.Server.AllowedActions.Timeout.Suspend)
            Resume  = [int](Protect-PodeValue -Value  $Configuration.AllowedActions.Timeout.Resume -Default $Context.Server.AllowedActions.Timeout.Resume)
        }
    }

    $Context.Server.Console = @{
        DisableTermination  = [bool](Protect-PodeValue -Value  $Configuration.Console.DisableTermination -Default $Context.Server.Console.DisableTermination)
        DisableConsoleInput = [bool](Protect-PodeValue -Value  $Configuration.Console.DisableConsoleInput -Default $Context.Server.Console.DisableConsoleInput)
        Quiet               = [bool](Protect-PodeValue -Value  $Configuration.Console.Quiet -Default $Context.Server.Console.Quiet)
        ClearHost           = [bool](Protect-PodeValue -Value  $Configuration.Console.ClearHost -Default $Context.Server.Console.ClearHost)
        ShowOpenAPI         = [bool](Protect-PodeValue -Value  $Configuration.Console.ShowOpenAPI -Default $Context.Server.Console.ShowOpenAPI)
        ShowEndpoints       = [bool](Protect-PodeValue -Value  $Configuration.Console.ShowEndpoints -Default $Context.Server.Console.ShowEndpoints)
        ShowHelp            = [bool](Protect-PodeValue -Value  $Configuration.Console.ShowHelp -Default $Context.Server.Console.ShowHelp)
        ShowDivider         = [bool](Protect-PodeValue -Value  $Configuration.Console.ShowDivider -Default $Context.Server.Console.ShowDivider)
        ShowTimeStamp       = [bool](Protect-PodeValue -Value  $Configuration.Console.ShowTimeStamp -Default $Context.Server.Console.ShowTimeStamp)
        DividerLength       = [int](Protect-PodeValue -Value  $Configuration.Console.DividerLength -Default $Context.Server.Console.DividerLength)
        Colors              = @{
            Header            = Protect-PodeValue $Configuration.Console.Colors.Header -Default $Context.Server.Console.Colors.Header -EnumType ([type][System.ConsoleColor])
            EndpointsHeader   = Protect-PodeValue -Value $Configuration.Console.Colors.EndpointsHeader -Default $Context.Server.Console.Colors.EndpointsHeader -EnumType ([type][System.ConsoleColor])
            Endpoints         = Protect-PodeValue -Value $Configuration.Console.Colors.Endpoints -Default $Context.Server.Console.Colors.Endpoints -EnumType ([type][System.ConsoleColor])
            EndpointsProtocol = Protect-PodeValue -Value $Configuration.Console.Colors.EndpointsProtocol -Default $Context.Server.Console.Colors.EndpointsProtocol -EnumType ([type][System.ConsoleColor])
            EndpointsFlag     = Protect-PodeValue -Value $Configuration.Console.Colors.EndpointsFlag -Default $Context.Server.Console.Colors.EndpointsFlag -EnumType ([type][System.ConsoleColor])
            EndpointsName     = Protect-PodeValue -Value $Configuration.Console.Colors.EndpointsName -Default $Context.Server.Console.Colors.EndpointsName -EnumType ([type][System.ConsoleColor])
            OpenApiUrls       = Protect-PodeValue -Value $Configuration.Console.Colors.OpenApiUrls -Default $Context.Server.Console.Colors.OpenApiUrls -EnumType ([type][System.ConsoleColor])
            OpenApiHeaders    = Protect-PodeValue -Value $Configuration.Console.Colors.OpenApiHeaders -Default $Context.Server.Console.Colors.OpenApiHeaders -EnumType ([type][System.ConsoleColor])
            OpenApiTitles     = Protect-PodeValue -Value $Configuration.Console.Colors.OpenApiTitles -Default $Context.Server.Console.Colors.OpenApiTitles -EnumType ([type][System.ConsoleColor])
            OpenApiSubtitles  = Protect-PodeValue -Value $Configuration.Console.Colors.OpenApiSubtitles -Default $Context.Server.Console.Colors.OpenApiSubtitles -EnumType ([type][System.ConsoleColor])
            HelpHeader        = Protect-PodeValue -Value $Configuration.Console.Colors.HelpHeader -Default $Context.Server.Console.Colors.HelpHeader -EnumType ([type][System.ConsoleColor])
            HelpKey           = Protect-PodeValue -Value $Configuration.Console.Colors.HelpKey -Default $Context.Server.Console.Colors.HelpKey -EnumType ([type][System.ConsoleColor])
            HelpDescription   = Protect-PodeValue -Value $Configuration.Console.Colors.HelpDescription -Default $Context.Server.Console.Colors.HelpDescription -EnumType ([type][System.ConsoleColor])
            HelpDivider       = Protect-PodeValue -Value $Configuration.Console.Colors.HelpDivider -Default $Context.Server.Console.Colors.HelpDivider -EnumType ([type][System.ConsoleColor])
            Divider           = Protect-PodeValue -Value $Configuration.Console.Colors.Divider -Default $Context.Server.Console.Colors.Divider -EnumType ([type][System.ConsoleColor])
            MetricsHeader     = Protect-PodeValue -Value $Configuration.Console.Colors.MetricsHeader -Default $Context.Server.Console.Colors.MetricsHeader -EnumType ([type][System.ConsoleColor])
            MetricsLabel      = Protect-PodeValue -Value $Configuration.Console.Colors.MetricsLabel -Default $Context.Server.Console.Colors.MetricsLabel -EnumType ([type][System.ConsoleColor])
            MetricsValue      = Protect-PodeValue -Value $Configuration.Console.Colors.MetricsValue -Default $Context.Server.Console.Colors.MetricsValue -EnumType ([type][System.ConsoleColor])


        }
        KeyBindings         = @{
            Browser   = Protect-PodeValue -Value $Configuration.Console.KeyBindings.Browser -Default $Context.Server.Console.KeyBindings.Browser -EnumType ([type][System.ConsoleKey])
            Help      = Protect-PodeValue -Value $Configuration.Console.KeyBindings.Help -Default $Context.Server.Console.KeyBindings.Help -EnumType ([type][System.ConsoleKey])
            OpenAPI   = Protect-PodeValue -Value $Configuration.Console.KeyBindings.OpenAPI -Default $Context.Server.Console.KeyBindings.OpenAPI -EnumType ([type][System.ConsoleKey])
            Endpoints = Protect-PodeValue -Value $Configuration.Console.KeyBindings.Endpoints -Default $Context.Server.Console.KeyBindings.Endpoints -EnumType ([type][System.ConsoleKey])
            Clear     = Protect-PodeValue -Value $Configuration.Console.KeyBindings.Clear -Default $Context.Server.Console.KeyBindings.Clear -EnumType ([type][System.ConsoleKey])
            Quiet     = Protect-PodeValue -Value $Configuration.Console.KeyBindings.Quiet -Default $Context.Server.Console.KeyBindings.Quiet -EnumType ([type][System.ConsoleKey])
            Terminate = Protect-PodeValue -Value $Configuration.Console.KeyBindings.Terminate -Default $Context.Server.Console.KeyBindings.Terminate -EnumType ([type][System.ConsoleKey])
            Restart   = Protect-PodeValue -Value $Configuration.Console.KeyBindings.Restart -Default $Context.Server.Console.KeyBindings.Restart -EnumType ([type][System.ConsoleKey])
            Disable   = Protect-PodeValue -Value $Configuration.Console.KeyBindings.Disable -Default $Context.Server.Console.KeyBindings.Disable -EnumType ([type][System.ConsoleKey])
            Suspend   = Protect-PodeValue -Value $Configuration.Console.KeyBindings.Suspend -Default $Context.Server.Console.KeyBindings.Suspend -EnumType ([type][System.ConsoleKey])
            Metrics   = Protect-PodeValue -Value $Configuration.Console.KeyBindings.Metrics -Default $Context.Server.Console.KeyBindings.Metrics -EnumType ([type][System.ConsoleKey])
        }
    }


}

function Set-PodeWebConfiguration {
    param(
        [Parameter()]
        [hashtable]
        $Configuration,

        [Parameter()]
        $Context
    )

    # setup the main web config
    $Context.Server.Web = @{
        Static           = @{
            Defaults          = $Configuration.Static.Defaults
            RedirectToDefault = [bool]$Configuration.Static.RedirectToDefault
            Cache             = @{
                Enabled = [bool]$Configuration.Static.Cache.Enable
                MaxAge  = [int](Protect-PodeValue -Value $Configuration.Static.Cache.MaxAge -Default 3600)
                Include = (Convert-PodePathPatternsToRegex -Paths @($Configuration.Static.Cache.Include) -NotSlashes)
                Exclude = (Convert-PodePathPatternsToRegex -Paths @($Configuration.Static.Cache.Exclude) -NotSlashes)
            }
            ValidateLast      = [bool]$Configuration.Static.ValidateLast
        }
        ErrorPages       = @{
            ShowExceptions      = [bool]$Configuration.ErrorPages.ShowExceptions
            StrictContentTyping = [bool]$Configuration.ErrorPages.StrictContentTyping
            Default             = $Configuration.ErrorPages.Default
            Routes              = @{}
        }
        ContentType      = @{
            Default = $Configuration.ContentType.Default
            Routes  = @{}
        }
        TransferEncoding = @{
            Default = $Configuration.TransferEncoding.Default
            Routes  = @{}
        }
        Compression      = @{
            Enabled = [bool]$Configuration.Compression.Enable
        }
        OpenApi          = @{
            DefaultDefinitionTag = [string](Protect-PodeValue -Value $Configuration.OpenApi.DefaultDefinitionTag -Default 'default')
        }
        Conversion       = @{
            # If Pode is running in Powershell Core Json conversion are by default to HashTable
            JsonToHashTable = [bool] (Protect-PodeValue -Value $Configuration.Conversion.JsonToHashTable -Default (Test-PodeIsPSCore) )
            XmlToHashTable  = [bool] (Protect-PodeValue -Value $Configuration.Conversion.XmlToHashTable -Default $true )
            YamlToHashTable = [bool] (Protect-PodeValue -Value $Configuration.Conversion.XmlToHashTable -Default $true )
        }
    }

    if ($Configuration.OpenApi -and $Configuration.OpenApi.ContainsKey('UsePodeYamlInternal')) {
        $Context.Server.Web.OpenApi.UsePodeYamlInternal = $Configuration.OpenApi.UsePodeYamlInternal
    }

    # setup content type route patterns for forced content types
    $Configuration.ContentType.Routes.Keys | Where-Object { ![string]::IsNullOrWhiteSpace($_) } | ForEach-Object {
        $_type = $Configuration.ContentType.Routes[$_]
        $_pattern = (Convert-PodePathPatternToRegex -Path $_ -NotSlashes)
        $Context.Server.Web.ContentType.Routes[$_pattern] = $_type
    }

    # setup transfer encoding route patterns for forced transfer encodings
    $Configuration.TransferEncoding.Routes.Keys | Where-Object { ![string]::IsNullOrWhiteSpace($_) } | ForEach-Object {
        $_type = $Configuration.TransferEncoding.Routes[$_]
        $_pattern = (Convert-PodePathPatternToRegex -Path $_ -NotSlashes)
        $Context.Server.Web.TransferEncoding.Routes[$_pattern] = $_type
    }

    # setup content type route patterns for error pages
    $Configuration.ErrorPages.Routes.Keys | Where-Object { ![string]::IsNullOrWhiteSpace($_) } | ForEach-Object {
        $_type = $Configuration.ErrorPages.Routes[$_]
        $_pattern = (Convert-PodePathPatternToRegex -Path $_ -NotSlashes)
        $Context.Server.Web.ErrorPages.Routes[$_pattern] = $_type
    }
}

function New-PodeAutoRestartServer {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSPossibleIncorrectComparisonWithNull', '')]
    [CmdletBinding()]
    param()
    # don't configure if not supplied, or running as serverless
    $config = (Get-PodeConfig)
    if (($null -eq $config) -or ($null -eq $config.Server.Restart) -or $PodeContext.Server.IsServerless) {
        return
    }

    $restart = $config.Server.Restart

    # period - setup a timer
    $period = [int]$restart.period
    if ($period -gt 0) {
        Add-PodeTimer -Name '__pode_restart_period__' -Interval ($period * 60) -ScriptBlock {
            Close-PodeCancellationTokenRequest -Type Restart
        }
    }

    # times - convert into cron expressions
    $times = @(@($restart.times) -ne $null)
    if (($times | Measure-Object).Count -gt 0) {
        $crons = @()

        @($times) | ForEach-Object {
            $atoms = $_ -split '\:'
            $crons += "$([int]$atoms[1]) $([int]$atoms[0]) * * *"
        }

        Add-PodeSchedule -Name '__pode_restart_times__' -Cron @($crons) -ScriptBlock {
            Close-PodeCancellationTokenRequest -Type Restart
        }
    }

    # crons - setup schedules
    $crons = @(@($restart.crons) -ne $null)
    if (($crons | Measure-Object).Count -gt 0) {
        Add-PodeSchedule -Name '__pode_restart_crons__' -Cron @($crons) -ScriptBlock {
            Close-PodeCancellationTokenRequest -Type Restart
        }
    }
}

<#
.SYNOPSIS
    Sets global output variables based on the Pode server context.

.DESCRIPTION
    This function sets global output variables based on the Pode server context. It retrieves output variables from the server context and assigns them as global variables. These output variables can be accessed and used in other parts of your code.

.OUTPUTS
    Sets global output variables based on the Pode server context.

#>
function Set-PodeOutputVariable {
    if (Test-PodeIsEmpty $PodeContext.Server.Output.Variables) {
        return
    }

    foreach ($key in $PodeContext.Server.Output.Variables.Keys) {
        try {
            Set-Variable -Name $key -Value $PodeContext.Server.Output.Variables[$key] -Force -Scope Global
        }
        catch {
            $_ | Write-PodeErrorLog
        }
    }
}