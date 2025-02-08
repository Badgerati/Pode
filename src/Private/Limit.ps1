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

function Invoke-PodeLimitAccessRuleRequest {
    # are there any rules?
    if ($PodeContext.Server.Limits.Access.Rules.Count -eq 0) {
        return $null
    }

    # generate the rule order, if rules have been altered
    if ($PodeContext.Server.Limits.Access.RulesAltered) {
        $PodeContext.Server.Limits.Access.RulesOrder = $PodeContext.Server.Limits.Access.Rules.Values |
            Sort-Object -Property { $_.Priority } -Descending |
            Select-Object -ExpandProperty Name
        $PodeContext.Server.Limits.Access.RulesAltered = $false
    }

    # loop through each access rule
    foreach ($ruleName in $PodeContext.Server.Limits.Access.RulesOrder) {
        $rule = $PodeContext.Server.Limits.Access.Rules[$ruleName]

        # loop through each component of the rule, checking if the request matches
        $skip = $false
        foreach ($component in $rule.Components) {
            $result = Invoke-PodeScriptBlock -ScriptBlock $component.ScriptBlock -Arguments $component.Options -Return

            # if result is null/empty then move to the next rule
            if ([string]::IsNullOrEmpty($result)) {
                $skip = $true
                break
            }
        }

        # if we skipped the rule, then move to the next one
        if ($skip) {
            continue
        }

        # if we get here, then the request matches all the components - so allow or deny the request
        if ($rule.Action -ieq 'Deny') {
            return @{
                StatusCode = $rule.StatusCode
            }
        }

        return $null
    }

    # if we get here, then the request didn't match any rules
    # if we have any allow rules, then deny the request
    if ($PodeContext.Server.Limits.Access.HaveAllowRules) {
        return @{
            StatusCode = 403
        }
    }

    return $null
}

function Test-PodeLimitAccessRuleRequest {
    $result = Invoke-PodeLimitAccessRuleRequest
    return ($null -eq $result)
}

function Invoke-PodeLimitRateRuleRequest {
    # are there any rate rules?
    if ($PodeContext.Server.Limits.Rate.Rules.Count -eq 0) {
        return $null
    }

    # generate the rule order, if rules have been altered
    if ($PodeContext.Server.Limits.Rate.RulesAltered) {
        $PodeContext.Server.Limits.Rate.RulesOrder = $PodeContext.Server.Limits.Rate.Rules.Values |
            Sort-Object -Property { $_.Priority } -Descending |
            Select-Object -ExpandProperty Name
        $PodeContext.Server.Limits.Rate.RulesAltered = $false
    }

    # loop through each rate rule
    foreach ($ruleName in $PodeContext.Server.Limits.Rate.RulesOrder) {
        $rule = $PodeContext.Server.Limits.Rate.Rules[$ruleName]
        $ruleKey = @()
        $now = [DateTime]::UtcNow

        # loop through each component of the rule
        $skip = $false
        foreach ($component in $rule.Components) {
            $result = Invoke-PodeScriptBlock -ScriptBlock $component.ScriptBlock -Arguments $component.Options -Return

            # if result is null/empty then move to the next rule
            if ([string]::IsNullOrEmpty($result)) {
                $skip = $true
                break
            }

            # add the result to the rule key
            $ruleKey += $result
        }

        # if we skipped the rule, then move to the next one
        if ($skip) {
            continue
        }

        # concatenate the rule key
        $ruleKey = $ruleKey -join '|'

        # if it's not in the active dictionary, or the timeout has passed, then add/reset it
        if (!$rule.Active.ContainsKey($ruleKey) -or ($rule.Active[$ruleKey].Timeout -le $now)) {
            $rule.Active[$ruleKey] = @{
                Timeout = $now.AddMilliseconds($rule.Duration)
                Counter = 0
            }
        }

        # increment the counter
        $rule.Active[$ruleKey].Counter++

        # if the key is in the active dictionary, then check the timeout/counter and set the status code if needed
        if ($rule.Active.ContainsKey($ruleKey) -and
            ($rule.Active[$ruleKey].Timeout -gt $now) -and
            ($rule.Active[$ruleKey].Counter -gt $rule.Limit)) {
            return @{
                RetryAfter = [int][System.Math]::Ceiling(($rule.Active[$ruleKey].Timeout - $now).TotalSeconds)
                StatusCode = $rule.StatusCode
            }
        }
    }

    # request is allowed
    return $null
}

function Test-PodeLimitRateRuleRequest {
    $result = Invoke-PodeLimitRateRuleRequest
    return ($null -eq $result)
}