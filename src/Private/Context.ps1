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

        [switch]
        $DisableTermination,

        [switch]
        $Quiet,

        [switch]
        $EnableBreakpoints
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
    $ctx = New-Object -TypeName psobject |
        Add-Member -MemberType NoteProperty -Name Threads -Value @{} -PassThru |
        Add-Member -MemberType NoteProperty -Name Timers -Value @{} -PassThru |
        Add-Member -MemberType NoteProperty -Name Schedules -Value @{} -PassThru |
        Add-Member -MemberType NoteProperty -Name Tasks -Value @{} -PassThru |
        Add-Member -MemberType NoteProperty -Name AsyncRoutes -Value @{} -PassThru |
        Add-Member -MemberType NoteProperty -Name RunspacePools -Value $null -PassThru |
        Add-Member -MemberType NoteProperty -Name Runspaces -Value $null -PassThru |
        Add-Member -MemberType NoteProperty -Name RunspaceState -Value $null -PassThru |
        Add-Member -MemberType NoteProperty -Name Tokens -Value @{} -PassThru |
        Add-Member -MemberType NoteProperty -Name LogsToProcess -Value $null -PassThru |
        Add-Member -MemberType NoteProperty -Name Threading -Value @{} -PassThru |
        Add-Member -MemberType NoteProperty -Name Server -Value @{} -PassThru |
        Add-Member -MemberType NoteProperty -Name Metrics -Value @{} -PassThru |
        Add-Member -MemberType NoteProperty -Name Listeners -Value @() -PassThru |
        Add-Member -MemberType NoteProperty -Name Receivers -Value @() -PassThru |
        Add-Member -MemberType NoteProperty -Name Watchers -Value @() -PassThru |
        Add-Member -MemberType NoteProperty -Name Fim -Value @{} -PassThru

    # set the server name, logic and root, and other basic properties
    $ctx.Server.Name = $Name
    $ctx.Server.Logic = $ScriptBlock
    $ctx.Server.LogicPath = $FilePath
    $ctx.Server.Interval = $Interval
    $ctx.Server.PodeModule = (Get-PodeModuleInfo)
    $ctx.Server.DisableTermination = $DisableTermination.IsPresent
    $ctx.Server.Quiet = $Quiet.IsPresent
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
        Enabled        = ($EnablePool -icontains 'tasks')
        Items          = @{}
        Processes      = @{}
        HouseKeeping = @{
            TimerInterval    = 30
            RetentionMinutes = 1
        }
    }

    $ctx.AsyncRoutes = @{
        Enabled             = $true
        Items               = [System.Collections.Concurrent.ConcurrentDictionary[string, PSObject]]::new()
        Results             = [System.Collections.Concurrent.ConcurrentDictionary[string, PSObject]]::new()
        HouseKeeping        = @{
            TimerInterval    = 30
            RetentionMinutes = 10
        }
        UserFieldIdentifier = 'Id'
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
        General     = $Threads
        Schedules   = 10
        Files       = 1
        Tasks       = 2
        WebSockets  = 2
        AsyncRoutes = 0
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
        'Views'  = 'views'
        'Public' = 'public'
        'Errors' = 'errors'
    }

    # check if there is any global configuration
    $ctx.Server.Configuration = Open-PodeConfiguration -ServerRoot $ServerRoot -Context $ctx

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
        if ($null -eq $ctx.Server.Debug) {
            $ctx.Server.Debug = @{ Breakpoints = @{} }
        }

        $ctx.Server.Debug.Breakpoints.Enabled = $EnableBreakpoints.IsPresent
    }

    # set the server's listener type
    $ctx.Server.ListenerType = $ListenerType

    # set serverless info
    $ctx.Server.ServerlessType = $ServerlessType
    $ctx.Server.IsServerless = $isServerless
    if ($isServerless) {
        $ctx.Server.DisableTermination = $true
    }

    # set the server types
    $ctx.Server.IsService = ($Interval -gt 0)
    $ctx.Server.Types = @()

    # is the server running under IIS? (also, disable termination)
    $ctx.Server.IsIIS = (!$isServerless -and (!(Test-PodeIsEmpty $env:ASPNETCORE_PORT)) -and (!(Test-PodeIsEmpty $env:ASPNETCORE_TOKEN)))
    if ($ctx.Server.IsIIS) {
        $ctx.Server.DisableTermination = $true

        # if under IIS and Azure Web App, force quiet
        if (!(Test-PodeIsEmpty $env:WEBSITE_IIS_SITE_NAME)) {
            $ctx.Server.Quiet = $true
        }

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

    # if we're inside a remote host, stop termination
    if ($Host.Name -ieq 'ServerRemoteHost') {
        $ctx.Server.DisableTermination = $true
    }

    # set the IP address details
    $ctx.Server.Endpoints = @{}
    $ctx.Server.EndpointsMap = @{}

    # general encoding for the server
    $ctx.Server.Encoding = New-Object System.Text.UTF8Encoding

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
    $ctx.Server.Routes = @{
        'connect' = [ordered]@{}
        'delete'  = [ordered]@{}
        'get'     = [ordered]@{}
        'head'    = [ordered]@{}
        'merge'   = [ordered]@{}
        'options' = [ordered]@{}
        'patch'   = [ordered]@{}
        'post'    = [ordered]@{}
        'put'     = [ordered]@{}
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
        Rules  = @{}
        Active = @{}
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
    $ctx.Tokens = @{
        Cancellation = New-Object System.Threading.CancellationTokenSource
        Restart      = New-Object System.Threading.CancellationTokenSource
    }

    # requests that should be logged
    $ctx.LogsToProcess = New-Object System.Collections.ArrayList

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
    $ctx.RunspacePools = [System.Collections.Concurrent.ConcurrentDictionary[string, PSObject]]::new()
    $ctx.RunspacePools['Main'] = $null
    $ctx.RunspacePools['Web'] = $null
    $ctx.RunspacePools['Smtp'] = $null
    $ctx.RunspacePools['Tcp'] = $null
    $ctx.RunspacePools['Signals'] = $null
    $ctx.RunspacePools['Schedules'] = $null
    $ctx.RunspacePools['Gui'] = $null
    $ctx.RunspacePools['Tasks'] = $null
    $ctx.RunspacePools['Files'] = $null
    $ctx.RunspacePools['Timers'] = $null

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
        (New-Object System.Management.Automation.Runspaces.SessionStateVariableEntry -ArgumentList 'PodeLocale', $PodeLocale, $null),
        (New-Object System.Management.Automation.Runspaces.SessionStateVariableEntry -ArgumentList 'PodeContext', $session, $null),
        (New-Object System.Management.Automation.Runspaces.SessionStateVariableEntry -ArgumentList 'Console', $Host, $null),
        (New-Object System.Management.Automation.Runspaces.SessionStateVariableEntry -ArgumentList 'PODE_SCOPE_RUNSPACE', $true, $null)
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
        Pool  = New-PodeRunspacePoolNetWrapper  -MaxRunspaces $totalThreadCount -RunspaceState $PodeContext.RunspaceState
        State = 'Waiting'
    }

    # web runspace - if we have any http/s endpoints
    if (Test-PodeEndpointByProtocolType -Type Http) {
        $PodeContext.RunspacePools.Web = @{
            Pool  = [runspacefactory]::CreateRunspacePool(1, ($PodeContext.Threads.General + 1), $PodeContext.RunspaceState, $Host)
            State = 'Waiting'
        }
    }

    # smtp runspace - if we have any smtp endpoints
    if (Test-PodeEndpointByProtocolType -Type Smtp) {
        $PodeContext.RunspacePools.Smtp = @{
            Pool  = New-PodeRunspacePoolNetWrapper -MaxRunspaces ($PodeContext.Threads.General + 1) -RunspaceState $PodeContext.RunspaceState
            State = 'Waiting'
        }
    }

    # tcp runspace - if we have any tcp endpoints
    if (Test-PodeEndpointByProtocolType -Type Tcp) {
        $PodeContext.RunspacePools.Tcp = @{
            Pool  = New-PodeRunspacePoolNetWrapper -MaxRunspaces ($PodeContext.Threads.General + 1) -RunspaceState $PodeContext.RunspaceState
            State = 'Waiting'
        }
    }

    # signals runspace - if we have any ws/s endpoints
    if (Test-PodeEndpointByProtocolType -Type Ws) {
        $PodeContext.RunspacePools.Signals = @{
            Pool  = New-PodeRunspacePoolNetWrapper -MaxRunspaces ($PodeContext.Threads.General + 2) -RunspaceState $PodeContext.RunspaceState
            State = 'Waiting'
        }
    }

    # web socket connections runspace - for receiving data for external sockets
    if (Test-PodeWebSocketsExist) {
        $PodeContext.RunspacePools.WebSockets = @{
            Pool  = New-PodeRunspacePoolNetWrapper -MaxRunspaces ($PodeContext.Threads.WebSockets + 1) -RunspaceState $PodeContext.RunspaceState
            State = 'Waiting'
        }

        New-PodeWebSocketReceiver
    }

    # setup timer runspace pool -if we have any timers
    if (Test-PodeTimersExist) {
        $PodeContext.RunspacePools.Timers = @{
            Pool  = [runspacefactory]::CreateRunspacePool(1, $PodeContext.Threads.Timers, $PodeContext.RunspaceState, $Host)
            State = 'Waiting'
        }
    }

    # setup schedule runspace pool -if we have any schedules
    if (Test-PodeSchedulesExist) {
        $PodeContext.RunspacePools.Schedules = @{
            Pool  = New-PodeRunspacePoolNetWrapper -MaxRunspaces $PodeContext.Threads.Schedules -RunspaceState $PodeContext.RunspaceState
            State = 'Waiting'
        }
    }

    # setup tasks runspace pool -if we have any tasks
    if (Test-PodeTasksExist) {
        $PodeContext.RunspacePools.Tasks = @{
            Pool  = New-PodeRunspacePoolNetWrapper -MaxRunspaces $PodeContext.Threads.Tasks -RunspaceState $PodeContext.RunspaceState
            State = 'Waiting'
        }
    }

    # setup files runspace pool -if we have any file watchers
    if (Test-PodeFileWatchersExist) {
        $PodeContext.RunspacePools.Files = @{
            Pool  = New-PodeRunspacePoolNetWrapper -MaxRunspaces ($PodeContext.Threads.Files + 1) -RunspaceState $PodeContext.RunspaceState
            State = 'Waiting'
        }
    }

    # setup gui runspace pool (only for non-ps-core) - if gui enabled
    if (Test-PodeGuiEnabled) {
        $PodeContext.RunspacePools.Gui = @{
            Pool  = New-PodeRunspacePoolNetWrapper -MaxRunspaces 1 -RunspaceState $PodeContext.RunspaceState
            State = 'Waiting'
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

    return (New-Object -TypeName psobject |
            Add-Member -MemberType NoteProperty -Name Threads -Value $Context.Threads -PassThru |
            Add-Member -MemberType NoteProperty -Name Timers -Value $Context.Timers -PassThru |
            Add-Member -MemberType NoteProperty -Name Schedules -Value $Context.Schedules -PassThru |
            Add-Member -MemberType NoteProperty -Name Tasks -Value $Context.Tasks -PassThru |
            Add-Member -MemberType NoteProperty -Name AsyncRoutes -Value $Context.AsyncRoutes -PassThru |
            Add-Member -MemberType NoteProperty -Name Fim -Value $Context.Fim -PassThru |
            Add-Member -MemberType NoteProperty -Name RunspacePools -Value $Context.RunspacePools -PassThru |
            Add-Member -MemberType NoteProperty -Name Tokens -Value $Context.Tokens -PassThru |
            Add-Member -MemberType NoteProperty -Name Metrics -Value $Context.Metrics -PassThru |
            Add-Member -MemberType NoteProperty -Name LogsToProcess -Value $Context.LogsToProcess -PassThru |
            Add-Member -MemberType NoteProperty -Name Threading -Value $Context.Threading -PassThru |
            Add-Member -MemberType NoteProperty -Name Server -Value $Context.Server -PassThru)
}

function Open-PodeConfiguration {
    param(
        [Parameter()]
        [string]
        $ServerRoot = $null,

        [Parameter()]
        $Context
    )

    $config = @{}

    # set the path to the root config file
    $configPath = (Join-PodeServerRoot -Folder '.' -FilePath 'server.psd1' -Root $ServerRoot)

    # check to see if an environmental config exists (if the env var is set)
    if (!(Test-PodeIsEmpty $env:PODE_ENVIRONMENT)) {
        $_path = (Join-PodeServerRoot -Folder '.' -FilePath "server.$($env:PODE_ENVIRONMENT).psd1" -Root $ServerRoot)
        if (Test-PodePath -Path $_path -NoStatus) {
            $configPath = $_path
        }
    }

    # check the path exists, and load the config
    if (Test-PodePath -Path $configPath -NoStatus) {
        $config = Import-PowerShellDataFile -Path $configPath -ErrorAction Stop
        Set-PodeServerConfiguration -Configuration $config.Server -Context $Context
        Set-PodeWebConfiguration -Configuration $config.Web -Context $Context
    }

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
            Enabled = [bool]$Configuration.Debug.Breakpoints.Enable
        }
    }

    $Context.AsyncRoutes.HouseKeeping = @{
        TimerInterval    = Protect-PodeValue -Value $Configuration.AsyncRoutes.HouseKeeping.TimerInterval -Default $Context.AsyncRoutes.HouseKeeping.TimerInterval
        RetentionMinutes = Protect-PodeValue -Value $Configuration.AsyncRoutes.HouseKeeping.RetentionMinutes -Default $Context.AsyncRoutes.HouseKeeping.RetentionMinutes
    }

    $Context.AsyncRoutes.UserFieldIdentifier = Protect-PodeValue -Value $Configuration.AsyncRoutes.UserFieldIdentifier -Default $Context.AsyncRoutes.UserFieldIdentifier

    $Context.Tasks.HouseKeeping = @{
        TimerInterval    = Protect-PodeValue -Value $Configuration.Tasks.HouseKeeping.TimerInterval -Default $Context.Tasks.HouseKeeping.TimerInterval
        RetentionMinutes = Protect-PodeValue -Value $Configuration.Tasks.HouseKeeping.RetentionMinutes -Default $Context.Tasks.HouseKeeping.RetentionMinutes
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
            $PodeContext.Tokens.Restart.Cancel()
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
            $PodeContext.Tokens.Restart.Cancel()
        }
    }

    # crons - setup schedules
    $crons = @(@($restart.crons) -ne $null)
    if (($crons | Measure-Object).Count -gt 0) {
        Add-PodeSchedule -Name '__pode_restart_crons__' -Cron @($crons) -ScriptBlock {
            $PodeContext.Tokens.Restart.Cancel()
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