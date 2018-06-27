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

    # setup the monitor timer - only restart server after changes + 1s of no changes
    $timer = New-Object System.Timers.Timer
    $timer.AutoReset = $false
    $timer.Interval = 2000

    # listen out of file changed events
    Register-ObjectEvent -InputObject $watcher -EventName 'Changed' -SourceIdentifier (Get-PodeFileMonitorName) -Action { 
        $Event.MessageData.Timer.Stop()
        $Event.MessageData.Timer.Start()
    } -MessageData @{ 'Session' = $PodeSession; 'Timer' = $timer; } -SupportEvent

    # listen out for timer ticks to reset server
    Register-ObjectEvent -InputObject $timer -EventName 'Elapsed' -SourceIdentifier (Get-PodeFileMonitorTimerName) -Action {
        $_id = $Event.MessageData.ServerName
        Set-PodeEnvVar -Name (Get-PodeEnvServerName $_id) -Value '1'
        $Event.Sender.Stop()
    } -MessageData @{ 'ServerName' = $PodeSession.ServerName; } -SupportEvent
}

function Stop-PodeFileMonitor
{
    if ($PodeSession.FileMonitor) {
        Unregister-Event -SourceIdentifier (Get-PodeFileMonitorName) -Force
        Unregister-Event -SourceIdentifier (Get-PodeFileMonitorTimerName) -Force
    }
}

function Get-PodeFileMonitorName
{
    return 'PodeFileMonitor'
}

function Get-PodeFileMonitorTimerName
{
    return 'PodeFileMonitorTimer'
}