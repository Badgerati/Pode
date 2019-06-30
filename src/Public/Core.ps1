function Get-PodeConfiguration
{
    return (config)
}

function Config
{
    return $PodeContext.Server.Configuration
}

function Endware
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [scriptblock]
        $ScriptBlock
    )

    # add the scriptblock to array of endware that needs to be run
    $PodeContext.Server.Endware += $ScriptBlock
}

function Engine
{
    param (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [Alias('t')]
        [string]
        $Engine,

        [Parameter()]
        [Alias('s')]
        [scriptblock]
        $ScriptBlock = $null,

        [Parameter()]
        [Alias('ext')]
        [string]
        $Extension
    )

    if ([string]::IsNullOrWhiteSpace($Extension)) {
        $Extension = $Engine.ToLowerInvariant()
    }

    $PodeContext.Server.ViewEngine.Engine = $Engine.ToLowerInvariant()
    $PodeContext.Server.ViewEngine.Extension = $Extension
    $PodeContext.Server.ViewEngine.Script = $ScriptBlock
    $PodeContext.Server.ViewEngine.IsDynamic = ($Engine -ine 'html')
}

function Gui
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [Alias('n')]
        [string]
        $Name,

        [Parameter()]
        [Alias('o')]
        [hashtable]
        $Options
    )

    # error if serverless
    Test-PodeIsServerless -FunctionName 'gui' -ThrowError

    # only valid for Windows PowerShell
    if (Test-IsPSCore) {
        throw 'The gui function is currently unavailable for PS Core, and only works for Windows PowerShell'
    }

    # enable the gui and set it's title/name
    $PodeContext.Server.Gui.Enabled = $true
    $PodeContext.Server.Gui.Name = $Name

    # coalesce the options
    $Options = (coalesce $Options @{})

    # set the window's icon path
    if (![string]::IsNullOrWhiteSpace($Options.Icon)) {
        $PodeContext.Server.Gui.Icon = (Resolve-Path $Options.Icon).Path
        if (!(Test-Path $PodeContext.Server.Gui.Icon)) {
            throw "Path to icon for GUI does not exist: $($PodeContext.Server.Gui.Icon)"
        }
    }

    # display the app in the taskbar?
    $PodeContext.Server.Gui.ShowInTaskbar = (coalesce $Options.ShowInTaskbar $true)

    # set the window's state
    $states = @('Normal', 'Maximized', 'Minimized')
    $PodeContext.Server.Gui.State = (coalesce $Options.State 'Normal')
    if ($states -inotcontains $PodeContext.Server.Gui.State) {
        throw "Invalid GUI window state supplied, should be blank or one of $($states -join ' / ')"
    }

    # set the window's style
    $styles = @('None', 'SingleBorderWindow', 'ThreeDBorderWindow', 'ToolWindow')
    $PodeContext.Server.Gui.WindowStyle = (coalesce $Options.WindowStyle 'SingleBorderWindow')
    if ($styles -inotcontains $PodeContext.Server.Gui.WindowStyle) {
        throw "Invalid GUI window style supplied, should be blank or one of $($styles -join ' / ')"
    }

    # set the height of the window
    $PodeContext.Server.Gui.Height = (coalesce ([int]$Options.Height) 0)
    if ($PodeContext.Server.Gui.Height -le 0) {
        $PodeContext.Server.Gui.Height = 'auto'
    }

    # set the width of the window
    $PodeContext.Server.Gui.Width = (coalesce ([int]$Options.Width) 0)
    if ($PodeContext.Server.Gui.Width -le 0) {
        $PodeContext.Server.Gui.Width = 'auto'
    }

    # set the resize mode of the window
    $modes = @('CanResize', 'CanMinimize', 'NoResize')
    $PodeContext.Server.Gui.ResizeMode = (coalesce $Options.ResizeMode 'CanResize')
    if ($modes -inotcontains $PodeContext.Server.Gui.ResizeMode) {
        throw "Invalid GUI window resize mode supplied, should be blank or one of $($modes -join ' / ')"
    }

    # set the gui to use a specific listener
    $PodeContext.Server.Gui.ListenName = $Options.ListenName

    if (!(Test-Empty $PodeContext.Server.Gui.ListenName)) {
        $found = ($PodeContext.Server.Endpoints | Where-Object {
            $_.Name -eq $PodeContext.Server.Gui.ListenName
        } | Select-Object -First 1)

        if ($null -eq $found) {
            throw "Listen endpoint with name '$($Name)' does not exist"
        }

        $PodeContext.Server.Gui.Endpoint = $found
    }
}

