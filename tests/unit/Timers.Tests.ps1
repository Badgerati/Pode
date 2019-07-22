$path = $MyInvocation.MyCommand.Path
$src = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]unit', '/src/'
Get-ChildItem "$($src)/*.ps1" -Recurse | Resolve-Path | ForEach-Object { . $_ }

Describe 'Get-PodeTimer' {
    Context 'Invalid parameters supplied' {
        It 'Throw null name parameter error' {
            { Get-PodeTimer -Name $null } | Should Throw 'The argument is null or empty'
        }

        It 'Throw empty name parameter error' {
            { Get-PodeTimer -Name ([string]::Empty) } | Should Throw 'The argument is null or empty'
        }
    }

    Context 'Valid values supplied' {
        It 'Returns null as the timer does not exist' {
            $PodeContext = @{ 'Timers' = @{}; }
            Get-PodeTimer -Name 'test' | Should Be $null
        }

        It 'Returns timer for name' {
            $PodeContext = @{ 'Timers' = @{ 'test' = @{ 'Name' = 'test'; }; }; }
            $result = (Get-PodeTimer -Name 'test')

            $result | Should BeOfType System.Collections.Hashtable
            $result.Name | Should Be 'test'
        }
    }
}

Describe 'Add-PodeTimer' {
    It 'Throws error because timer already exists' {
        $PodeContext = @{ 'Timers' = @{ 'test' = $null }; }
        { Add-PodeTimer -Name 'test' -Interval 1 -ScriptBlock {} } | Should Throw 'already defined'
    }

    It 'Throws error because interval is 0' {
        $PodeContext = @{ 'Timers' = @{}; }
        { Add-PodeTimer -Name 'test' -Interval 0 -ScriptBlock {} } | Should Throw 'interval must be greater than 0'
    }

    It 'Throws error because interval is less than 0' {
        $PodeContext = @{ 'Timers' = @{}; }
        { Add-PodeTimer -Name 'test' -Interval -1 -ScriptBlock {} } | Should Throw 'interval must be greater than 0'
    }

    It 'Throws error because limit is negative' {
        $PodeContext = @{ 'Timers' = @{}; }
        { Add-PodeTimer -Name 'test' -Interval 1 -ScriptBlock {} -Limit -1 } | Should Throw 'negative limit'
    }

    It 'Throws error because skip is negative' {
        $PodeContext = @{ 'Timers' = @{}; }
        { Add-PodeTimer -Name 'test' -Interval 1 -ScriptBlock {} -Skip -1 } | Should Throw 'negative skip'
    }

    It 'Adds new timer to session with no limit' {
        $PodeContext = @{ 'Timers' = @{}; }
        Add-PodeTimer -Name 'test' -Interval 1 -ScriptBlock { Write-Host 'hello' } -Limit 0 -Skip 1

        $timer = $PodeContext.Timers['test']
        $timer | Should Not Be $null
        $timer.Name | Should Be 'test'
        $timer.Interval | Should Be 1
        $timer.Limit | Should Be 0
        $timer.Count | Should Be 0
        $timer.Skip | Should Be 1
        $timer.Countable | Should Be $false
        $timer.NextTick | Should BeOfType System.DateTime
        $timer.Script | Should Not Be $null
        $timer.Script.ToString() | Should Be ({ Write-Host 'hello' }).ToString()
    }

    It 'Adds new timer to session with limit' {
        $PodeContext = @{ 'Timers' = @{}; }
        Add-PodeTimer -Name 'test' -Interval 3 -ScriptBlock { Write-Host 'hello' } -Limit 2 -Skip 1

        $timer = $PodeContext.Timers['test']
        $timer | Should Not Be $null
        $timer.Name | Should Be 'test'
        $timer.Interval | Should Be 3
        $timer.Limit | Should Be 2
        $timer.Count | Should Be 0
        $timer.Skip | Should Be 1
        $timer.Countable | Should Be $true
        $timer.NextTick | Should BeOfType System.DateTime
        $timer.Script | Should Not Be $null
        $timer.Script.ToString() | Should Be ({ Write-Host 'hello' }).ToString()
    }
}

Describe 'Remove-PodeTimer' {
    It 'Adds new timer and then removes it' {
        $PodeContext = @{ 'Timers' = @{}; }
        Add-PodeTimer -Name 'test' -Interval 1 -ScriptBlock { Write-Host 'hello' }

        $timer = $PodeContext.Timers['test']
        $timer.Name | Should Be 'test'
        $timer.Script.ToString() | Should Be ({ Write-Host 'hello' }).ToString()

        Remove-PodeTimer -Name 'test'

        $timer = $PodeContext.Timers['test']
        $timer | Should Be $null
    }
}

Describe 'Clear-PodeTimers' {
    It 'Adds new timers and then removes them' {
        $PodeContext = @{ 'Timers' = @{}; }
        Add-PodeTimer -Name 'test1' -Interval 1 -ScriptBlock { Write-Host 'hello1' }
        Add-PodeTimer -Name 'test2' -Interval 1 -ScriptBlock { Write-Host 'hello2' }

        $PodeContext.Timers.Count | Should Be 2

        Clear-PodeTimers

        $PodeContext.Timers.Count | Should Be 0
    }
}