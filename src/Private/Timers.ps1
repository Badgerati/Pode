function Find-PodeTimer
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name
    )

    return $PodeContext.Timers[$Name]
}

function Start-PodeTimerRunspace
{
    if ((Get-PodeCount $PodeContext.Timers) -eq 0) {
        return
    }

    $script = {
        while ($true)
        {
            $_now = [DateTime]::Now

            # only run timers that haven't completed, and have a next trigger in the past
            $PodeContext.Timers.Values | Where-Object {
                !$_.Completed -and ($_.OnStart -or ($_.NextTriggerTime -le $_now))
            } | ForEach-Object {
                $_.OnStart = $false
                $_.Count++

                # has the timer completed?
                if (($_.Limit -gt 0) -and ($_.Count -ge $_.Limit)) {
                    $_.Completed = $true
                }

                # run the timer
                Invoke-PodeInternalTimer -Timer $_

                # next trigger
                if (!$_.Completed) {
                    $_.NextTriggerTime = $_now.AddSeconds($_.Interval)
                }
                else {
                    $_.NextTriggerTime = $null
                }
            }

            Start-Sleep -Seconds 1
        }
    }

    Add-PodeRunspace -Type Main -ScriptBlock $script
}

function Invoke-PodeInternalTimer
{
    param(
        [Parameter(Mandatory=$true)]
        $Timer
    )

    try {
        $TimerEvent = @{ Lockable = $PodeContext.Lockable }

        $_args = @($Timer.Arguments)
        if ($null -ne $Timer.UsingVariables) {
            $_args = @($Timer.UsingVariables.Value) + $_args
        }

        Invoke-PodeScriptBlock -ScriptBlock $Timer.Script -Arguments $_args -Scoped -Splat
    }
    catch {
        $_ | Write-PodeErrorLog
    }
}