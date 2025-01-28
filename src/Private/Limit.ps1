function Get-PodeLimitRateTimerName {
    return '__pode_rate_limit_housekeeper__'
}

function Test-PodeLimitRateTimer {
    return Test-PodeTimer -Name (Get-PodeLimitRateTimerName)
}

function Add-PodeLimitRateTimer {
    if (Test-PodeLimitRateTimer) {
        return
    }

    Add-PodeTimer -Name (Get-PodeLimitRateTimerName) -Interval 30 -ScriptBlock {
        try {
            $now = [DateTime]::UtcNow
            $value = $null

            foreach ($rule in $PodeContext.Server.Limits.Rate.Rules.Values) {
                if ($rule.Active.Count -eq 0) {
                    continue
                }

                foreach ($key in $rule.Active.Keys.Clone()) {
                    try {
                        $item = $rule.Active[$key]

                        if ($item.Timeout.AddSeconds(5) -lt $now) {
                            $rule.Active.TryRemove($key, [ref]$value)
                        }
                    }
                    catch {
                        $_ | Write-PodeErrorLog
                    }
                }
            }
        }
        catch {
            $_ | Write-PodeErrorLog
        }
    }
}

function Remove-PodeLimitRateTimer {
    if (($PodeContext.Server.Limits.Rate.Rules.Count -gt 0) -or !(Test-PodeLimitRateTimer)) {
        return
    }

    Remove-PodeTimer -Name (Get-PodeLimitRateTimerName)
}