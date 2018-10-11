function Get-PodeTimer
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name
    )

    return $PodeSession.Timers[$Name]
}

function Start-TimerRunspace
{
    if (($PodeSession.Timers | Measure-Object).Count -eq 0) {
        return
    }

    $script = {
        while ($true)
        {
            $_remove = @()
            $_now = [DateTime]::Now

            $PodeSession.Timers.Values | Where-Object { $_.NextTick -le $_now } | ForEach-Object {
                $run = $true

                # increment total number of runs for timer (do we still need to count?)
                if ($_.Countable) {
                    $_.Count++
                    $_.Countable = ($_.Count -lt $_.Skip -or $_.Count -lt $_.Limit)
                }

                # check if this run should be skipped
                if ($_.Count -lt $_.Skip) {
                    $run = $false
                }

                # check if we have hit the limit, and remove
                if ($run -and $_.Limit -ne 0 -and $_.Count -ge $_.Limit) {
                    $run = $false
                    $_remove += $_.Name
                }

                if ($run) {
                    try {
                        Invoke-ScriptBlock -ScriptBlock $_.Script -Arguments @{ 'Lockable' = $PodeSession.Lockable } -Scoped
                    }
                    catch {
                        $Error[0]
                    }

                    $_.NextTick = $_now.AddSeconds($_.Interval)
                }
            }

            # remove any timers
            $_remove | ForEach-Object {
                $PodeSession.Timers.Remove($_)
            }

            Start-Sleep -Seconds 1
        }
    }

    Add-PodeRunspace -Type 'Main' -ScriptBlock $script
}

function Timer
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name,

        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [Alias('i')]
        [int]
        $Interval,

        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [Alias('l')]
        [int]
        $Limit = 0,

        [Parameter()]
        [Alias('s')]
        [int]
        $Skip = 0
    )

    # lower the name
    $Name = $Name.ToLowerInvariant()

    # ensure the timer doesn't already exist
    if ($PodeSession.Timers.ContainsKey($Name)) {
        throw "Timer called $($Name) already exists"
    }

    # is the interval valid?
    if ($Interval -le 0) {
        throw "Timer $($Name) cannot have an interval less than or equal to 0"
    }

    # is the limit valid?
    if ($Limit -lt 0) {
        throw "Timer $($Name) cannot have a negative limit"
    }

    if ($Limit -ne 0) {
        $Limit += $Skip
    }

    # is the skip valid?
    if ($Skip -lt 0) {
        throw "Timer $($Name) cannot have a negative skip value"
    }

    # run script if it's not being skipped
    if ($Skip -eq 0) {
        Invoke-ScriptBlock -ScriptBlock $ScriptBlock -Arguments @{ 'Lockable' = $PodeSession.Lockable } -Scoped
    }

    # add the timer
    $PodeSession.Timers[$Name] = @{
        'Name' = $Name;
        'Interval' = $Interval;
        'Limit' = $Limit;
        'Count' = 0;
        'Skip' = $Skip;
        'Countable' = ($Skip -gt 0 -or $Limit -gt 0);
        'NextTick' = [DateTime]::Now.AddSeconds($Interval);
        'Script' = $ScriptBlock;
    }
}