function Handler
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet('SMTP', 'TCP', 'Service')]
        [string]
        $Type,

        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [scriptblock]
        $ScriptBlock
    )

    # error if serverless
    Test-PodeIsServerless -FunctionName 'handler' -ThrowError

    # lower the type
    $Type = $Type.ToLowerInvariant()

    # ensure handler isn't already set
    if ($null -ne $PodeContext.Server.Handlers[$Type]) {
        throw "Handler for $($Type) already defined"
    }

    # add the handler
    $PodeContext.Server.Handlers[$Type] = $ScriptBlock
}

function Script
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Path
    )

    Import -Path $Path
}

function Import
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [Alias('p')]
        [string]
        $Path,

        [switch]
        [Alias('n')]
        $Now,

        [switch]
        [Alias('si')]
        $SnapIn
    )

    # for a snapin, just import it; for a module we need to check paths
    if ($SnapIn)
    {
        # if non-windows or core, fail
        if ((Test-IsPSCore) -or (Test-IsUnix)) {
            throw 'SnapIns are only supported on Windows PowerShell'
        }

        # import the snap-in into the runspace state
        $exp = $null
        $PodeContext.RunspaceState.ImportPSSnapIn($Path, ([ref]$exp))

        # import the snap-in now, if specified
        if ($Now) {
            Add-PSSnapin -Name $Path | Out-Null
        }
    }
    else
    {
        # if path is '.', replace with server root
        $_path = Get-PodeRelativePath -Path $Path -JoinRoot -Resolve

        # if the resolved path is empty, then it's a module name that was supplied
        if (Test-Empty $_path) {
            # check to see if module is in ps_modules
            $_psModulePath = Join-PodeServerRoot -Folder (Join-PodePaths @('ps_modules', $Path))
            if (Test-Path $_psModulePath) {
                $_path = (Get-ChildItem (Join-PodePaths @($_psModulePath, '*', "$($Path).ps*1")) -Recurse -Force | Select-Object -First 1).FullName
            }

            # otherwise, use a global module
            else {
                $_path = (Get-Module -Name $Path -ListAvailable | Select-Object -First 1).Path
            }
        }

        # else, we have a path, if it's a directory/wildcard then loop over all files
        else {
            $_paths = Get-PodeWildcardFiles -Path $Path -Wildcard '*.ps*1'
            if (!(Test-Empty $_paths)) {
                foreach ($_path in $_paths) {
                    import -Path $_path -Now:$Now
                }

                return
            }
        }

        # if it's still empty, error
        if (Test-Empty $_path) {
            throw "Failed to import module: $($Path)"
        }

        # check if the path exists
        if (!(Test-PodePath $_path -NoStatus)) {
            throw "The module path does not exist: $(coalesce $_path $Path)"
        }

        # import the module into the runspace state
        $PodeContext.RunspaceState.ImportPSModule($_path)

        # import the module now, if specified
        if ($Now) {
            Import-Module $_path -Force -DisableNameChecking -Scope Global -ErrorAction Stop | Out-Null
        }
    }
}

