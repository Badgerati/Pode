function New-PodeContext
{
    [CmdletBinding()]
    param (
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
        $ServerType
    )

    # set a random server name if one not supplied
    if (Test-IsEmpty $Name) {
        $Name = Get-PodeRandomName
    }

    # are we running in a serverless context
    $isServerless = (@('AzureFunctions', 'AwsLambda') -icontains $ServerType)

    # ensure threads are always >0, for to 1 if we're serverless
    if (($Threads -le 0) -or $isServerless) {
        $Threads = 1
    }

    # basic context object
    $ctx = New-Object -TypeName psobject |
        Add-Member -MemberType NoteProperty -Name Threads -Value @{} -PassThru |
        Add-Member -MemberType NoteProperty -Name Timers -Value @{} -PassThru |
        Add-Member -MemberType NoteProperty -Name Schedules -Value @{} -PassThru |
        Add-Member -MemberType NoteProperty -Name RunspacePools -Value $null -PassThru |
        Add-Member -MemberType NoteProperty -Name Runspaces -Value $null -PassThru |
        Add-Member -MemberType NoteProperty -Name RunspaceState -Value $null -PassThru |
        Add-Member -MemberType NoteProperty -Name Tokens -Value @{} -PassThru |
        Add-Member -MemberType NoteProperty -Name LogsToProcess -Value $null -PassThru |
        Add-Member -MemberType NoteProperty -Name Lockable -Value $null -PassThru |
        Add-Member -MemberType NoteProperty -Name Server -Value @{} -PassThru

    # set the server name, logic and root
    $ctx.Server.Name = $Name
    $ctx.Server.Logic = $ScriptBlock
    $ctx.Server.LogicPath = $FilePath
    $ctx.Server.Interval = $Interval
    $ctx.Server.PodeModulePath = (Get-PodeModulePath)

    # basic logging setup
    $ctx.Server.Logging = @{
        Enabled = $true
        Types = @{}
    }

    # set thread counts
    $ctx.Threads = @{
        Web = $Threads
        Schedules = 10
    }

    # set socket details for pode server
    $ctx.Server.Sockets = @{
        Listeners = @()
        MaxConnections = 0
        Ssl = @{
            Callback = $null
            Protocols = (ConvertTo-PodeSslProtocols -Protocols @('Ssl3', 'Tls12'))
        }
        ReceiveTimeout = 100
        Queues = @{
            Connections = [System.Collections.Concurrent.ConcurrentQueue[System.Net.Sockets.SocketAsyncEventArgs]]::new()
        }
    }

    $ctx.Server.WebSockets = @{
        Enabled = $false
        Listeners = @()
        MaxConnections = 0
        Ssl = @{
            Callback = $null
            Protocols = (ConvertTo-PodeSslProtocols -Protocols @('Ssl3', 'Tls12'))
        }
        ReceiveTimeout = 100
        Queues = @{
            Sockets = @{}
            Messages = [System.Collections.Concurrent.ConcurrentQueue[hashtable]]::new()
            Connections = [System.Collections.Concurrent.ConcurrentQueue[System.Net.Sockets.SocketAsyncEventArgs]]::new()
        }
    }

    # check if there is any global configuration
    $ctx.Server.Configuration = Open-PodeConfiguration -ServerRoot $ServerRoot -Context $ctx

    # configure the server's root path
    $ctx.Server.Root = $ServerRoot
    if (!(Test-IsEmpty $ctx.Server.Configuration.Server.Root)) {
        $ctx.Server.Root = Get-PodeRelativePath -Path $ctx.Server.Configuration.Server.Root -RootPath $ctx.Server.Root -JoinRoot -Resolve -TestPath
    }

    # set the server default type
    $ctx.Server.Type = $ServerType.ToUpperInvariant()
    if ($Interval -gt 0) {
        $ctx.Server.Type = 'SERVICE'
    }

    if ($isServerless) {
        $ctx.Server.IsServerless = $isServerless
    }

    # set the IP address details
    $ctx.Server.Endpoints = @()

    # general encoding for the server
    $ctx.Server.Encoding = New-Object System.Text.UTF8Encoding

    # setup gui details
    $ctx.Server.Gui = @{}

    # shared temp drives
    $ctx.Server.Drives = @{}
    $ctx.Server.InbuiltDrives = @{}

    # shared state between runspaces
    $ctx.Server.State = @{}

    # view engine for rendering pages
    $ctx.Server.ViewEngine = @{
        Type = 'html'
        Extension = 'html'
        Script = $null
        IsDynamic = $false
    }

    # routes for pages and api
    $ctx.Server.Routes = @{
        'delete' = @{};
        'get' = @{};
        'head' = @{};
        'merge' = @{};
        'options' = @{};
        'patch' = @{};
        'post' = @{};
        'put' = @{};
        'trace' = @{};
        'static' = @{};
        '*' = @{};
    }

    # handlers for tcp
    $ctx.Server.Handlers = @{
        'tcp' = @{};
        'smtp' = @{};
        'service' = @{};
    }

    # setup basic access placeholders
    $ctx.Server.Access = @{
        Allow = @{}
        Deny = @{}
    }

    # setup basic limit rules
    $ctx.Server.Limits = @{
        Rules = @{}
        Active = @{}
    }

    # cookies and session logic
    $ctx.Server.Cookies = @{
        Session = @{}
        Csrf = @{}
        Secrets = @{}
    }

    # authnetication methods
    $ctx.Server.Authentications = @{}

    # create new cancellation tokens
    $ctx.Tokens = @{
        Cancellation = New-Object System.Threading.CancellationTokenSource
        Restart = New-Object System.Threading.CancellationTokenSource
    }

    # requests that should be logged
    $ctx.LogsToProcess = New-Object System.Collections.ArrayList

    # middleware that needs to run
    $ctx.Server.Middleware = @()
    $ctx.Server.BodyParsers = @{}

    # endware that needs to run
    $ctx.Server.Endware = @()

    # runspace pools
    $ctx.RunspacePools = @{
        Main = $null
        Signals = $null
        Schedules = $null
        Gui = $null
    }

    # session state
    $ctx.Lockable = [hashtable]::Synchronized(@{})

    # setup runspaces
    $ctx.Runspaces = @()

    # return the new context
    return $ctx
}

