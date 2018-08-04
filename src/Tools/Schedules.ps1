function Get-PodeSchedule
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name
    )

    return $PodeSession.Schedules[$Name]
}

function Start-ScheduleRunspace
{
    if (($PodeSession.Schedules | Measure-Object).Count -eq 0) {
        return
    }

    $script = {
        # first, sleep for a period of time to get to 00 seconds (start of minute)
        Start-Sleep -Seconds (60 - [DateTime]::Now.Second)

        while ($true)
        {
            $_now = [DateTime]::Now

            $PodeSession.Schedules.Values |
                Where-Object {
                    ($null -eq $_.StartTime -or $_.StartTime -le $_now) -and
                    ($null -eq $_.EndTime -or $_.EndTime -ge $_now) -and
                    (Test-CronExpression -Expression $_.Cron -DateTime $_now)
                } | ForEach-Object {

                try {
                    Add-PodeRunspace -ScriptBlock (($_.Script).GetNewClosure()) `
                        -Parameters @{ 'Lockable' = $PodeSession.Lockable } -Forget
                }
                catch {
                    $Error[0]
                }
            }

            # cron expression only goes down to the minute, so sleep for 1min
            Start-Sleep -Seconds 60
        }
    }

    Add-PodeRunspace $script
}

function Schedule
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Cron,

        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        $StartTime = $null,

        [Parameter()]
        $EndTime = $null
    )

    # lower the name
    $Name = $Name.ToLowerInvariant()

    # ensure the schedule doesn't already exist
    if ($PodeSession.Schedules.ContainsKey($Name)) {
        throw "Schedule called $($Name) already exists"
    }

    # ensure the start/end dates are valid
    if ($null -ne $EndTime -and $EndTime -lt [DateTime]::Now) {
        throw "Schedule $($Name) must have an EndTime in the future"
    }

    if ($null -ne $StartTime -and $null -ne $EndTime -and $EndTime -lt $StartTime) {
        throw "Schedule $($Name) cannot have a StartTime after the EndTime"
    }

    # parse the cron expression
    $exp = ConvertFrom-CronExpression -Expression $Cron

    # add the schedule
    $PodeSession.Schedules[$Name] = @{
        'Name' = $Name;
        'StartTime' = $StartTime;
        'EndTime' = $EndTime;
        'Cron' = $exp;
        'Script' = $ScriptBlock
    }
}