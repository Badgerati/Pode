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

    # basic session object
    $session = New-Object -TypeName psobject |
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
    $session.Server.Name = $Name
    $session.Server.Root = $ServerRoot
    $session.Server.Logic = $ScriptBlock
    $session.Server.Interval = $Interval
    $session.Server.FileMonitor = $FileMonitor

    # set the server default type
    $session.Server.Type = ([string]::Empty)
    if ($Interval -gt 0) {
        $session.Server.Type = 'SERVICE'
    }

    # check if there is any global configuration
    $session.Server.Configuration = @{}

    $configPath = (Join-ServerRoot -Folder '.' -FilePath 'pode.json' -Root $ServerRoot)
    if (Test-PodePath -Path $configPath  -NoStatus) {
        $session.Server.Configuration = (Get-Content $configPath -Raw | ConvertFrom-Json)
    }

    # set the IP address details
    $session.Server.Endpoints = @()

    # setup gui details
    $session.Server.Gui = @{
        'Enabled' = $false;
        'Name' = $null;
        'Icon' = $null;
        'State' = 'Normal';
        'ShowInTaskbar' = $true;
        'WindowStyle' = 'SingleBorderWindow';
    }

    # shared temp drives
    $session.Server.Drives = @{}
    $session.Server.InbuiltDrives = @{}

    # shared state between runspaces
    $session.Server.State = @{}

    # session engine for rendering views
    $session.Server.ViewEngine = @{
        'Engine' = 'html';
        'Extension' = 'html';
        'Script' = $null;
    }

    # routes for pages and api
    $session.Server.Routes = @{
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
    $session.Server.Handlers = @{
        'tcp' = $null;
        'smtp' = $null;
        'service' = $null;
    }

    # setup basic access placeholders
    $session.Server.Access = @{
        'Allow' = @{};
        'Deny' = @{};
    }

    # setup basic limit rules
    $session.Server.Limits = @{
        'Rules' = @{};
        'Active' = @{};
    }

    # cookies and session logic
    $session.Server.Cookies = @{
        'Session' = @{};
    }

    # authnetication methods
    $session.Server.Authentications = @{}

    # logging methods
    $session.Server.Logging = @{
        'Methods' = @{};
        'Disabled' = $DisableLogging;
    }

    # create new cancellation tokens
    $session.Tokens = @{
        'Cancellation' = New-Object System.Threading.CancellationTokenSource;
        'Restart' = New-Object System.Threading.CancellationTokenSource;
    }

    # requests that should be logged
    $session.RequestsToLog = New-Object System.Collections.ArrayList

    # middleware that needs to run
    $session.Server.Middleware = @()

    # endware that needs to run
    $session.Server.Endware = @()

    # runspace pools
    $session.RunspacePools = @{
        'Main' = $null;
        'Schedules' = $null;
        'Gui' = $null;
    }

    # session state
    $session.Lockable = [hashtable]::Synchronized(@{})
    $state = [initialsessionstate]::CreateDefault()
    $state.ImportPSModule((Get-Module -Name Pode).Path)

    $_session = New-PodeStateSession $session

    $variables = @(
        (New-Object System.Management.Automation.Runspaces.SessionStateVariableEntry -ArgumentList 'PodeContext', $_session, $null),
        (New-Object System.Management.Automation.Runspaces.SessionStateVariableEntry -ArgumentList 'Console', $Host, $null)
    )

    $variables | ForEach-Object {
        $state.Variables.Add($_)
    }

    # setup runspaces
    $session.Runspaces = @()

    # setup main runspace pool
    $threadsCounts = @{
        'Default' = 1;
        'Timer' = 1;
        'Log' = 1;
        'Schedule' = 1;
        'Misc' = 1;
    }

    $totalThreadCount = ($threadsCounts.Values | Measure-Object -Sum).Sum + $Threads
    $session.RunspacePools.Main = [runspacefactory]::CreateRunspacePool(1, $totalThreadCount, $state, $Host)
    $session.RunspacePools.Main.Open()

    # setup schedule runspace pool
    $session.RunspacePools.Schedules = [runspacefactory]::CreateRunspacePool(1, 2, $state, $Host)
    $session.RunspacePools.Schedules.Open()

    # setup gui runspace pool (only for non-ps-core)
    if (!(Test-IsPSCore)) {
        $session.RunspacePools.Gui = [runspacefactory]::CreateRunspacePool(1, 1, $state, $Host)
        $session.RunspacePools.Gui.ApartmentState = 'STA'
        $session.RunspacePools.Gui.Open()
    }

    # return the new session
    return $session
}

function New-PodeStateSession
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        $Session
    )

    return (New-Object -TypeName psobject |
        Add-Member -MemberType NoteProperty -Name Threads -Value $Session.Threads -PassThru |
        Add-Member -MemberType NoteProperty -Name Timers -Value $Session.Timers -PassThru |
        Add-Member -MemberType NoteProperty -Name Schedules -Value $Session.Schedules -PassThru |
        Add-Member -MemberType NoteProperty -Name RunspacePools -Value $Session.RunspacePools -PassThru |
        Add-Member -MemberType NoteProperty -Name Tokens -Value $Session.Tokens -PassThru |
        Add-Member -MemberType NoteProperty -Name RequestsToLog -Value $Session.RequestsToLog -PassThru |
        Add-Member -MemberType NoteProperty -Name Lockable -Value $Session.Lockable -PassThru |
        Add-Member -MemberType NoteProperty -Name Server -Value $Session.Server -PassThru)
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

    # set the ip for the session
    $obj.Address = (Get-IPAddress $_endpoint.Host)
    if (!(Test-IPAddressLocalOrAny -IP $obj.Address)) {
        $obj.HostName = "$($obj.Address)"
    }

    # set the port for the session
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