function Listen
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [Alias('ipp', 'e', 'endpoint')]
        [string]
        $IPPort,

        [Parameter()]
        [ValidateSet('HTTP', 'HTTPS', 'SMTP', 'TCP')]
        [Alias('t')]
        [string]
        $Type,

        [Parameter()]
        [Alias('cert', 'cname')]
        [string]
        $Certificate = $null,

        [Parameter()]
        [Alias('thumb', 'cthumb')]
        [string]
        $Thumbprint = $null,

        [Parameter()]
        [Alias('n', 'id')]
        [string]
        $Name = $null,

        [switch]
        [Alias('f')]
        $Force
    )

    # error if serverless
    Test-PodeIsServerless -FunctionName 'listen' -ThrowError

    # parse the endpoint for host/port info
    $_endpoint = Get-PodeEndpointInfo -Endpoint $IPPort

    # if a name was supplied, check it is unique
    if (!(Test-Empty $Name) -and
        (Get-PodeCount ($PodeContext.Server.Endpoints | Where-Object { $_.Name -eq $Name })) -ne 0)
    {
        throw "An endpoint with the name '$($Name)' has already been defined"
    }

    # new endpoint object
    $obj = @{
        'Name' = $Name;
        'Address' = $null;
        'RawAddress' = $IPPort;
        'Port' = $null;
        'IsIPAddress' = $true;
        'HostName' = 'localhost';
        'Ssl' = $false;
        'Protocol' = $Type;
        'Certificate' = @{
            'Name' = $null;
            'Thumbprint' = $null;
        };
    }

    # set the ip for the context
    $obj.Address = (Get-PodeIPAddress $_endpoint.Host)
    if (!(Test-PodeIPAddressLocalOrAny -IP $obj.Address)) {
        $obj.HostName = "$($obj.Address)"
    }

    $obj.IsIPAddress = (Test-PodeIPAddress -IP $obj.Address -IPOnly)

    # set the port for the context
    $obj.Port = $_endpoint.Port

    # if the server type is https, set cert details
    if ($Type -ieq 'https') {
        $obj.Ssl = $true
        $obj.Certificate.Name = $Certificate
        $obj.Certificate.Thumbprint = $Thumbprint
    }

    # if the address is non-local, then check admin privileges
    if (!$Force -and !(Test-PodeIPAddressLocal -IP $obj.Address) -and !(Test-IsAdminUser)) {
        throw 'Must be running with administrator priviledges to listen on non-localhost addresses'
    }

    # has this endpoint been added before? (for http/https we can just not add it again)
    $exists = ($PodeContext.Server.Endpoints | Where-Object {
        ($_.Address -eq $obj.Address) -and ($_.Port -eq $obj.Port) -and ($_.Ssl -eq $obj.Ssl)
    } | Measure-Object).Count

    if (!$exists) {
        # has an endpoint already been defined for smtp/tcp?
        if (@('smtp', 'tcp') -icontains $Type -and $Type -ieq $PodeContext.Server.Type) {
            throw "An endpoint for $($Type.ToUpperInvariant()) has already been defined"
        }

        # set server type, ensure we aren't trying to change the server's type
        $_type = (iftet ($Type -ieq 'https') 'http' $Type)
        if ([string]::IsNullOrWhiteSpace($PodeContext.Server.Type)) {
            $PodeContext.Server.Type = $_type
        }
        elseif ($PodeContext.Server.Type -ine $_type) {
            throw "Cannot add $($Type.ToUpperInvariant()) endpoint when already listening to $($PodeContext.Server.Type.ToUpperInvariant()) endpoints"
        }

        # add the new endpoint
        $PodeContext.Server.Endpoints += $obj
    }
}

function Load
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [Alias('p')]
        [string]
        $Path
    )

    # if path is '.', replace with server root
    $_path = Get-PodeRelativePath -Path $Path -JoinRoot -Resolve

    # we have a path, if it's a directory/wildcard then loop over all files
    if (!(Test-Empty $_path)) {
        $_paths = Get-PodeWildcardFiles -Path $Path -Wildcard '*.ps1'
        if (!(Test-Empty $_paths)) {
            foreach ($_path in $_paths) {
                load -Path $_path
            }

            return
        }
    }

    # check if the path exists
    if (!(Test-PodePath $_path -NoStatus)) {
        throw "The script path does not exist: $(coalesce $_path $Path)"
    }

    # dot-source the script
    . $_path
}

function Logger
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [Alias('n')]
        [string]
        $Name,

        [Parameter()]
        [Alias('d')]
        [object]
        $Details = $null,

        [switch]
        [Alias('c')]
        $Custom
    )

    # error if serverless
    Test-PodeIsServerless -FunctionName 'logger' -ThrowError

    # is logging disabled?
    if ($PodeContext.Server.Logging.Disabled) {
        Write-Host "Logging has been disabled for $($Name)" -ForegroundColor DarkCyan
        return
    }

    # set the logger as custom if flag is passed
    if ($Name -inotlike 'custom_*' -and $Custom) {
        $Name = "custom_$($Name)"
    }

    # lowercase the name
    $Name = $Name.ToLowerInvariant()

    # ensure the logger doesn't already exist
    if ($PodeContext.Server.Logging.Methods.ContainsKey($Name)) {
        throw "Logger called $($Name) already exists"
    }

    # ensure the details are of a correct type (inbuilt=hashtable, custom=scriptblock)
    $type = (Get-PodeType $Details)

    if ($Name -ilike 'custom_*') {
        if ($null -eq $Details) {
            throw 'For custom loggers, a ScriptBlock is required'
        }

        if ($type.Name -ine 'scriptblock') {
            throw "Custom logger details should be a ScriptBlock, but got: $($type.Name)"
        }
    }
    else {
        if ($null -ne $Details -and $type.Name -ine 'hashtable') {
            throw "Inbuilt logger details should be a HashTable, but got: $($type.Name)"
        }
    }

    # add the logger, along with any given details (hashtable/scriptblock)
    $PodeContext.Server.Logging.Methods[$Name] = $Details

    # if a file logger, create base directory (file is a dummy file, and won't be created)
    if ($Name -ieq 'file') {
        # has a specific logging path been supplied?
        if ($null -eq $Details -or (Test-Empty $Details.Path)) {
            $path = (Split-Path -Parent -Path (Join-PodeServerRoot 'logs' 'tmp.txt'))
        }
        else {
            $path = $Details.Path
        }

        Write-Host "Log Path: $($path)" -ForegroundColor DarkCyan
        New-Item -Path $path -ItemType Directory -Force | Out-Null
    }
}

