function New-PodeSession
{
    param (
        [scriptblock]
        $ScriptBlock,

        [int]
        $Port = 0,

        [string]
        $IP = $null,

        [int]
        $Threads = 1,

        [int]
        $Interval = 0,

        [string]
        $ServerRoot,

        [ValidateSet('HTTP', 'HTTPS', 'SCRIPT', 'SERVICE', 'SMTP', 'TCP')]
        [string]
        $ServerType,

        [string]
        $Name = $null,

        [switch]
        $DisableLogging,

        [switch]
        $FileMonitor
    )

    # set a random server name if one not supplied
    if (Test-Empty $Name) {
        $Name = Get-RandomServerName
    }

    # ensure threads are always >0
    if ($Threads -le 0) {
        $Threads = 1
    }

    # basic session object
    $session = New-Object -TypeName psobject |
        Add-Member -MemberType NoteProperty -Name ServerName -Value $Name -PassThru |
        Add-Member -MemberType NoteProperty -Name ScriptBlock -Value $ScriptBlock -PassThru |
        Add-Member -MemberType NoteProperty -Name Routes -Value $null -PassThru |
        Add-Member -MemberType NoteProperty -Name Handlers -Value $null -PassThru |
        Add-Member -MemberType NoteProperty -Name Interval -Value $Interval -PassThru |
        Add-Member -MemberType NoteProperty -Name IP -Value @{} -PassThru |
        Add-Member -MemberType NoteProperty -Name ViewEngine -Value $null -PassThru |
        Add-Member -MemberType NoteProperty -Name Threads -Value $Threads -PassThru |
        Add-Member -MemberType NoteProperty -Name Timers -Value @{} -PassThru |
        Add-Member -MemberType NoteProperty -Name Schedules -Value @{} -PassThru |
        Add-Member -MemberType NoteProperty -Name RunspacePools -Value $null -PassThru |
        Add-Member -MemberType NoteProperty -Name Runspaces -Value $null -PassThru |
        Add-Member -MemberType NoteProperty -Name Tokens -Value @{} -PassThru |
        Add-Member -MemberType NoteProperty -Name DisableLogging -Value $DisableLogging -PassThru |
        Add-Member -MemberType NoteProperty -Name Loggers -Value @{} -PassThru |
        Add-Member -MemberType NoteProperty -Name RequestsToLog -Value $null -PassThru |
        Add-Member -MemberType NoteProperty -Name ServerRoot -Value $ServerRoot -PassThru |
        Add-Member -MemberType NoteProperty -Name ServerType -Value $ServerType -PassThru |
        Add-Member -MemberType NoteProperty -Name SharedState -Value @{} -PassThru |
        Add-Member -MemberType NoteProperty -Name Lockable -Value $null -PassThru |
        Add-Member -MemberType NoteProperty -Name Access -Value @{} -PassThru |
        Add-Member -MemberType NoteProperty -Name Limits -Value @{} -PassThru |
        Add-Member -MemberType NoteProperty -Name FileMonitor -Value $FileMonitor -PassThru

    # set the IP address details
    $session.IP = @{
        'Address' = $null;
        'Port' = $Port;
        'Name' = 'localhost';
    }

    # session engine for rendering views
    $session.ViewEngine = @{
        'Extension' = 'html';
        'Script' = $null;
    }

    # routes for pages and api
    $session.Routes = @{
        'delete' = @{};
        'get' = @{};
        'head' = @{};
        'merge' = @{};
        'options' = @{};
        'patch' = @{};
        'post' = @{};
        'put' = @{};
        'trace' = @{};
        '*' = @{};
    }

    # handlers for tcp
    $session.Handlers = @{
        'tcp' = $null;
        'smtp' = $null;
    }

    # setup basic access placeholders
    $session.Access = @{
        'Allow' = @{};
        'Deny' = @{};
    }

    # setup basic limit rules
    $session.Limits = @{
        'Rules' = @{};
        'Active' = @{};
    }

    # create new cancellation tokens
    $session.Tokens = @{
        'Cancellation' = New-Object System.Threading.CancellationTokenSource;
        'Restart' = New-Object System.Threading.CancellationTokenSource;
    }

    # requests that should be logged
    $session.RequestsToLog = New-Object System.Collections.ArrayList

    # runspace pools
    $session.RunspacePools = @{
        'Main' = $null;
        'Schedules' = $null;
    }

    # session state
    $session.Lockable = [hashtable]::Synchronized(@{})
    $state = [initialsessionstate]::CreateDefault()
    $state.ImportPSModule((Get-Module -Name Pode).Path)

    $_session = New-PodeStateSession $session

    $variables = @(
        (New-Object System.Management.Automation.Runspaces.SessionStateVariableEntry -ArgumentList 'PodeSession', $_session, $null),
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
        Add-Member -MemberType NoteProperty -Name ServerName -Value $Session.ServerName -PassThru |
        Add-Member -MemberType NoteProperty -Name Routes -Value $Session.Routes -PassThru |
        Add-Member -MemberType NoteProperty -Name Handlers -Value $Session.Handlers -PassThru |
        Add-Member -MemberType NoteProperty -Name IP -Value $Session.IP -PassThru |
        Add-Member -MemberType NoteProperty -Name ViewEngine -Value $Session.ViewEngine -PassThru |
        Add-Member -MemberType NoteProperty -Name Threads -Value $Session.Threads -PassThru |
        Add-Member -MemberType NoteProperty -Name Timers -Value $Session.Timers -PassThru |
        Add-Member -MemberType NoteProperty -Name Schedules -Value $Session.Schedules -PassThru |
        Add-Member -MemberType NoteProperty -Name RunspacePools -Value $Session.RunspacePools -PassThru |
        Add-Member -MemberType NoteProperty -Name Tokens -Value $Session.Tokens -PassThru |
        Add-Member -MemberType NoteProperty -Name DisableLogging -Value $Session.DisableLogging -PassThru |
        Add-Member -MemberType NoteProperty -Name Loggers -Value $Session.Loggers -PassThru |
        Add-Member -MemberType NoteProperty -Name RequestsToLog -Value $Session.RequestsToLog -PassThru |
        Add-Member -MemberType NoteProperty -Name ServerRoot -Value $Session.ServerRoot -PassThru |
        Add-Member -MemberType NoteProperty -Name SharedState -Value $Session.SharedState -PassThru |
        Add-Member -MemberType NoteProperty -Name Lockable -Value $Session.Lockable -PassThru |
        Add-Member -MemberType NoteProperty -Name Access -Value $Session.Access -PassThru |
        Add-Member -MemberType NoteProperty -Name Limits -Value $Session.Limits -PassThru)
}

