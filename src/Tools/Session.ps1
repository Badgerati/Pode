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

    if (Test-Empty $Name) {
        $Name = Get-RandomServerName
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
        Add-Member -MemberType NoteProperty -Name Web -Value @{} -PassThru |
        Add-Member -MemberType NoteProperty -Name Smtp -Value @{} -PassThru |
        Add-Member -MemberType NoteProperty -Name Tcp -Value @{} -PassThru |
        Add-Member -MemberType NoteProperty -Name Timers -Value @{} -PassThru |
        Add-Member -MemberType NoteProperty -Name RunspacePool -Value $null -PassThru |
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

    # create new cancellation tokens
    $session.Tokens = @{
        'Cancellation' = New-Object System.Threading.CancellationTokenSource;
        'Restart' = New-Object System.Threading.CancellationTokenSource;
    }

    # requests that should be logged
    $session.RequestsToLog = New-Object System.Collections.ArrayList

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

    # runspace and pool
    $session.Runspaces = @()
    $session.RunspacePool = [runspacefactory]::CreateRunspacePool(1, 4, $state, $Host)
    $session.RunspacePool.Open()

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
        Add-Member -MemberType NoteProperty -Name IP -Value $Session.IP -PassThru |
        Add-Member -MemberType NoteProperty -Name ViewEngine -Value $Session.ViewEngine -PassThru |
        Add-Member -MemberType NoteProperty -Name Web -Value $Session.Web -PassThru |
        Add-Member -MemberType NoteProperty -Name Timers -Value $Session.Timers -PassThru |
        Add-Member -MemberType NoteProperty -Name Tokens -Value $Session.Tokens -PassThru |
        Add-Member -MemberType NoteProperty -Name DisableLogging -Value $Session.DisableLogging -PassThru |
        Add-Member -MemberType NoteProperty -Name Loggers -Value $Session.Loggers -PassThru |
        Add-Member -MemberType NoteProperty -Name RequestsToLog -Value $Session.RequestsToLog -PassThru |
        Add-Member -MemberType NoteProperty -Name ServerRoot -Value $Session.ServerRoot -PassThru |
        Add-Member -MemberType NoteProperty -Name SharedState -Value $Session.SharedState -PassThru |
        Add-Member -MemberType NoteProperty -Name Lockable -Value $Session.Lockable -PassThru |
        Add-Member -MemberType NoteProperty -Name Access -Value $Session.Access -PassThru)
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
        if ($PodeSession -eq $null -or $PodeSession.SharedState -eq $null) {
            return
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