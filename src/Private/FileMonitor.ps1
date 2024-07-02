function Start-PodeFileMonitor {
    # don't configure if not supplied, or we're running as serverless
    if (!$PodeContext.Server.FileMonitor.Enabled -or $PodeContext.Server.IsServerless) {
        return
    }

    # what folder and filter are we moitoring?
    $folder = $PodeContext.Server.Root
    $filter = '*.*'

    # setup the file monitor
    $watcher = New-Object System.IO.FileSystemWatcher $folder, $filter -Property @{
        IncludeSubdirectories = $true
        NotifyFilter          = [System.IO.NotifyFilters]'FileName,LastWrite,CreationTime'
    }

    $watcher.EnableRaisingEvents = $true

    # setup the monitor timer - only restart server after changes + 2s of no changes
    $timer = New-Object System.Timers.Timer
    $timer.AutoReset = $false
    $timer.Interval = 2000

    # setup the message data for the events
    $msgData = @{
        Timer    = $timer
        Settings = $PodeContext.Server.FileMonitor
    }

    # setup the events script logic
    $action = {
        # if there are exclusions, and one matches, return
        if (($null -ne $Event.MessageData.Settings.Exclude) -and ($Event.SourceEventArgs.Name -imatch $Event.MessageData.Settings.Exclude)) {
            return
        }

        # if there are inclusions, and none match, return
        if (($null -ne $Event.MessageData.Settings.Include) -and ($Event.SourceEventArgs.Name -inotmatch $Event.MessageData.Settings.Include)) {
            return
        }

        # if enabled, add the file to the list of files that trigggered the restart
        if ($Event.MessageData.Settings.ShowFiles) {
            $name = "[$($Event.SourceEventArgs.ChangeType)] $($Event.SourceEventArgs.Name)"

            if ($Event.MessageData.Settings.Files -inotcontains $name) {
                $Event.MessageData.Settings.Files += $name
            }
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
        # if enabled, show the files that triggered the restart
        if ($Event.MessageData.FileSettings.ShowFiles) {
            if (!$Event.MessageData.Quiet) {
                # The following files have changed
                Write-PodeHost $PodeLocale.filesHaveChangedMessage  -ForegroundColor Magenta

                foreach ($file in $Event.MessageData.FileSettings.Files) {
                    Write-PodeHost "> $($file)" -ForegroundColor Magenta
                }
            }

            $Event.MessageData.FileSettings.Files = @()
        }

        # trigger the restart
        $Event.MessageData.Tokens.Restart.Cancel()
        $Event.Sender.Stop()
    } -MessageData @{
        Tokens       = $PodeContext.Tokens
        FileSettings = $PodeContext.Server.FileMonitor
        Quiet        = $PodeContext.Server.Quiet
    } -SupportEvent
}

function Stop-PodeFileMonitor {
    if ($PodeContext.Server.IsServerless) {
        return
    }

    if ($PodeContext.Server.FileMonitor.Enabled) {
        Unregister-Event -SourceIdentifier (Get-PodeFileMonitorName Create) -Force
        Unregister-Event -SourceIdentifier (Get-PodeFileMonitorName Delete) -Force
        Unregister-Event -SourceIdentifier (Get-PodeFileMonitorName Update) -Force
        Unregister-Event -SourceIdentifier (Get-PodeFileMonitorTimerName) -Force
    }
}

function Get-PodeFileMonitorName {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Create', 'Delete', 'Update')]
        [string]
        $Type
    )

    return "PodeFileMonitor$($Type)"
}

function Get-PodeFileMonitorTimerName {
    return 'PodeFileMonitorTimer'
}