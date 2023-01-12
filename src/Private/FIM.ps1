using namespace Pode

function Test-PodeFileWatchersExist
{
    return (($null -ne $PodeContext.Fim) -and (($PodeContext.Fim.Enabled) -or ($PodeContext.Fim.Items.Count -gt 0)))
}

function New-PodeFileWatcher
{
    $watcher = [PodeWatcher]::new($PodeContext.Tokens.Cancellation.Token)
    $watcher.ErrorLoggingEnabled = (Test-PodeErrorLoggingEnabled)
    $watcher.ErrorLoggingLevels = @(Get-PodeErrorLoggingLevels)
    return $watcher
}

function Start-PodeFileWatcherRunspace
{
    if (!(Test-PodeFileWatchersExist)) {
        return
    }

    try {
        # create the watcher
        $watcher = New-PodeFileWatcher

        # register file watchers and events
        foreach ($item in $PodeContext.Fim.Items.Values) {
            for ($i = 0; $i -lt $item.Watchers.Length; $i++) {
                Write-Verbose "Creating FileWatcher for '$($item.Watchers[$i].Path)'"
                $fileWatcher = [PodeFileWatcher]::new($item.Name, $item.Watchers[$i].Path, $item.IncludeSubdirectories, $item.InternalBufferSize, $item.NotifyFilters)

                foreach ($evt in $item.Events) {
                    Write-Verbose "-> Registering event: $($evt)"
                    $fileWatcher.RegisterEvent($evt)
                }

                $watcher.AddFileWatcher($fileWatcher)
            }
        }

        $watcher.Start()
        $PodeContext.Watchers += $watcher
    }
    catch {
        $_ | Write-PodeErrorLog
        $_.Exception | Write-PodeErrorLog -CheckInnerException
        Close-PodeDisposable -Disposable $watcher
        throw $_.Exception
    }

    $watchScript = {
        param(
            [Parameter(Mandatory=$true)]
            $Watcher,

            [Parameter(Mandatory=$true)]
            [int]
            $ThreadId
        )

        try
        {
            while ($Watcher.IsConnected -and !$PodeContext.Tokens.Cancellation.IsCancellationRequested)
            {
                $evt = (Wait-PodeTask -Task $Watcher.GetFileEventAsync($PodeContext.Tokens.Cancellation.Token))

                try
                {
                    try
                    {
                        # get file watcher
                        $fileWatcher = $PodeContext.Fim.Items[$evt.FileWatcher.Name]
                        if ($null -eq $fileWatcher) {
                            continue
                        }

                        # if there are exclusions, and one matches, return
                        if (($null -ne $fileWatcher.Exclude) -and ($evt.Name -imatch $fileWatcher.Exclude)) {
                            continue
                        }

                        # if there are inclusions, and none match, return
                        if (($null -ne $fileWatcher.Include) -and ($evt.Name -inotmatch $fileWatcher.Include)) {
                            continue
                        }

                        # set file event object
                        $FileEvent = @{
                            Type = $evt.ChangeType
                            FullPath = $evt.FullPath
                            Name = $evt.Name
                            Old = @{
                                FullPath = $evt.OldFullPath
                                Name = $evt.OldName
                            }
                            Parameters = @{}
                            Lockable = $PodeContext.Lockables.Global
                            Timestamp = [datetime]::UtcNow
                        }

                        # do we have any parameters?
                        if ($fileWatcher.Placeholders.Exist -and ($FileEvent.FullPath -imatch $fileWatcher.Placeholders.Path)) {
                            $FileEvent.Parameters = $Matches
                        }

                        # invoke main script
                        $_args = @(Get-PodeScriptblockArguments -ArgumentList $fileWatcher.Arguments -UsingVariables $fileWatcher.UsingVariables)
                        Invoke-PodeScriptBlock -ScriptBlock $fileWatcher.Script -Arguments $_args -Scoped -Splat
                    }
                    catch [System.OperationCanceledException] {}
                    catch {
                        $_ | Write-PodeErrorLog
                        $_.Exception | Write-PodeErrorLog -CheckInnerException
                    }
                }
                finally {
                    $FileEvent = $null
                    Close-PodeDisposable -Disposable $evt
                }
            }
        }
        catch [System.OperationCanceledException] {}
        catch {
            $_ | Write-PodeErrorLog
            $_.Exception | Write-PodeErrorLog -CheckInnerException
            throw $_.Exception
        }
    }

    1..$PodeContext.Threads.Files | ForEach-Object {
        Add-PodeRunspace -Type Files -ScriptBlock $watchScript -Parameters @{ 'Watcher' = $watcher; 'ThreadId' = $_ }
    }

    # script to keep file watcher server alive until cancelled
    $waitScript = {
        param(
            [Parameter(Mandatory=$true)]
            $Watcher
        )

        try {
            while ($Watcher.IsConnected -and !$PodeContext.Tokens.Cancellation.IsCancellationRequested) {
                Start-Sleep -Seconds 1
            }
        }
        catch [System.OperationCanceledException] {}
        catch {
            $_ | Write-PodeErrorLog
            $_.Exception | Write-PodeErrorLog -CheckInnerException
            throw $_.Exception
        }
        finally {
            Close-PodeDisposable -Disposable $Watcher
        }
    }

    Add-PodeRunspace -Type Files -ScriptBlock $waitScript -Parameters @{ 'Watcher' = $watcher } -NoProfile




    # $script = {
    #     # wrapper action handler
    #     $action = Get-PodeFileWatcherAction

    #     # error action hanlder
    #     $errAction = Get-PodeFileWatcherErrorAction

    #     try {
    #         # register file watchers for each one setup
    #         foreach ($item in $PodeContext.Fim.Items.Values) {
    #             for ($i = 0; $i -lt $item.Watchers.Length; $i++) {
    #                 # create .net file watcher for path
    #                 $item.Watchers[$i].Watcher = New-Object Pode.FileWatcher.RecoveringFileSystemWatcher $item.Watchers[$i].Path -Property @{
    #                     IncludeSubdirectories = $item.IncludeSubdirectories
    #                     InternalBufferSize = $item.InternalBufferSize
    #                     NotifyFilter = $item.NotifyFilters
    #                     EnableRaisingEvents = $true
    #                 }

    #                 # setup message data ith script/args
    #                 $msgData = @{
    #                     ScriptBlock = $item.Script
    #                     ArgumentList = @(Get-PodeScriptblockArguments -ArgumentList $item.Arguments -UsingVariables $item.UsingVariables) 
    #                     Exclude = $item.Exclude
    #                     Include = $item.Include
    #                     Placeholders = $item.Placeholders
    #                 }

    #                 # register defined events
    #                 foreach ($evt in $item.Events) {
    #                     Register-PodeFileWatcherEvent `
    #                         -Name $item.Name `
    #                         -Index $i `
    #                         -EventName $evt `
    #                         -Watcher $item.Watchers[$i].Watcher `
    #                         -ScriptBlock $action `
    #                         -MessageData $msgData
    #                 }

    #                 # register "Error" event type - log the exception
    #                 Register-PodeFileWatcherEvent `
    #                     -Name $item.Name `
    #                     -Index $i `
    #                     -EventName 'Error' `
    #                     -Watcher $item.Watchers[$i].Watcher `
    #                     -ScriptBlock $errAction
    #             }
    #         }

    #         # keep the runspace alive
    #         while (!$PodeContext.Tokens.Cancellation.IsCancellationRequested) {
    #             $PodeContext.Fim.Items.Values[0].Watchers[0].Watcher | Out-Default
    #             $PodeContext.Tokens.Cancellation.Token | Out-Default
    #             $null = (Wait-PodeTask -Task $PodeContext.Fim.Items.Values[0].Watchers[0].Watcher.GetContextAsync($PodeContext.Tokens.Cancellation.Token))
    #             # $processing = $false

    #             # foreach ($item in $PodeContext.Fim.Items.Values) {
    #             #     foreach ($watcher in $item.Watchers) {
    #             #         if ($watcher.Watcher.Count -gt 0) {
    #             #             $processing = $true
    #             #             break
    #             #         }
    #             #     }
    #             # }

    #             # if ($processing) {
    #             #     Start-Sleep -Milliseconds 10
    #             # }
    #             # else {
    #             #     Start-Sleep -Seconds 1
    #             # }
    #         }
    #     }
    #     catch [System.OperationCanceledException] {}
    #     catch {
    #         $_ | Write-PodeErrorLog
    #         $_.Exception | Write-PodeErrorLog -CheckInnerException
    #         throw
    #     }
    #     finally {
    #         # dispose/unregister all watchers
    #         foreach ($item in $PodeContext.Fim.Items.Values) {
    #             for ($i = 0; $i -lt $item.Watchers.Length; $i++) {
    #                 # unregister events
    #                 foreach ($evt in $item.Events) {
    #                     Unregister-PodeFileWatcherEvent -Name $item.Name -Index $i -EventName $evt
    #                 }

    #                 # unregister error event
    #                 Unregister-PodeFileWatcherEvent -Name $item.Name -Index $i -EventName 'Error'

    #                 # dispose watcher
    #                 if ($null -ne $item.Watchers[$i].Watcher) {
    #                     $item.Watchers[$i].Watcher.Dispose()
    #                 }
    #             }
    #         }
    #     }
    # }

    # Add-PodeRunspace -Type Files -ScriptBlock $script -NoProfile
}