function New-PodeRunspaceState
{
    $state = [initialsessionstate]::CreateDefault()
    $state.ImportPSModule($PodeContext.Server.PodeModulePath)

    $session = New-PodeStateContext -Context $PodeContext

    $variables = @(
        (New-Object System.Management.Automation.Runspaces.SessionStateVariableEntry -ArgumentList 'PodeContext', $session, $null),
        (New-Object System.Management.Automation.Runspaces.SessionStateVariableEntry -ArgumentList 'Console', $Host, $null),
        (New-Object System.Management.Automation.Runspaces.SessionStateVariableEntry -ArgumentList 'PODE_SCOPE_RUNSPACE', $true, $null)
    )

    foreach ($var in $variables) {
        $state.Variables.Add($var)
    }

    $PodeContext.RunspaceState = $state
}

function New-PodeRunspacePools
{
    if ($PodeContext.Server.IsServerless) {
        return
    }

    # setup main runspace pool
    $threadsCounts = @{
        Default = 3
        Timer = 1
        Log = 1
        Schedule = 1
        Misc = 1
    }

    $totalThreadCount = ($threadsCounts.Values | Measure-Object -Sum).Sum + $PodeContext.Threads.Web
    $PodeContext.RunspacePools.Main = [runspacefactory]::CreateRunspacePool(1, $totalThreadCount, $PodeContext.RunspaceState, $Host)

    # setup signal runspace pool
    $PodeContext.RunspacePools.Signals = [runspacefactory]::CreateRunspacePool(1, ($PodeContext.Threads.Web + 2), $PodeContext.RunspaceState, $Host)

    # setup schedule runspace pool
    $PodeContext.RunspacePools.Schedules = [runspacefactory]::CreateRunspacePool(1, $PodeContext.Threads.Schedules, $PodeContext.RunspaceState, $Host)

    # setup gui runspace pool (only for non-ps-core)
    if (!((Test-IsPSCore) -and ($PSVersionTable.PSVersion.Major -eq 6))) {
        $PodeContext.RunspacePools.Gui = [runspacefactory]::CreateRunspacePool(1, 1, $PodeContext.RunspaceState, $Host)
        $PodeContext.RunspacePools.Gui.ApartmentState = 'STA'
    }
}

function Open-PodeRunspacePools
{
    if ($PodeContext.Server.IsServerless) {
        return
    }

    foreach ($key in $PodeContext.RunspacePools.Keys) {
        if ($null -ne $PodeContext.RunspacePools[$key]) {
            $PodeContext.RunspacePools[$key].Open()
        }
    }
}

function New-PodeStateContext
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        $Context
    )

    return (New-Object -TypeName psobject |
        Add-Member -MemberType NoteProperty -Name Threads -Value $Context.Threads -PassThru |
        Add-Member -MemberType NoteProperty -Name Timers -Value $Context.Timers -PassThru |
        Add-Member -MemberType NoteProperty -Name Schedules -Value $Context.Schedules -PassThru |
        Add-Member -MemberType NoteProperty -Name RunspacePools -Value $Context.RunspacePools -PassThru |
        Add-Member -MemberType NoteProperty -Name Tokens -Value $Context.Tokens -PassThru |
        Add-Member -MemberType NoteProperty -Name LogsToProcess -Value $Context.LogsToProcess -PassThru |
        Add-Member -MemberType NoteProperty -Name Lockable -Value $Context.Lockable -PassThru |
        Add-Member -MemberType NoteProperty -Name Server -Value $Context.Server -PassThru)
}

