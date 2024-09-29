function Find-PodeTimer {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name
    )

    return $PodeContext.Timers.Items[$Name]
}

function Test-PodeTimersExist {
    return (($null -ne $PodeContext.Timers) -and (($PodeContext.Timers.Enabled) -or ($PodeContext.Timers.Items.Count -gt 0)))
}

function Start-PodeTimerRunspace {
    if (!(Test-PodeTimersExist)) {
        return
    }

    $script = {
        try {

            while (!$PodeContext.Tokens.Cancellation.IsCancellationRequested) {
                try {
                    $_now = [DateTime]::Now

                    # only run timers that haven't completed, and have a next trigger in the past
                    foreach ($timer in $PodeContext.Timers.Items.Values) {
                        if ($timer.Completed -or (!$timer.OnStart -and ($timer.NextTriggerTime -gt $_now))) {
                            continue
                        }

                        try {
                            $timer.OnStart = $false
                            $timer.Count++

                            # set last trigger to current next trigger
                            if ($null -ne $timer.NextTriggerTime) {
                                $timer.LastTriggerTime = $timer.NextTriggerTime
                            }
                            else {
                                $timer.LastTriggerTime = $_now
                            }

                            # has the timer completed?
                            if (($timer.Limit -gt 0) -and ($timer.Count -ge $timer.Limit)) {
                                $timer.Completed = $true
                            }

                            # next trigger
                            if (!$timer.Completed) {
                                $timer.NextTriggerTime = $_now.AddSeconds($timer.Interval)
                            }
                            else {
                                $timer.NextTriggerTime = $null
                            }

                            # run the timer
                            Invoke-PodeInternalTimer -Timer $timer
                        }
                        catch {
                            $_ | Write-PodeErrorLog
                        }
                    }

                    Start-Sleep -Seconds 1
                }
                catch {
                    $_ | Write-PodeErrorLog
                }
            }
        }
        catch [System.OperationCanceledException] {
            $_ | Write-PodeErrorLog -Level Debug
        }
        catch {
            $_ | Write-PodeErrorLog
            throw $_.Exception
        }
    }

    Add-PodeRunspace -Type Timers -Name 'Scheduler' -ScriptBlock $script
}

function Invoke-PodeInternalTimer {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
    param(
        [Parameter(Mandatory = $true)]
        $Timer,

        [Parameter()]
        [object[]]
        $ArgumentList = $null
    )

    try {
        $TimerEvent = @{
            Lockable  = $PodeContext.Threading.Lockables.Global
            Sender    = $Timer
            Timestamp = [DateTime]::UtcNow
            Metadata  = @{}
        }

        # add main timer args
        $_args = @()
        if (($null -ne $Timer.Arguments) -and ($Timer.Arguments.Length -gt 0)) {
            $_args += $Timer.Arguments
        }

        # add adhoc timer invoke args
        if (($null -ne $ArgumentList) -and ($ArgumentList.Length -gt 0)) {
            $_args += $ArgumentList
        }

        # invoke timer
        Invoke-PodeScriptBlock -ScriptBlock $Timer.Script.GetNewClosure() -Arguments $_args -UsingVariables $Timer.UsingVariables -Scoped -Splat -NoNewClosure
    }
    catch {
        $_ | Write-PodeErrorLog
    }
    finally {
        Invoke-PodeGC
    }
}