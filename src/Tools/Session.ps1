function New-PodeSession
{
    param (
        [int]
        $Port = 0,

        [string]
        $IP = $null,

        [string]
        $ServerRoot,

        [switch]
        $DisableLogging
    )

    # basic session object
    $session = New-Object -TypeName psobject |
        Add-Member -MemberType NoteProperty -Name Routes -Value $null -PassThru |
        Add-Member -MemberType NoteProperty -Name Handlers -Value $null -PassThru |
        Add-Member -MemberType NoteProperty -Name Port -Value $Port -PassThru |
        Add-Member -MemberType NoteProperty -Name IP -Value @{} -PassThru |
        Add-Member -MemberType NoteProperty -Name ViewEngine -Value $null -PassThru |
        Add-Member -MemberType NoteProperty -Name Web -Value @{} -PassThru |
        Add-Member -MemberType NoteProperty -Name Smtp -Value @{} -PassThru |
        Add-Member -MemberType NoteProperty -Name Tcp -Value @{} -PassThru |
        Add-Member -MemberType NoteProperty -Name Timers -Value $null -PassThru |
        Add-Member -MemberType NoteProperty -Name RunspacePool -Value $null -PassThru |
        Add-Member -MemberType NoteProperty -Name Runspaces -Value $null -PassThru |
        Add-Member -MemberType NoteProperty -Name CancelToken -Value $null -PassThru |
        Add-Member -MemberType NoteProperty -Name DisableLogging -Value $DisableLogging -PassThru |
        Add-Member -MemberType NoteProperty -Name Loggers -Value @{} -PassThru |
        Add-Member -MemberType NoteProperty -Name RequestsToLog -Value $null -PassThru |
        Add-Member -MemberType NoteProperty -Name ServerRoot -Value $ServerRoot -PassThru |
        Add-Member -MemberType NoteProperty -Name SharedState -Value @{} -PassThru

    # set the IP address details
    $session.IP = @{
        'Address' = (Get-IPAddress $IP);
        'Name' = 'localhost'
    }

    if (!(Test-IPAddressLocal -IP $session.IP.Address)) {
        $session.IP.Name = $session.IP.Address
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

    # create new cancellation token
    $session.CancelToken = New-Object System.Threading.CancellationTokenSource

    # setup system state shared variable
    $session.SharedState['__system__'] = @{}

    # async timers
    $session.Timers = @{}

    # requests that should be logged
    $session.RequestsToLog = New-Object System.Collections.ArrayList

    # session state
    $state = [initialsessionstate]::CreateDefault()
    $state.ImportPSModule((Get-Module -Name Pode).Path)

    $variables = @(
        (New-Object System.Management.Automation.Runspaces.SessionStateVariableEntry -ArgumentList 'PodeSession', $session, $null),
        (New-Object System.Management.Automation.Runspaces.SessionStateVariableEntry -ArgumentList 'Console', $Host, $null)
    )

    $variables | ForEach-Object {
        $state.Variables.Add($_)
    }

    # runspace and pool
    $session.Runspaces = @()
    $session.RunspacePool = [runspacefactory]::CreateRunspacePool(1, 3, $state, $Host)
    $session.RunspacePool.Open()

    return $session
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

    if ($PodeSession -eq $null) {
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

function Start-FileMonitor
{
    $folder = $PodeSession.ServerRoot
    $filter = '*.*'

    $watcher = New-Object System.IO.FileSystemWatcher $folder, $filter -Property @{
        IncludeSubdirectories = $false;
        NotifyFilter = [System.IO.NotifyFilters]'FileName, LastWrite';
    }

    $watcher.EnableRaisingEvents = $true

    Register-ObjectEvent -InputObject $watcher -EventName 'Changed' -SourceIdentifier 'FileChanged' -Action { 
        $name = $Event.SourceEventArgs.Name 
        $changeType = $Event.SourceEventArgs.ChangeType 
        $timeStamp = $Event.TimeGenerated 
        "The file '$name' was $changeType at $timeStamp" | Out-Default
    }
}