function Open-PodeConfiguration
{
    param (
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
    if (!(Test-IsEmpty $env:PODE_ENVIRONMENT)) {
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

function Set-PodeServerConfiguration
{
    param (
        [Parameter()]
        [hashtable]
        $Configuration,

        [Parameter()]
        $Context
    )

    # file monitoring
    $Context.Server.FileMonitor = @{
        Enabled = ([bool]$Configuration.FileMonitor.Enable)
        Exclude = (Convert-PodePathPatternsToRegex -Paths @($Configuration.FileMonitor.Exclude))
        Include = (Convert-PodePathPatternsToRegex -Paths @($Configuration.FileMonitor.Include))
        ShowFiles = ([bool]$Configuration.FileMonitor.ShowFiles)
        Files = @()
    }

    # logging
    $Context.Server.Logging = @{
        Enabled = !([bool]$Configuration.Logging.Enable)
        Masking = @{
            Patterns = (Remove-PodeEmptyItemsFromArray -Array @($Configuration.Logging.Masking.Patterns))
            Mask = (Protect-PodeValue -Value $Configuration.Logging.Masking.Mask -Default '********')
        }
        Types = @{}
    }

    # sockets (pode)
    if (!(Test-IsEmpty $Configuration.Pode.Ssl.Protocols)) {
        $Context.Server.Sockets.Ssl.Protocols = (ConvertTo-PodeSslProtocols -Protocols $Configuration.Pode.Ssl.Protocols)
    }

    if ([int]$Configuration.Pode.ReceiveTimeout -gt 0) {
        $Context.Server.Sockets.ReceiveTimeout = (Protect-PodeValue -Value $Configuration.Pode.ReceiveTimeout $Context.Server.Sockets.ReceiveTimeout)
    }
}

function Set-PodeWebConfiguration
{
    param (
        [Parameter()]
        [hashtable]
        $Configuration,

        [Parameter()]
        $Context
    )

    # setup the main web config
    $Context.Server.Web = @{
        Static = @{
            Defaults = $Configuration.Static.Defaults
            Cache = @{
                Enabled = [bool]$Configuration.Static.Cache.Enable
                MaxAge = [int](Protect-PodeValue -Value $Configuration.Static.Cache.MaxAge -Default 3600)
                Include = (Convert-PodePathPatternsToRegex -Paths @($Configuration.Static.Cache.Include) -NotSlashes)
                Exclude = (Convert-PodePathPatternsToRegex -Paths @($Configuration.Static.Cache.Exclude) -NotSlashes)
            }
        }
        ErrorPages = @{
            ShowExceptions = [bool]$Configuration.ErrorPages.ShowExceptions
            StrictContentTyping = [bool]$Configuration.ErrorPages.StrictContentTyping
            Default = $Configuration.ErrorPages.Default
            Routes = @{}
        }
        ContentType = @{
            Default = $Configuration.ContentType.Default
            Routes = @{}
        }
    }

    # setup content type route patterns for forced content types
    $Configuration.ContentType.Routes.Keys | Where-Object { ![string]::IsNullOrWhiteSpace($_) } | ForEach-Object {
        $_type = $Configuration.ContentType.Routes[$_]
        $_pattern = (Convert-PodePathPatternToRegex -Path $_ -NotSlashes)
        $Context.Server.Web.ContentType.Routes[$_pattern] = $_type
    }

    # setup content type route patterns for error pages
    $Configuration.ErrorPages.Routes.Keys | Where-Object { ![string]::IsNullOrWhiteSpace($_) } | ForEach-Object {
        $_type = $Configuration.ErrorPages.Routes[$_]
        $_pattern = (Convert-PodePathPatternToRegex -Path $_ -NotSlashes)
        $Context.Server.Web.ErrorPages.Routes[$_pattern] = $_type
    }
}

function New-PodeAutoRestartServer
{
    # don't configure if not supplied, or running as serverless
    $config = (Get-PodeConfig)
    if (($null -eq $config) -or ($null -eq $config.Server.Restart) -or $PodeContext.Server.IsServerless)  {
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

function Get-PodeEndpoints
{
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('Http', 'Ws')]
        [string]
        $Type
    )

    $endpoints = $null

    switch ($Type.ToLowerInvariant()) {
        'http' {
            $endpoints = @($PodeContext.Server.Endpoints | Where-Object { @('http', 'https') -icontains $_.Protocol })
        }

        'ws' {
            $endpoints = @($PodeContext.Server.Endpoints | Where-Object { @('ws', 'wss') -icontains $_.Protocol })
        }
    }

    return $endpoints
}