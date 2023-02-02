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
            foreach ($path in $item.Paths) {
                Write-Verbose "Creating FileWatcher for '$($path)'"
                $fileWatcher = [PodeFileWatcher]::new($item.Name, $path, $item.IncludeSubdirectories, $item.InternalBufferSize, $item.NotifyFilters)

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
                        $exc = (Convert-PodePathPatternsToRegex -Paths $fileWatcher.Exclude)
                        if (($null -ne $exc) -and ($evt.Name -imatch $exc)) {
                            continue
                        }

                        # if there are inclusions, and none match, return
                        $inc = (Convert-PodePathPatternsToRegex -Paths $fileWatcher.Include)
                        if (($null -ne $inc) -and ($evt.Name -inotmatch $inc)) {
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
                            Lockable = $PodeContext.Threading.Lockables.Global
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
}