function Middleware
{
    param (
        [Parameter(Mandatory=$true, Position=0, ParameterSetName='Script')]
        [Parameter(Mandatory=$true, Position=1, ParameterSetName='ScriptRoute')]
        [ValidateNotNull()]
        [scriptblock]
        $ScriptBlock,

        [Parameter(Mandatory=$true, Position=0, ParameterSetName='ScriptRoute')]
        [Parameter(Mandatory=$true, Position=0, ParameterSetName='HashRoute')]
        [Alias('r')]
        [string]
        $Route,

        [Parameter(Mandatory=$true, Position=0, ParameterSetName='Hash')]
        [Parameter(Mandatory=$true, Position=1, ParameterSetName='HashRoute')]
        [Alias('h')]
        [hashtable]
        $HashTable,

        [Parameter()]
        [Alias('n')]
        [string]
        $Name,

        [switch]
        $Return
    )

    # if a name was supplied, ensure it doesn't already exist
    if (!(Test-Empty $Name)) {
        if (($PodeContext.Server.Middleware | Where-Object { $_.Name -ieq $Name } | Measure-Object).Count -gt 0) {
            throw "Middleware with defined name of $($Name) already exists"
        }
    }

    # if route is empty, set it to root
    $Route = Coalesce $Route '/'
    $Route = Split-PodeRouteQuery -Route $Route
    $Route = Coalesce $Route '/'
    $Route = Update-PodeRouteSlashes -Route $Route
    $Route = Update-PodeRoutePlaceholders -Route $Route

    # create the middleware hash, or re-use a passed one
    if (Test-Empty $HashTable)
    {
        $HashTable = @{
            'Name' = $Name;
            'Route' = $Route;
            'Logic' = $ScriptBlock;
        }
    }
    else
    {
        if (Test-Empty $HashTable.Logic) {
            throw 'Middleware supplied has no Logic'
        }

        if (Test-Empty $HashTable.Route) {
            $HashTable.Route = $Route
        }

        if (Test-Empty $HashTable.Name) {
            $HashTable.Name = $Name
        }
    }

    # add the scriptblock to array of middleware that needs to be run
    if ($Return) {
        return $HashTable
    }
    else {
        $PodeContext.Server.Middleware += $HashTable
    }
}

