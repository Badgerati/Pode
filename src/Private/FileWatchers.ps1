using namespace Pode

function Test-PodeFileWatchersExist {
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    return (($null -ne $PodeContext.Fim) -and (($PodeContext.Fim.Enabled) -or ($PodeContext.Fim.Items.Count -gt 0)))
}

function New-PodeFileWatcher {
    [CmdletBinding()]
    [OutputType([PodeWatcher])]
    param()
    $watcher = [PodeWatcher]::new($PodeContext.Tokens.Cancellation.Token)
    $watcher.ErrorLoggingEnabled = (Test-PodeErrorLoggingEnabled)
    $watcher.ErrorLoggingLevels = @(Get-PodeErrorLoggingLevel)
    return $watcher
}

function Start-PodeFileWatcherRunspace {
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
            [Parameter(Mandatory = $true)]
            $Watcher,

            [Parameter(Mandatory = $true)]
            [int]
            $ThreadId
        )
        # Waits for the Pode server to fully start before proceeding with further operations.
        Wait-PodeCancellationTokenRequest -Type Start
        do {
            try {
                while ($Watcher.IsConnected -and !(Test-PodeCancellationTokenRequest -Type Terminate)) {
                    $evt = (Wait-PodeTask -Task $Watcher.GetFileEventAsync($PodeContext.Tokens.Cancellation.Token))

                    try {
                        try {
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
                                Type       = $evt.ChangeType
                                FullPath   = $evt.FullPath
                                Name       = $evt.Name
                                Old        = @{
                                    FullPath = $evt.OldFullPath
                                    Name     = $evt.OldName
                                }
                                Parameters = @{}
                                Lockable   = $PodeContext.Threading.Lockables.Global
                                Timestamp  = [datetime]::UtcNow
                                Metadata   = @{}
                            }

                            # do we have any parameters?
                            if ($fileWatcher.Placeholders.Exist -and ($FileEvent.FullPath -imatch $fileWatcher.Placeholders.Path)) {
                                $FileEvent.Parameters = $Matches
                            }

                            # invoke main script
                            $null = Invoke-PodeScriptBlock -ScriptBlock $fileWatcher.Script -Arguments $fileWatcher.Arguments -UsingVariables $fileWatcher.UsingVariables -Scoped -Splat
                        }
                        catch [System.OperationCanceledException] {
                            $_ | Write-PodeErrorLog -Level Debug
                        }
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
            catch [System.OperationCanceledException] {
                $_ | Write-PodeErrorLog -Level Debug
            }
            catch {
                $_ | Write-PodeErrorLog
                $_.Exception | Write-PodeErrorLog -CheckInnerException
                throw $_.Exception
            }

            # end do-while
        } while (Test-PodeSuspensionToken) # Check for suspension token and wait for the debugger to reset if active

    }

    1..$PodeContext.Threads.Files | ForEach-Object {
        Add-PodeRunspace -Type Files -Name 'Watcher' -ScriptBlock $watchScript -Parameters @{ 'Watcher' = $watcher ; 'ThreadId' = $_ }
    }

    # script to keep file watcher server alive until cancelled
    $waitScript = {
        param(
            [Parameter(Mandatory = $true)]
            $Watcher
        )

        try {
            while ($Watcher.IsConnected -and !(Test-PodeCancellationTokenRequest -Type Terminate)) {
                Start-Sleep -Seconds 1
            }
        }
        catch [System.OperationCanceledException] {
            $_ | Write-PodeErrorLog -Level Debug
        }
        catch {
            $_ | Write-PodeErrorLog
            $_.Exception | Write-PodeErrorLog -CheckInnerException
            throw $_.Exception
        }
        finally {
            Close-PodeDisposable -Disposable $Watcher
        }
    }

    Add-PodeRunspace -Type Files -Name 'KeepAlive' -ScriptBlock $waitScript -Parameters @{ 'Watcher' = $watcher } -NoProfile
}