function Get-PodeFileWatcherIdenifierName
{
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Name,

        [Parameter(Mandatory=$true)]
        [int]
        $Index,

        [Parameter(Mandatory=$true)]
        [string]
        $EventName
    )

    return "Pode.Fim.$($Name -replace '\s+', '_').$($Index).$($EventName)"
}

function Test-PodeFileWatcherEventRegistered
{
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $SourceIdentifier
    )

    return (($null -ne (Get-Event -SourceIdentifier $SourceIdentifier -ErrorAction Ignore)))
}

function Get-PodeFileWatcherAction
{
    return {
        try {
            # if there are exclusions, and one matches, return
            if (($null -ne $Event.MessageData.Exclude) -and ($Event.SourceEventArgs.Name -imatch $Event.MessageData.Exclude)) {
                return
            }

            # if there are inclusions, and none match, return
            if (($null -ne $Event.MessageData.Include) -and ($Event.SourceEventArgs.Name -inotmatch $Event.MessageData.Include)) {
                return
            }

            # set file event object
            $global:FileEvent = @{
                Type = $Event.SourceEventArgs.ChangeType
                FullPath = $Event.SourceEventArgs.FullPath
                Name = $Event.SourceEventArgs.Name
                Old = @{
                    FullPath = $Event.SourceEventArgs.OldFullPath
                    Name = $Event.SourceEventArgs.OldName
                }
                Parameters = @{}
                Lockable = $PodeContext.Lockables.Global
                Timestamp = [datetime]::UtcNow
            }

            # do we have any parameters?
            if ($Event.MessageData.Placeholders.Exist -and ($FileEvent.FullPath -imatch $Event.MessageData.Placeholders.Path)) {
                $FileEvent.Parameters = $Matches
            }

            # invoke main script
            Invoke-PodeScriptBlock `
                -ScriptBlock $Event.MessageData.ScriptBlock `
                -Arguments $Event.MessageData.ArgumentList  `
                -Scoped `
                -Splat
        }
        catch [System.OperationCanceledException] {}
        catch {
            $_ | Write-PodeErrorLog
        }
    }
}

