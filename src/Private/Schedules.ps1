function Get-PodeSchedule
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name
    )

    return $PodeContext.Schedules[$Name]
}

function Start-PodeScheduleRunspace
{
    if ((Get-PodeCount $PodeContext.Schedules) -eq 0) {
        return
    }

    $script = {
        # first, sleep for a period of time to get to 00 seconds (start of minute)
        Start-Sleep -Seconds (60 - [DateTime]::Now.Second)

        while ($true)
        {
            $_remove = @()
            $_now = [DateTime]::Now

            # select the schedules that need triggering
            $PodeContext.Schedules.Values |
                Where-Object {
                    (($null -eq $_.StartTime) -or ($_.StartTime -le $_now)) -and
                    (($null -eq $_.EndTime) -or ($_.EndTime -ge $_now)) -and
                    (Test-PodeCronExpressions -Expressions $_.Crons -DateTime $_now)
                } | ForEach-Object {

                # increment total number of triggers for the schedule
                if ($_.Countable) {
                    $_.Count++
                    $_.Countable = ($_.Count -lt $_.Limit)
                }

                # check if we have hit the limit, and remove
                if ($_.Limit -ne 0 -and $_.Count -ge $_.Limit) {
                    $_remove += $_.Name
                }

                # trigger the schedules logic
                try {
                    Add-PodeRunspace -Type 'Schedules' -ScriptBlock (($_.Script).GetNewClosure()) `
                        -Parameters @{ 'Lockable' = $PodeContext.Lockable } -Forget
                }
                catch {
                    $Error[0] | Out-Default
                }

                # reset the cron if it's random
                $_.Crons = Reset-PodeRandomCronExpressions -Expressions $_.Crons
            }

            # add any schedules to remove that have exceeded their end time
            $_remove += @($PodeContext.Schedules.Values |
                Where-Object { (($null -ne $_.EndTime) -and ($_.EndTime -lt $_now)) }).Name

            # remove any schedules
            foreach ($name in $_remove) {
                if ($PodeContext.Schedules.ContainsKey($name)) {
                    $PodeContext.Schedules.Remove($name) | Out-Null
                }
            }

            # cron expression only goes down to the minute, so sleep for 1min
            Start-Sleep -Seconds (60 - [DateTime]::Now.Second)
        }
    }

    Add-PodeRunspace -Type 'Main' -ScriptBlock $script
}