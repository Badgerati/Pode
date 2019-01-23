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

        [switch]
        $DisableLogging,

        [switch]
        $FileMonitor
    )

    # set a random server name if one not supplied
    if (Test-Empty $Name) {
        $Name = Get-RandomName
    }

    # ensure threads are always >0
    if ($Threads -le 0) {
        $Threads = 1
    }

    # basic context object
    $ctx = New-Object -TypeName psobject |
        Add-Member -MemberType NoteProperty -Name Threads -Value $Threads -PassThru |
        Add-Member -MemberType NoteProperty -Name Timers -Value @{} -PassThru |
        Add-Member -MemberType NoteProperty -Name Schedules -Value @{} -PassThru |
        Add-Member -MemberType NoteProperty -Name RunspacePools -Value $null -PassThru |
        Add-Member -MemberType NoteProperty -Name Runspaces -Value $null -PassThru |
        Add-Member -MemberType NoteProperty -Name Tokens -Value @{} -PassThru |
        Add-Member -MemberType NoteProperty -Name RequestsToLog -Value $null -PassThru |
        Add-Member -MemberType NoteProperty -Name Lockable -Value $null -PassThru |
        Add-Member -MemberType NoteProperty -Name Server -Value @{} -PassThru

    # set the server name, logic and root
    $ctx.Server.Name = $Name
    $ctx.Server.Root = $ServerRoot
    $ctx.Server.Logic = $ScriptBlock
    $ctx.Server.Interval = $Interval
    $ctx.Server.FileMonitor = $FileMonitor

    # set the server default type
    $ctx.Server.Type = ([string]::Empty)
    if ($Interval -gt 0) {
        $ctx.Server.Type = 'SERVICE'
    }

    # check if there is any global configuration
    $ctx.Server.Configuration = Open-PodeConfiguration -ServerRoot $ServerRoot

    # set the IP address details
    $ctx.Server.Endpoints = @()

    # setup gui details
    $ctx.Server.Gui = @{
        'Enabled' = $false;
        'Name' = $null;
        'Icon' = $null;
        'State' = 'Normal';
        'ShowInTaskbar' = $true;
        'WindowStyle' = 'SingleBorderWindow';
    }

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
    $state = [initialsessionstate]::CreateDefault()
    $state.ImportPSModule((Get-Module -Name Pode).Path)

    $_session = New-PodeStateContext $ctx

    $variables = @(
        (New-Object System.Management.Automation.Runspaces.SessionStateVariableEntry -ArgumentList 'PodeContext', $_session, $null),
        (New-Object System.Management.Automation.Runspaces.SessionStateVariableEntry -ArgumentList 'Console', $Host, $null)
    )

    $variables | ForEach-Object {
        $state.Variables.Add($_)
    }

    # setup runspaces
    $ctx.Runspaces = @()

    # setup main runspace pool
    $threadsCounts = @{
        'Default' = 1;
        'Timer' = 1;
        'Log' = 1;
        'Schedule' = 1;
        'Misc' = 1;
    }

    $totalThreadCount = ($threadsCounts.Values | Measure-Object -Sum).Sum + $Threads
    $ctx.RunspacePools.Main = [runspacefactory]::CreateRunspacePool(1, $totalThreadCount, $state, $Host)
    $ctx.RunspacePools.Main.Open()

    # setup schedule runspace pool
    $ctx.RunspacePools.Schedules = [runspacefactory]::CreateRunspacePool(1, 2, $state, $Host)
    $ctx.RunspacePools.Schedules.Open()

    # setup gui runspace pool (only for non-ps-core)
    if (!(Test-IsPSCore)) {
        $ctx.RunspacePools.Gui = [runspacefactory]::CreateRunspacePool(1, 1, $state, $Host)
        $ctx.RunspacePools.Gui.ApartmentState = 'STA'
        $ctx.RunspacePools.Gui.Open()
    }

    # return the new context
    return $ctx
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

function Get-PodeConfiguration
{
    return $PodeContext.Server.Configuration
}