function Get-PodeFileWatcherErrorAction
{
    return {
        $Event.SourceEventArgs.GetException() | Write-PodeErrorLog
    }
}

function Register-PodeFileWatcherEvent
{
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Name,

        [Parameter(Mandatory=$true)]
        [int]
        $Index,

        [Parameter(Mandatory=$true)]
        [string]
        $EventName,

        [Parameter(Mandatory=$true)]
        [Pode.FileWatcher.RecoveringFileSystemWatcher]
        $Watcher,

        [Parameter(Mandatory=$true)]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [hashtable]
        $MessageData = @{}
    )

    $id = Get-PodeFileWatcherIdenifierName -Name $Name -Index $Index -EventName $EventName

    if (Test-PodeFileWatcherEventRegistered -SourceIdentifier $id) {
        throw "An event handler has already been registered with the identifier '$($id)'"
    }

    if ($null -eq $MessageData) {
        $MessageData = @{}
    }

    Register-ObjectEvent `
        -InputObject $Watcher `
        -EventName $EventName `
        -SourceIdentifier $id `
        -Action $ScriptBlock `
        -MessageData $MessageData `
        -SupportEvent `
        -ErrorAction Stop
}

function Unregister-PodeFileWatcherEvent
{
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Name,

        [Parameter(Mandatory=$true)]
        [int]
        $Index,

        [Parameter(Mandatory=$true)]
        [string]
        $EventName
    )

    $id = Get-PodeFileWatcherIdenifierName -Name $Name -Index $Index -EventName $EventName

    if (Test-PodeFileWatcherEventRegistered -SourceIdentifier $id) {
        Unregister-Event -SourceIdentifier $id -Force -ErrorAction SilentlyContinue
    }
}