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
        $ServerlessType,

        [Parameter()]
        [string]
        $StatusPageExceptions,

        [Parameter()]
        [string]
        $ListenerType,

        [switch]
        $DisableTermination,

        [switch]
        $Quiet
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
        Add-Member -MemberType NoteProperty -Name RunspacePools -Value $null -PassThru |
        Add-Member -MemberType NoteProperty -Name Runspaces -Value $null -PassThru |
        Add-Member -MemberType NoteProperty -Name RunspaceState -Value $null -PassThru |
        Add-Member -MemberType NoteProperty -Name Tokens -Value @{} -PassThru |
        Add-Member -MemberType NoteProperty -Name LogsToProcess -Value $null -PassThru |
        Add-Member -MemberType NoteProperty -Name Lockable -Value $null -PassThru |
        Add-Member -MemberType NoteProperty -Name Server -Value @{} -PassThru |
        Add-Member -MemberType NoteProperty -Name Metrics -Value @{} -PassThru |
        Add-Member -MemberType NoteProperty -Name Listeners -Value @() -PassThru

    # set the server name, logic and root, and other basic properties
    $ctx.Server.Name = $Name
    $ctx.Server.Logic = $ScriptBlock
    $ctx.Server.LogicPath = $FilePath
    $ctx.Server.Interval = $Interval
    $ctx.Server.PodeModulePath = (Get-PodeModulePath)
    $ctx.Server.DisableTermination = $DisableTermination.IsPresent
    $ctx.Server.Quiet = $Quiet.IsPresent
    $ctx.Server.ComputerName = [System.Net.DNS]::GetHostName()

    # list of created listeners
    $ctx.Listeners = @()

    # auto importing (modules, funcs, snap-ins)
    $ctx.Server.AutoImport = @{
        Modules = @{
            Enabled = $true
            ExportList = @()
            ExportOnly = $false
        }
        Snapins = @{
            Enabled = $true
            ExportList = @()
            ExportOnly = $false
        }
        Functions = @{
            Enabled = $true
            ExportList = @()
            ExportOnly = $false
        }
    }

    # basic logging setup
    $ctx.Server.Logging = @{
        Enabled = $true
        Types = @{}
    }

    # set thread counts
    $ctx.Threads = @{
        General = $Threads
        Schedules = 10
    }

    # set socket details for pode server
    $ctx.Server.Sockets = @{
        Ssl = @{
            Protocols = (ConvertTo-PodeSslProtocols -Protocols @('Ssl3', 'Tls12'))
        }
        ReceiveTimeout = 100
    }

    $ctx.Server.WebSockets = @{
        Enabled = $false
        Listener = $null
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
    $ctx.Server.FindRouteEndpoint = $false

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
        ScriptBlock = $null
        UsingVariables = $null
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

    # custom view paths
    $ctx.Server.Views = @{}

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
        Csrf = @{}
        Secrets = @{}
    }

    # sessions
    $ctx.Server.Sessions = @{}

    # swagger and openapi
    $ctx.Server.OpenAPI = Get-PodeOABaseObject

    # server metrics
    $ctx.Metrics = @{
        Server = @{
            InitialLoadTime = [datetime]::UtcNow
            StartTime = [datetime]::UtcNow
            RestartCount = 0
        }
        Requests = @{
            Total = 0
            StatusCodes = @{}
        }
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

    # common support values
    $ctx.Server.Compression = @{
        Encodings = @('gzip', 'deflate', 'x-gzip')
    }

    # endware that needs to run
    $ctx.Server.Endware = @()

    # runspace pools
    $ctx.RunspacePools = @{
        Main = $null
        Web = $null
        Smtp = $null
        Tcp = $null
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
    # create the state, and add the pode module
    $state = [initialsessionstate]::CreateDefault()
    $state.ImportPSModule($PodeContext.Server.PodeModulePath)

    # load the vars into the share state
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

function Import-PodeFunctionsIntoRunspaceState
{
    param(
        [Parameter(Mandatory=$true, ParameterSetName='Script')]
        [scriptblock]
        $ScriptBlock,

        [Parameter(Mandatory=$true, ParameterSetName='File')]
        [string]
        $FilePath
    )

    # do nothing if disabled
    if (!$PodeContext.Server.AutoImport.Functions.Enabled) {
        return
    }

    # if export only, and there are none, do nothing
    if ($PodeContext.Server.AutoImport.Functions.ExportOnly -and ($PodeContext.Server.AutoImport.Functions.ExportList.Length -eq 0)) {
        return
    }

    # script or file functions?
    switch ($PSCmdlet.ParameterSetName.ToLowerInvariant()) {
        'script' {
            $funcs = (Get-PodeFunctionsFromScriptBlock -ScriptBlock $ScriptBlock)
        }

        'file' {
            $funcs = (Get-PodeFunctionsFromFile -FilePath $FilePath)
        }
    }

    # looks like we have nothing!
    if (($null -eq $funcs) -or ($funcs.Length -eq 0)) {
        return
    }

    # groups funcs in case there or multiple definitions
    $funcs = ($funcs | Group-Object -Property { $_.Name })

    # import them, but also check if they're exported
    foreach ($func in $funcs) {
        # only exported funcs? is the func exported?
        if ($PodeContext.Server.AutoImport.Functions.ExportOnly -and ($PodeContext.Server.AutoImport.Functions.ExportList -inotcontains $func.Name)) {
            continue
        }

        # load the function
        $funcDef = [System.Management.Automation.Runspaces.SessionStateFunctionEntry]::new($func.Name, $func.Group[-1].Definition)
        $PodeContext.RunspaceState.Commands.Add($funcDef)
    }
}

function Import-PodeModulesIntoRunspaceState
{
    # do nothing if disabled
    if (!$PodeContext.Server.AutoImport.Modules.Enabled) {
        return
    }

    # if export only, and there are none, do nothing
    if ($PodeContext.Server.AutoImport.Modules.ExportOnly -and ($PodeContext.Server.AutoImport.Modules.ExportList.Length -eq 0)) {
        return
    }

    # load modules into runspaces, if allowed
    $modules = (Get-Module |
        Where-Object {
            ($_.Name -ine 'pode') -and ($_.Name -inotlike 'microsoft.powershell.*')
        }).Name | Sort-Object -Unique

    foreach ($module in $modules) {
        # only exported modules? is the module exported?
        if ($PodeContext.Server.AutoImport.Modules.ExportOnly -and ($PodeContext.Server.AutoImport.Modules.ExportList -inotcontains $module)) {
            continue
        }

        $path = (Get-Module -Name $module | Sort-Object -Property Version -Descending | Select-Object -First 1 -ExpandProperty Path)
        $PodeContext.RunspaceState.ImportPSModule($path)
    }
}

function Import-PodeSnapinsIntoRunspaceState
{
    # if non-windows or core, do nothing
    if ((Test-PodeIsPSCore) -or (Test-PodeIsUnix)) {
        return
    }

    # do nothing if disabled
    if (!$PodeContext.Server.AutoImport.Snapins.Enabled) {
        return
    }

    # if export only, and there are none, do nothing
    if ($PodeContext.Server.AutoImport.Snapins.ExportOnly -and ($PodeContext.Server.AutoImport.Snapins.ExportList.Length -eq 0)) {
        return
    }

    # load snapins into runspaces, if allowed
    $snapins = (Get-PSSnapin | Where-Object { !$_.IsDefault }).Name | Sort-Object -Unique

    foreach ($snapin in $snapins) {
        # only exported snapins? is the snapin exported?
        if ($PodeContext.Server.AutoImport.Snapins.ExportOnly -and ($PodeContext.Server.AutoImport.Snapins.ExportList -inotcontains $snapin)) {
            continue
        }

        $PodeContext.RunspaceState.ImportPSSnapIn($snapin, [ref]$null)
    }
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

    # main runspace - for timers, schedules, etc
    $totalThreadCount = ($threadsCounts.Values | Measure-Object -Sum).Sum
    $PodeContext.RunspacePools.Main = [runspacefactory]::CreateRunspacePool(1, $totalThreadCount, $PodeContext.RunspaceState, $Host)

    # web runspace - if we have any http/s endpoints
    if (Test-PodeEndpoints -Type Http) {
        $PodeContext.RunspacePools.Web = [runspacefactory]::CreateRunspacePool(1, ($PodeContext.Threads.General + 1), $PodeContext.RunspaceState, $Host)
    }

    # smtp runspace - if we have any smtp endpoints
    if (Test-PodeEndpoints -Type Smtp) {
        $PodeContext.RunspacePools.Smtp = [runspacefactory]::CreateRunspacePool(1, ($PodeContext.Threads.General + 1), $PodeContext.RunspaceState, $Host)
    }

    # tcp runspace - if we have any tcp endpoints
    if (Test-PodeEndpoints -Type Tcp) {
        $PodeContext.RunspacePools.Tcp = [runspacefactory]::CreateRunspacePool(1, ($PodeContext.Threads.General + 1), $PodeContext.RunspaceState, $Host)
    }

    # web socket runspace - if we have any ws/s endpoints
    if (Test-PodeEndpoints -Type Ws) {
        $PodeContext.RunspacePools.Signals = [runspacefactory]::CreateRunspacePool(1, 3, $PodeContext.RunspaceState, $Host)
    }

    # setup schedule runspace pool
    $PodeContext.RunspacePools.Schedules = [runspacefactory]::CreateRunspacePool(1, $PodeContext.Threads.Schedules, $PodeContext.RunspaceState, $Host)

    # setup gui runspace pool (only for non-ps-core)
    if (!$PodeContext.Server.IsServerless -and !((Test-PodeIsPSCore) -and ($PSVersionTable.PSVersion.Major -eq 6))) {
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
        Add-Member -MemberType NoteProperty -Name Metrics -Value $Context.Metrics -PassThru |
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
        Enabled = (($null -eq $Configuration.Logging.Enable) -or [bool]$Configuration.Logging.Enable)
        Masking = @{
            Patterns = (Remove-PodeEmptyItemsFromArray -Array @($Configuration.Logging.Masking.Patterns))
            Mask = (Protect-PodeValue -Value $Configuration.Logging.Masking.Mask -Default '********')
        }
        Types = @{}
    }

    # sockets
    if (!(Test-PodeIsEmpty $Configuration.Ssl.Protocols)) {
        $Context.Server.Sockets.Ssl.Protocols = (ConvertTo-PodeSslProtocols -Protocols $Configuration.Ssl.Protocols)
    }

    if ([int]$Configuration.ReceiveTimeout -gt 0) {
        $Context.Server.Sockets.ReceiveTimeout = (Protect-PodeValue -Value $Configuration.ReceiveTimeout $Context.Server.Sockets.ReceiveTimeout)
    }

    # auto-import
    $Context.Server.AutoImport = @{
        Modules = @{
            Enabled = (($null -eq $Configuration.AutoImport.Modules.Enable) -or [bool]$Configuration.AutoImport.Modules.Enable)
            ExportList = @()
            ExportOnly = ([bool]$Configuration.AutoImport.Modules.ExportOnly)
        }
        Snapins = @{
            Enabled = (($null -eq $Configuration.AutoImport.Snapins.Enable) -or [bool]$Configuration.AutoImport.Snapins.Enable)
            ExportList = @()
            ExportOnly = ([bool]$Configuration.AutoImport.Snapins.ExportOnly)
        }
        Functions = @{
            Enabled = (($null -eq $Configuration.AutoImport.Functions.Enable) -or [bool]$Configuration.AutoImport.Functions.Enable)
            ExportList = @()
            ExportOnly = ([bool]$Configuration.AutoImport.Functions.ExportOnly)
        }
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
        TransferEncoding = @{
            Default = $Configuration.TransferEncoding.Default
            Routes = @{}
        }
        Compression = @{
            Enabled = [bool]$Configuration.Compression.Enable
        }
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