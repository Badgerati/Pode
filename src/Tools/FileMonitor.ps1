function Start-PodeFileMonitor
{
    if (!$PodeContext.Server.FileMonitor.Enabled) {
        return
    }

    # what folder and filter are we moitoring?
    $folder = $PodeContext.Server.Root
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

    # setup the message data for the events
    $msgData = @{
        'Timer' = $timer;
        'Exclude' = $PodeContext.Server.FileMonitor.Exclude;
        'Include' = $PodeContext.Server.FileMonitor.Include;
    }

    # setup the events script logic
    $action = {
        # if there are exclusions, and one matches, return
        if (($null -ne $Event.MessageData.Exclude) -and ($Event.SourceEventArgs.Name -imatch $Event.MessageData.Exclude)) {
            return
        }

        # if there are inclusions, and none match, return
        if (($null -ne $Event.MessageData.Include) -and ($Event.SourceEventArgs.Name -inotmatch $Event.MessageData.Include)) {
            return
        }

        # restart the timer
        $Event.MessageData.Timer.Stop()
        $Event.MessageData.Timer.Start()
    }

    # listen out of file created, changed, deleted events
    Register-ObjectEvent -InputObject $watcher -EventName 'Created' `
        -SourceIdentifier (Get-PodeFileMonitorName Create) -Action $action -MessageData $msgData -SupportEvent

    Register-ObjectEvent -InputObject $watcher -EventName 'Changed' `
        -SourceIdentifier (Get-PodeFileMonitorName Update) -Action $action -MessageData $msgData -SupportEvent

    Register-ObjectEvent -InputObject $watcher -EventName 'Deleted' `
        -SourceIdentifier (Get-PodeFileMonitorName Delete) -Action $action -MessageData $msgData -SupportEvent

    # listen out for timer ticks to reset server
    Register-ObjectEvent -InputObject $timer -EventName 'Elapsed' -SourceIdentifier (Get-PodeFileMonitorTimerName) -Action {
        $Event.MessageData.Context.Tokens.Restart.Cancel()
        $Event.Sender.Stop()
    } -MessageData @{ 'Context' = $PodeContext; } -SupportEvent
}

function Stop-PodeFileMonitor
{
    if ($PodeContext.Server.FileMonitor.Enabled) {
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