function State
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet('set', 'get', 'remove')]
        [string]
        $Action,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name,

        [Parameter()]
        [object]
        $Object
    )

    try {
        if ($null -eq $PodeSession -or $null -eq $PodeSession.SharedState) {
            return $null
        }

        switch ($Action.ToLowerInvariant())
        {
            'set' {
                $PodeSession.SharedState[$Name] = $Object
            }

            'get' {
                $Object = $PodeSession.SharedState[$Name]
            }

            'remove' {
                $Object = $PodeSession.SharedState[$Name]
                $PodeSession.SharedState.Remove($Name) | Out-Null
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
        [string]
        $IPPort,
        
        [Parameter()]
        [ValidateSet('HTTP', 'HTTPS', 'SMTP', 'TCP')]
        [string]
        $Type
    )

    $hostRgx = '(?<host>(\[[a-z0-9\:]+\]|((\d+\.){3}\d+)|\:\:\d+|\*|all))'
    $portRgx = '(?<port>\d+)'
    $cmbdRgx = "$($hostRgx)\:$($portRgx)"

    # validate that we have a valid ip:port address
    if (!($IPPort -imatch "^$($cmbdRgx)$" -or $IPPort -imatch "^$($hostRgx)[\:]{0,1}" -or $IPPort -imatch "[\:]{0,1}$($portRgx)$")) {
        throw "Failed to parse '$($IPPort)' as a valid IP:Port address"
    }

    # grab the ip address
    $_host = $Matches['host']
    if (Test-Empty $_host) {
        $_host = '*'
    }

    # ensure we have a valid ip address
    if (!(Test-IPAddress -IP $_host)) {
        throw "Invalid IP address has been supplied: $($IP)"
    }

    # grab the port
    $_port = $Matches['port']
    if (Test-Empty $_port) {
        $_port = 0
    }

    # ensure the port is valid
    if ($_port -lt 0) {
        throw "Port cannot be negative: $($_port)"
    }

    # set the ip for the session
    $PodeSession.IP.Address = (Get-IPAddress $_host)
    if (!(Test-IPAddressLocal -IP $PodeSession.IP.Address)) {
        $PodeSession.IP.Name = $PodeSession.IP.Address
    }

    # set the port for the session
    $PodeSession.IP.Port = $_port

    # set the server type
    $PodeSession.ServerType = $Type
}

function Script
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Path
    )

    $Path = Resolve-Path -Path $Path

    $PodeSession.RunspacePools.Values | ForEach-Object {
        $_.InitialSessionState.ImportPSModule($Path)
    }
}