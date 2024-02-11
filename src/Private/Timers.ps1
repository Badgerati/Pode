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
        while (!$PodeContext.Tokens.Cancellation.IsCancellationRequested) {
            $_now = [DateTime]::Now

            # only run timers that haven't completed, and have a next trigger in the past
            $PodeContext.Timers.Items.Values | Where-Object {
                !$_.Completed -and ($_.OnStart -or ($_.NextTriggerTime -le $_now))
            } | ForEach-Object {
                $_.OnStart = $false
                $_.Count++

                # set last trigger to current next trigger
                if ($null -ne $_.NextTriggerTime) {
                    $_.LastTriggerTime = $_.NextTriggerTime
                }
                else {
                    $_.LastTriggerTime = [datetime]::Now
                }

                # has the timer completed?
                if (($_.Limit -gt 0) -and ($_.Count -ge $_.Limit)) {
                    $_.Completed = $true
                }

                # next trigger
                if (!$_.Completed) {
                    $_.NextTriggerTime = $_now.AddSeconds($_.Interval)
                }
                else {
                    $_.NextTriggerTime = $null
                }

                # run the timer
                Invoke-PodeInternalTimer -Timer $_
            }

            Start-Sleep -Seconds 1
        }
    }

    Add-PodeRunspace -Type Main -ScriptBlock $script
}

function Invoke-PodeInternalTimer {
    param(
        [Parameter(Mandatory = $true)]
        $Timer,

        [Parameter()]
        [object[]]
        $ArgumentList = $null
    )

    try {
        $global:TimerEvent = @{
            Lockable = $PodeContext.Threading.Lockables.Global
            Sender   = $Timer
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
        $null = Invoke-PodeScriptBlock -ScriptBlock $Timer.Script -Arguments $_args -UsingVariables $Timer.UsingVariables -Scoped -Splat
    }
    catch {
        $_ | Write-PodeErrorLog
    }
}