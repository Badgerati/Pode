function New-PodeContext
{
    param (
        [scriptblock]
        $ScriptBlock,

        [int]
        $Threads = 1,

        [int]
        $Interval = 0,

        [string]
        $ServerRoot,

        [string]
        $Name = $null,

        [string[]]
        $FileMonitorExclude = $null,

        [string[]]
        $FileMonitorInclude = $null,

        [string]
        $ServerType,

        [switch]
        $DisableLogging,

        [switch]
        $FileMonitor
    )

    # set a random server name if one not supplied
    if (Test-Empty $Name) {
        $Name = Get-PodeRandomName
    }

    # are we running in a serverless context
    $isServerless = (@('azure-functions', 'aws-lambda') -icontains $ServerType)

    # ensure threads are always >0, for to 1 if we're serverless
    if (($Threads -le 0) -or $isServerless) {
        $Threads = 1
    }

    # basic context object
    $ctx = New-Object -TypeName psobject |
        Add-Member -MemberType NoteProperty -Name Threads -Value $Threads -PassThru |
        Add-Member -MemberType NoteProperty -Name Timers -Value @{} -PassThru |
        Add-Member -MemberType NoteProperty -Name Schedules -Value @{} -PassThru |
        Add-Member -MemberType NoteProperty -Name RunspacePools -Value $null -PassThru |
        Add-Member -MemberType NoteProperty -Name Runspaces -Value $null -PassThru |
        Add-Member -MemberType NoteProperty -Name RunspaceState -Value $null -PassThru |
        Add-Member -MemberType NoteProperty -Name Tokens -Value @{} -PassThru |
        Add-Member -MemberType NoteProperty -Name RequestsToLog -Value $null -PassThru |
        Add-Member -MemberType NoteProperty -Name Lockable -Value $null -PassThru |
        Add-Member -MemberType NoteProperty -Name Server -Value @{} -PassThru

    # set the server name, logic and root
    $ctx.Server.Name = $Name
    $ctx.Server.Logic = $ScriptBlock
    $ctx.Server.Interval = $Interval
    $ctx.Server.PodeModulePath = (Get-PodeModulePath)

    # check if there is any global configuration
    $ctx.Server.Configuration = Open-PodeConfiguration -ServerRoot $ServerRoot -Context $ctx

    # configure the server's root path
    $ctx.Server.Root = $ServerRoot
    if (!(Test-Empty $ctx.Server.Configuration.server.root)) {
        $ctx.Server.Root = Get-PodeRelativePath -Path $ctx.Server.Configuration.server.root -RootPath $ctx.Server.Root -JoinRoot -Resolve -TestPath
    }

    # setup file monitoring details (code has priority over config)
    if (!(Test-Empty $ctx.Server.Configuration)) {
        if (!$FileMonitor) {
            $FileMonitor = [bool]$ctx.Server.Configuration.server.fileMonitor.enable
        }

        if (Test-Empty $FileMonitorExclude) {
            $FileMonitorExclude = @($ctx.Server.Configuration.server.fileMonitor.exclude)
        }

        if (Test-Empty $FileMonitorInclude) {
            $FileMonitorInclude = @($ctx.Server.Configuration.server.fileMonitor.include)
        }
    }

    $ctx.Server.FileMonitor = @{
        Enabled = $FileMonitor
        Exclude = (Convert-PodePathPatternsToRegex -Paths $FileMonitorExclude)
        Include = (Convert-PodePathPatternsToRegex -Paths $FileMonitorInclude)
        ShowFiles = [bool]$ctx.Server.Configuration.server.fileMonitor.showFiles
        Files = @()
    }

    # set the server default type
    $ctx.Server.Type = ([string]::Empty)
    if ($Interval -gt 0) {
        $ctx.Server.Type = 'SERVICE'
    }

    if ($isServerless) {
        $ctx.Server.Type = $ServerType.ToUpperInvariant()
        $ctx.Server.IsServerless = $isServerless
    }

    # set the IP address details
    $ctx.Server.Endpoints = @()

    # setup gui details
    $ctx.Server.Gui = @{}

    # shared temp drives
    $ctx.Server.Drives = @{}
    $ctx.Server.InbuiltDrives = @{}

    # shared state between runspaces
    $ctx.Server.State = @{}

    # view engine for rendering pages
    $ctx.Server.ViewEngine = @{
        'Engine' = 'html';
        'Extension' = 'html';
        'Script' = $null;
        'IsDynamic' = $false;
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
        'tcp' = $null;
        'smtp' = $null;
        'service' = $null;
    }

    # setup basic access placeholders
    $ctx.Server.Access = @{
        'Allow' = @{};
        'Deny' = @{};
    }

    # setup basic limit rules
    $ctx.Server.Limits = @{
        'Rules' = @{};
        'Active' = @{};
    }

    # cookies and session logic
    $ctx.Server.Cookies = @{
        'Session' = @{};
        'Csrf' = @{};
        'Secrets' = @{};
    }

    # authnetication methods
    $ctx.Server.Authentications = @{}

    # logging methods
    $ctx.Server.Logging = @{
        'Methods' = @{};
        'Disabled' = $DisableLogging;
    }

    # create new cancellation tokens
    $ctx.Tokens = @{
        'Cancellation' = New-Object System.Threading.CancellationTokenSource;
        'Restart' = New-Object System.Threading.CancellationTokenSource;
    }

    # requests that should be logged
    $ctx.RequestsToLog = New-Object System.Collections.ArrayList

    # middleware that needs to run
    $ctx.Server.Middleware = @()

    # endware that needs to run
    $ctx.Server.Endware = @()

    # runspace pools
    $ctx.RunspacePools = @{
        'Main' = $null;
        'Schedules' = $null;
        'Gui' = $null;
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
        (New-Object System.Management.Automation.Runspaces.SessionStateVariableEntry -ArgumentList 'PODE_IN_RUNSPACE', $true, $null)
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
        'Default' = 1;
        'Timer' = 1;
        'Log' = 1;
        'Schedule' = 1;
        'Misc' = 1;
    }

    $totalThreadCount = ($threadsCounts.Values | Measure-Object -Sum).Sum + $PodeContext.Threads
    $PodeContext.RunspacePools.Main = [runspacefactory]::CreateRunspacePool(1, $totalThreadCount, $PodeContext.RunspaceState, $Host)
    $PodeContext.RunspacePools.Main.Open()

    # setup schedule runspace pool
    $PodeContext.RunspacePools.Schedules = [runspacefactory]::CreateRunspacePool(1, 2, $PodeContext.RunspaceState, $Host)
    $PodeContext.RunspacePools.Schedules.Open()

    # setup gui runspace pool (only for non-ps-core)
    if (!(Test-IsPSCore)) {
        $PodeContext.RunspacePools.Gui = [runspacefactory]::CreateRunspacePool(1, 1, $PodeContext.RunspaceState, $Host)
        $PodeContext.RunspacePools.Gui.ApartmentState = 'STA'
        $PodeContext.RunspacePools.Gui.Open()
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
        Add-Member -MemberType NoteProperty -Name RequestsToLog -Value $Context.RequestsToLog -PassThru |
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
    $configPath = (Join-PodeServerRoot -Folder '.' -FilePath 'pode.json' -Root $ServerRoot)

    # check to see if an environmental config exists (if the env var is set)
    if (!(Test-Empty $env:PODE_ENVIRONMENT)) {
        $_path = (Join-PodeServerRoot -Folder '.' -FilePath "pode.$($env:PODE_ENVIRONMENT).json" -Root $ServerRoot)
        if (Test-PodePath -Path $_path -NoStatus) {
            $configPath = $_path
        }
    }

    # check the path exists, and load the config
    if (Test-PodePath -Path $configPath -NoStatus) {
        $config = (Get-Content $configPath -Raw | ConvertFrom-Json)
        Set-PodeWebConfiguration -Configuration $config -Context $Context
    }

    return $config
}

function Set-PodeWebConfiguration
{
    param (
        [Parameter()]
        $Configuration,

        [Parameter()]
        $Context
    )

    # setup the main web config
    $Context.Server.Web = @{
        'Static' = @{
            'Defaults' = $Configuration.web.static.defaults;
            'Cache' = @{
                'Enabled' = [bool]$Configuration.web.static.cache.enable;
                'MaxAge' = [int](coalesce $Configuration.web.static.cache.maxAge 3600);
                'Include' = (Convert-PodePathPatternsToRegex -Paths @($Configuration.web.static.cache.include) -NotSlashes);
                'Exclude' = (Convert-PodePathPatternsToRegex -Paths @($Configuration.web.static.cache.exclude) -NotSlashes);
            }
        };
        'ErrorPages' = @{
            'ShowExceptions' = [bool]$Configuration.web.errorPages.showExceptions;
            'StrictContentTyping' = [bool]$Configuration.web.errorPages.strictContentTyping;
            'Default' = $Configuration.web.errorPages.default;
            'Routes' = @{};
        };
        'ContentType' = @{
            'Default' = $Configuration.web.contentType.default;
            'Routes' = @{};
        };
    }

    # setup content type route patterns for forced content types
    if ($null -ne $Configuration.web.contentType.routes) {
        $Configuration.web.contentType.routes.psobject.properties.name | ForEach-Object {
            $_pattern = $_
            $_type = $Configuration.web.contentType.routes.$_pattern
            $_pattern = (Convert-PodePathPatternToRegex -Path $_pattern -NotSlashes)
            $Context.Server.Web.ContentType.Routes[$_pattern] = $_type
        }
    }

    # setup content type route patterns for error pages
    if ($null -ne $Configuration.web.errorPages.routes) {
        $Configuration.web.errorPages.routes.psobject.properties.name | ForEach-Object {
            $_pattern = $_
            $_type = $Configuration.web.errorPages.routes.$_pattern
            $_pattern = (Convert-PodePathPatternToRegex -Path $_pattern -NotSlashes)
            $Context.Server.Web.ErrorPages.Routes[$_pattern] = $_type
        }
    }
}

function New-PodeAutoRestartServer
{
    # don't configure if not supplied, or running as serverless
    $config = (config)
    if (($null -eq $config) -or ($null -eq $config.server.restart) -or $PodeContext.Server.IsServerless)  {
        return
    }

    $restart = $config.server.restart

    # period - setup a timer
    $period = [int]$restart.period
    if ($period -gt 0) {
        Timer -Name '__pode_restart_period__' -Interval ($period * 60) -ScriptBlock {
            $PodeContext.Tokens.Restart.Cancel()
        } -Skip 1
    }

    # times - convert into cron expressions
    $times = @(@($restart.times) -ne $null)
    if (($times | Measure-Object).Count -gt 0) {
        $crons = @()

        @($times) | ForEach-Object {
            $atoms = $_ -split '\:'
            $crons += "$([int]$atoms[1]) $([int]$atoms[0]) * * *"
        }

        Schedule -Name '__pode_restart_times__' -Cron @($crons) -ScriptBlock {
            $PodeContext.Tokens.Restart.Cancel()
        }
    }

    # crons - setup schedules
    $crons = @(@($restart.crons) -ne $null)
    if (($crons | Measure-Object).Count -gt 0) {
        Schedule -Name '__pode_restart_crons__' -Cron @($crons) -ScriptBlock {
            $PodeContext.Tokens.Restart.Cancel()
        }
    }
}