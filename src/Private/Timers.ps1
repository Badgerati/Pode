function Get-PodeTimer
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

            $PodeContext.Timers.Values | Where-Object {
                ($_.OnStart -or ($_.NextTick -le $_now)) -and !$_.Completed
            } | ForEach-Object {
                $run = $true
                $_.OnStart = $false

                # increment total number of runs for timer (do we still need to count?)
                if ($_.Countable) {
                    $_.Count++
                    $_.Countable = ($_.Count -le $_.Limit)
                }

                # check if we have hit the limit, and remove
                if ($run -and ($_.Limit -ne 0) -and ($_.Count -gt $_.Limit)) {
                    $run = $false
                    $_.Completed = $true
                }

                if ($run) {
                    Invoke-PodeInternalTimer -Timer $_
                }

                $_.NextTick = $_now.AddSeconds($_.Interval)
            }

            Start-Sleep -Seconds 1
        }
    }

    Add-PodeRunspace -Type 'Main' -ScriptBlock $script
}

function Invoke-PodeInternalTimer
{
    param(
        [Parameter(Mandatory=$true)]
        $Timer
    )

    try {
        $_event = @{ Lockable = $PodeContext.Lockable }
        $_args = @($_event) + @($Timer.Arguments)
        Invoke-PodeScriptBlock -ScriptBlock $Timer.Script -Arguments $_args -Scoped -Splat
    }
    catch {
        $_ | Write-PodeErrorLog
    }
}