function Route
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet('DELETE', 'GET', 'HEAD', 'MERGE', 'OPTIONS', 'PATCH', 'POST', 'PUT', 'TRACE', 'STATIC', '*')]
        [Alias('hm')]
        [string]
        $HttpMethod,

        [Parameter(Mandatory=$true)]
        [Alias('r')]
        [string]
        $Route,

        [Parameter()]
        [Alias('m')]
        [object[]]
        $Middleware,

        [Parameter()]
        [Alias('s')]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [Alias('d')]
        [string[]]
        $Defaults,

        [Parameter()]
        [ValidateSet('', 'HTTP', 'HTTPS')]
        [Alias('p')]
        [string]
        $Protocol,

        [Parameter()]
        [Alias('e')]
        [string]
        $Endpoint,

        [Parameter()]
        [Alias('ln', 'lid')]
        [string]
        $ListenName,

        [Parameter()]
        [Alias('ctype', 'ct')]
        [string]
        $ContentType,

        [Parameter()]
        [Alias('etype', 'et')]
        [string]
        $ErrorType,

        [Parameter()]
        [Alias('fp')]
        [string]
        $FilePath,

        [switch]
        [Alias('rm')]
        $Remove,

        [switch]
        [Alias('do')]
        $DownloadOnly
    )

    # uppercase the method
    $HttpMethod = $HttpMethod.ToUpperInvariant()

    # if a ListenName was supplied, find it and use it
    if (!(Test-Empty $ListenName)) {
        # ensure it exists
        $found = ($PodeContext.Server.Endpoints | Where-Object { $_.Name -eq $ListenName } | Select-Object -First 1)
        if ($null -eq $found) {
            throw "Listen endpoint with name '$($ListenName)' does not exist"
        }

        # override and set the protocol and endpoint
        $Protocol = $found.Protocol
        $Endpoint = $found.RawAddress
    }

    # if an endpoint was supplied (or used from a listen name), set any appropriate wildcards
    if (!(Test-Empty $Endpoint)) {
        $_endpoint = Get-PodeEndpointInfo -Endpoint $Endpoint -AnyPortOnZero
        $Endpoint = "$($_endpoint.Host):$($_endpoint.Port)"
    }

    # are we removing the route's logic?
    if ($Remove) {
        Remove-PodeRoute -HttpMethod $HttpMethod -Route $Route -Protocol $Protocol -Endpoint $Endpoint
        return
    }

    # add a new dynamic or static route
    if ($HttpMethod -ieq 'static') {
        Add-PodeStaticRoute -Route $Route -Source ([string](@($Middleware))[0]) -Protocol $Protocol `
            -Endpoint $Endpoint -Defaults $Defaults -DownloadOnly:$DownloadOnly
    }
    else {
        # error if defaults are defined
        if ((Get-PodeCount $Defaults) -gt 0) {
            throw "[$($HttpMethod)] $($Route) has default static files defined, which is only for [STATIC] routes"
        }

        # error if download only passed
        if ($DownloadOnly) {
            throw "[$($HttpMethod)] $($Route) is flagged as DownloadOnly, which is only for [STATIC] routes"
        }

        # add the route
        Add-PodeRoute -HttpMethod $HttpMethod -Route $Route -Middleware $Middleware -ScriptBlock $ScriptBlock `
            -Protocol $Protocol -Endpoint $Endpoint -ContentType $ContentType -ErrorType $ErrorType -FilePath $FilePath
    }
}

function Schedule
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $Cron,

        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [Alias('l')]
        [int]
        $Limit = 0,

        [Parameter()]
        [Alias('start', 's')]
        $StartTime = $null,

        [Parameter()]
        [Alias('end', 'e')]
        $EndTime = $null
    )

    # error if serverless
    Test-PodeIsServerless -FunctionName 'schedule' -ThrowError

    # lower the name
    $Name = $Name.ToLowerInvariant()

    # ensure the schedule doesn't already exist
    if ($PodeContext.Schedules.ContainsKey($Name)) {
        throw "Schedule called $($Name) already exists"
    }

    # ensure the limit is valid
    if ($Limit -lt 0) {
        throw "Schedule $($Name) cannot have a negative limit"
    }

    # ensure the start/end dates are valid
    if ($null -ne $EndTime -and $EndTime -lt [DateTime]::Now) {
        throw "Schedule $($Name) must have an EndTime in the future"
    }

    if ($null -ne $StartTime -and $null -ne $EndTime -and $EndTime -lt $StartTime) {
        throw "Schedule $($Name) cannot have a StartTime after the EndTime"
    }

    # add the schedule
    $PodeContext.Schedules[$Name] = @{
        'Name' = $Name;
        'StartTime' = $StartTime;
        'EndTime' = $EndTime;
        'Crons' = (ConvertFrom-PodeCronExpressions -Expressions @($Cron));
        'Limit' = $Limit;
        'Count' = 0;
        'Countable' = ($Limit -gt 0);
        'Script' = $ScriptBlock;
    }
}

