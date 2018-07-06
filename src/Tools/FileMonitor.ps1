function Start-PodeFileMonitor
{
    if (!$PodeSession.FileMonitor) {
        return
    }

    # what folder and filter are we moitoring?
    $folder = $PodeSession.ServerRoot
    $filter = '*.*'

    # setup the file monitor
    $watcher = New-Object System.IO.FileSystemWatcher $folder, $filter -Property @{
        IncludeSubdirectories = $true;
        NotifyFilter = [System.IO.NotifyFilters]'FileName,LastWrite,CreationTime';
    }

    $watcher.EnableRaisingEvents = $true

    # setup the monitor timer - only restart server after changes + 2s of no changes
    $timer = New-Object System.Timers.Timer
    $timer.AutoReset = $false
    $timer.Interval = 2000

    # listen out of file created, changed, deleted events
    Register-ObjectEvent -InputObject $watcher -EventName 'Created' -SourceIdentifier (Get-PodeFileMonitorName Create) -Action {
        $Event.MessageData.Timer.Stop()
        $Event.MessageData.Timer.Start()
    } -MessageData @{ 'Timer' = $timer; } -SupportEvent

    Register-ObjectEvent -InputObject $watcher -EventName 'Changed' -SourceIdentifier (Get-PodeFileMonitorName Update) -Action {
        $Event.MessageData.Timer.Stop()
        $Event.MessageData.Timer.Start()
    } -MessageData @{ 'Timer' = $timer; } -SupportEvent

    Register-ObjectEvent -InputObject $watcher -EventName 'Deleted' -SourceIdentifier (Get-PodeFileMonitorName Delete) -Action {
        $Event.MessageData.Timer.Stop()
        $Event.MessageData.Timer.Start()
    } -MessageData @{ 'Timer' = $timer; } -SupportEvent

    # listen out for timer ticks to reset server
    Register-ObjectEvent -InputObject $timer -EventName 'Elapsed' -SourceIdentifier (Get-PodeFileMonitorTimerName) -Action {
        $Event.MessageData.Session.Tokens.Restart.Cancel()
        $Event.Sender.Stop()
    } -MessageData @{ 'Session' = $PodeSession; } -SupportEvent
}

function Stop-PodeFileMonitor
{
    if ($PodeSession.FileMonitor) {
        Unregister-Event -SourceIdentifier (Get-PodeFileMonitorName Create) -Force
        Unregister-Event -SourceIdentifier (Get-PodeFileMonitorName Delete) -Force
        Unregister-Event -SourceIdentifier (Get-PodeFileMonitorName Update) -Force
        Unregister-Event -SourceIdentifier (Get-PodeFileMonitorTimerName) -Force
    }
}

function Get-PodeFileMonitorName
{
    param (
        [ValidateSet('Create', 'Delete', 'Update')]
        [string]
        $Type
    )

    return "PodeFileMonitor$($Type)"
}

function Get-PodeFileMonitorTimerName
{
    return 'PodeFileMonitorTimer'
}