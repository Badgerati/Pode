function New-PodeSession
{
    param (
        [int]
        $Port = 0
    )

    # basic session object
    $session = New-Object -TypeName psobject |
        Add-Member -MemberType NoteProperty -Name Routes -Value $null -PassThru |
        Add-Member -MemberType NoteProperty -Name Handlers -Value $null -PassThru |
        Add-Member -MemberType NoteProperty -Name Port -Value $Port -PassThru | 
        Add-Member -MemberType NoteProperty -Name ViewEngine -Value $null -PassThru | 
        Add-Member -MemberType NoteProperty -Name Web -Value @{} -PassThru | 
        Add-Member -MemberType NoteProperty -Name Smtp -Value @{} -PassThru | 
        Add-Member -MemberType NoteProperty -Name Tcp -Value @{} -PassThru |
        Add-Member -MemberType NoteProperty -Name Timers -Value $null -PassThru |
        Add-Member -MemberType NoteProperty -Name RunspacePool -Value $null -PassThru |
        Add-Member -MemberType NoteProperty -Name Runspaces -Value $null -PassThru

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

    # async timers
    $session.Timers = @{}

    # session state
    $state = [initialsessionstate]::CreateDefault()
    $variables = @(
        (New-Object System.Management.Automation.Runspaces.SessionStateVariableEntry -ArgumentList 'timers', $session.Timers, $null)
    )

    $variables | ForEach-Object {
        $state.Variables.Add($_)
    }

    # runspace and pool
    $session.Runspaces = @()
    $session.RunspacePool = [runspacefactory]::CreateRunspacePool(1, 2, $state, $Host)
    $session.RunspacePool.Open()

    return $session
}