function Open-PodeConfiguration
{
    param (
        [Parameter()]
        [string]
        $ServerRoot = $null
    )

    $config = @{}

    # set the path to the root config file
    $configPath = (Join-ServerRoot -Folder '.' -FilePath 'pode.json' -Root $ServerRoot)

    # check to see if an environmental config exists (if the env var is set)
    if (!(Test-Empty $env:PODE_ENVIRONMENT)) {
        $_path = (Join-ServerRoot -Folder '.' -FilePath "pode.$($env:PODE_ENVIRONMENT).json" -Root $ServerRoot)
        if (Test-PodePath -Path $_path -NoStatus) {
            $configPath = $_path
        }
    }

    # check the path exists, and load the config
    if (Test-PodePath -Path $configPath -NoStatus) {
        $config = (Get-Content $configPath -Raw | ConvertFrom-Json)
    }

    return $config
}

function State
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet('set', 'get', 'remove')]
        [Alias('a')]
        [string]
        $Action,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [Alias('n')]
        [string]
        $Name,

        [Parameter()]
        [Alias('o')]
        [object]
        $Object
    )

    try {
        if ($null -eq $PodeContext -or $null -eq $PodeContext.Server.State) {
            return $null
        }

        switch ($Action.ToLowerInvariant())
        {
            'set' {
                $PodeContext.Server.State[$Name] = $Object
            }

            'get' {
                $Object = $PodeContext.Server.State[$Name]
            }

            'remove' {
                $Object = $PodeContext.Server.State[$Name]
                $PodeContext.Server.State.Remove($Name) | Out-Null
            }
        }

        return $Object
    }
    catch {
        $Error[0] | Out-Default
        throw $_.Exception
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
        [Alias('cert')]
        [string]
        $Certificate = $null,

        [Parameter()]
        [Alias('n', 'id')]
        [string]
        $Name = $null,

        [switch]
        [Alias('f')]
        $Force
    )

    # parse the endpoint for host/port info
    $_endpoint = Get-PodeEndpointInfo -Endpoint $IPPort

    # if a name was supplied, check it is unique
    if (![string]::IsNullOrWhiteSpace($Name) -and
        (Get-Count ($PodeContext.Server.Endpoints | Where-Object { $_.Name -eq $Name })) -ne 0)
    {
        throw "An endpoint with the name '$($Name)' has already been defined"
    }

    # new endpoint object
    $obj = @{
        'Name' = $Name;
        'Address' = $null;
        'RawAddress' = $IPPort;
        'Port' = $null;
        'HostName' = 'localhost';
        'Ssl' = $false;
        'Protocol' = $Type;
        'Certificate' = @{
            'Name' = $null;
        };
    }

    # set the ip for the context
    $obj.Address = (Get-IPAddress $_endpoint.Host)
    if (!(Test-IPAddressLocalOrAny -IP $obj.Address)) {
        $obj.HostName = "$($obj.Address)"
    }

    # set the port for the context
    $obj.Port = $_endpoint.Port

    # if the server type is https, set cert details
    if ($Type -ieq 'https') {
        $obj.Ssl = $true
        $obj.Certificate.Name = $Certificate
    }

    # if the address is non-local, then check admin privileges
    if (!$Force -and !(Test-IPAddressLocal -IP $obj.Address) -and !(Test-IsAdminUser)) {
        throw 'Must be running with administrator priviledges to listen on non-localhost addresses'
    }

    # has this endpoint been added before? (for http/https we can just not add it again)
    $exists = ($PodeContext.Server.Endpoints | Where-Object {
        ($_.Address -eq $obj.Address) -and ($_.Port -eq $obj.Port) -and ($_.Ssl -eq $obj.Ssl)
    } | Measure-Object).Count

    # has an endpoint already been defined for smtp/tcp?
    if (@('smtp', 'tcp') -icontains $Type -and $Type -ieq $PodeContext.Server.Type) {
        throw "An endpoint for $($Type.ToUpperInvariant()) has already been defined"
    }

    if (!$exists) {
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
        $Path
    )

    # ensure the path exists, or it exists as a module
    $_path = Resolve-Path -Path $Path -ErrorAction Ignore
    if ([string]::IsNullOrWhiteSpace($_path)) {
        $_path = (Get-Module -Name $Path -ListAvailable | Select-Object -First 1).Path
    }

    # if it's still empty, error
    if ([string]::IsNullOrWhiteSpace($_path)) {
        throw "Failed to import module '$($Path)'"
    }

    # import the module into each runspace
    $PodeContext.RunspacePools.Values | ForEach-Object {
        $_.InitialSessionState.ImportPSModule($_path)
    }
}