function Server
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [ValidateNotNull()]
        [Alias('p')]
        [int]
        $Port = 0,

        [Parameter()]
        [ValidateNotNull()]
        [Alias('i')]
        [int]
        $Interval = 0,

        [Parameter()]
        [string]
        $IP,

        [Parameter()]
        [Alias('n')]
        [string]
        $Name,

        [Parameter()]
        [Alias('t')]
        [int]
        $Threads = 1,

        [Parameter()]
        [Alias('fme')]
        [string[]]
        $FileMonitorExclude,

        [Parameter()]
        [Alias('fmi')]
        [string[]]
        $FileMonitorInclude,

        [Parameter()]
        [Alias('rp', 'root')]
        [string]
        $RootPath,

        [Parameter()]
        [Alias('r', 'req')]
        $Request,

        [Parameter()]
        [ValidateSet('', 'Azure-Functions', 'Aws-Lambda')]
        [string]
        $Type,

        [switch]
        $Smtp,

        [switch]
        $Tcp,

        [switch]
        $Http,

        [switch]
        $Https,

        [switch]
        [Alias('dt')]
        $DisableTermination,

        [switch]
        [Alias('dl')]
        $DisableLogging,

        [switch]
        [Alias('fm')]
        $FileMonitor,

        [switch]
        [Alias('b')]
        $Browse
    )

    # ensure the session is clean
    $PodeContext = $null

    # validate port passed
    if ($Port -lt 0) {
        throw "Port cannot be negative: $($Port)"
    }

    # if an ip address was passed, ensure it's valid
    if (!(Test-Empty $IP) -and !(Test-PodeIPAddress $IP)) {
        throw "Invalid IP address has been supplied: $($IP)"
    }

    try {
        # get the current server type for legacy purposes
        $serverType = Get-PodeServerType -Port $Port -Interval $Interval -Smtp:$Smtp -Tcp:$Tcp -Https:$Https

        # configure the server's root path
        if (!(Test-Empty $RootPath)) {
            $RootPath = Get-PodeRelativePath -Path $RootPath -RootPath $MyInvocation.PSScriptRoot -JoinRoot -Resolve -TestPath
        }

        # create main context object
        $PodeContext = New-PodeContext -ScriptBlock $ScriptBlock `
            -Threads $Threads `
            -Interval $Interval `
            -ServerRoot (coalesce $RootPath $MyInvocation.PSScriptRoot) `
            -FileMonitorExclude $FileMonitorExclude `
            -FileMonitorInclude $FileMonitorInclude `
            -ServerType $Type `
            -DisableLogging:$DisableLogging `
            -FileMonitor:$FileMonitor

        # for legacy support, create initial listener from Server parameters
        if (@('http', 'https', 'smtp', 'tcp') -icontains $serverType) {
            listen "$($IP):$($Port)" $serverType
        }

        # set it so ctrl-c can terminate, unless serverless
        if (!$PodeContext.Server.IsServerless) {
            [Console]::TreatControlCAsInput = $true
        }

        # start the file monitor for interally restarting
        Start-PodeFileMonitor

        # start the server
        Start-PodeServer -Request $Request -Browse:$Browse

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
                Restart-PodeServer
            }
        }

        Write-Host 'Terminating...' -NoNewline -ForegroundColor Yellow
        $PodeContext.Tokens.Cancellation.Cancel()
    }
    finally {
        # clean the runspaces and tokens
        Close-Pode -Exit

        # clean the session
        $PodeContext = $null
    }
}

function Timer
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name,

        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [Alias('i')]
        [int]
        $Interval,

        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [Alias('l')]
        [int]
        $Limit = 0,

        [Parameter()]
        [Alias('s')]
        [int]
        $Skip = 0
    )

    # error if serverless
    Test-PodeIsServerless -FunctionName 'timer' -ThrowError

    # lower the name
    $Name = $Name.ToLowerInvariant()

    # ensure the timer doesn't already exist
    if ($PodeContext.Timers.ContainsKey($Name)) {
        throw "Timer called $($Name) already exists"
    }

    # is the interval valid?
    if ($Interval -le 0) {
        throw "Timer $($Name) cannot have an interval less than or equal to 0"
    }

    # is the limit valid?
    if ($Limit -lt 0) {
        throw "Timer $($Name) cannot have a negative limit"
    }

    if ($Limit -ne 0) {
        $Limit += $Skip
    }

    # is the skip valid?
    if ($Skip -lt 0) {
        throw "Timer $($Name) cannot have a negative skip value"
    }

    # run script if it's not being skipped
    if ($Skip -eq 0) {
        Invoke-ScriptBlock -ScriptBlock $ScriptBlock -Arguments @{ 'Lockable' = $PodeContext.Lockable } -Scoped
    }

    # add the timer
    $PodeContext.Timers[$Name] = @{
        'Name' = $Name;
        'Interval' = $Interval;
        'Limit' = $Limit;
        'Count' = 0;
        'Skip' = $Skip;
        'Countable' = ($Skip -gt 0 -or $Limit -gt 0);
        'NextTick' = [DateTime]::Now.AddSeconds($Interval);
        'Script' = $ScriptBlock;
    }
}