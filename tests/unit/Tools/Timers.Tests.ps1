$path = $MyInvocation.MyCommand.Path
$src = (Split-Path -Parent -Path $path) -ireplace '\\tests\\unit\\', '\src\'
$sut = (Split-Path -Leaf -Path $path) -ireplace '\.Tests\.', '.'
. "$($src)\$($sut)"

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
            $PodeSession = @{ 'Timers' = @{}; }
            Get-PodeTimer -Name 'test' | Should Be $null
        }

        It 'Returns timer for name' {
            $PodeSession = @{ 'Timers' = @{ 'test' = @{ 'Name' = 'test'; }; }; }
            $result = (Get-PodeTimer -Name 'test')

            $result | Should BeOfType System.Collections.Hashtable
            $result.Name | Should Be 'test'
        }
    }
}

Describe 'Timer' {
    Context 'Invalid parameters supplied' {
        It 'Throw null name parameter error' {
            { Timer -Name $null -Interval 0 -ScriptBlock {} } | Should Throw 'The argument is null or empty'
        }

        It 'Throw empty name parameter error' {
            { Timer -Name ([string]::Empty) -Interval 0 -ScriptBlock {} } | Should Throw 'The argument is null or empty'
        }

        It 'Throw null scriptblock parameter error' {
            { Timer -Name 'test' -Interval 0 -ScriptBlock $null } | Should Throw 'The argument is null'
        }
    }

    Context 'Valid timer parameters' {
        It 'Throws error because timer already exists' {
            $PodeSession = @{ 'Timers' = @{ 'test' = $null }; }
            { Timer -Name 'test' -Interval 1 -ScriptBlock {} } | Should Throw 'already exists'
        }

        It 'Throws error because interval is 0' {
            $PodeSession = @{ 'Timers' = @{}; }
            { Timer -Name 'test' -Interval 0 -ScriptBlock {} } | Should Throw 'interval less than or equal to 0'
        }

        It 'Throws error because interval is less than 0' {
            $PodeSession = @{ 'Timers' = @{}; }
            { Timer -Name 'test' -Interval -1 -ScriptBlock {} } | Should Throw 'interval less than or equal to 0'
        }

        It 'Throws error because limit is negative' {
            $PodeSession = @{ 'Timers' = @{}; }
            { Timer -Name 'test' -Interval 1 -ScriptBlock {} -Limit -1 } | Should Throw 'negative limit'
        }

        It 'Throws error because skip is negative' {
            $PodeSession = @{ 'Timers' = @{}; }
            { Timer -Name 'test' -Interval 1 -ScriptBlock {} -Skip -1 } | Should Throw 'negative skip'
        }

        It 'Adds new timer to session with no limit' {
            $PodeSession = @{ 'Timers' = @{}; }
            Timer -Name 'test' -Interval 1 -ScriptBlock { Write-Host 'hello' } -Limit 0 -Skip 1

            $timer = $PodeSession.Timers['test']
            $timer | Should Not Be $null
            $timer.Name | Should Be 'test'
            $timer.Interval | Should Be 1
            $timer.Limit | Should Be 0
            $timer.Count | Should Be 0
            $timer.Skip | Should Be 1
            $timer.Countable | Should Be $true
            $timer.NextTick | Should BeOfType System.DateTime
            $timer.Script | Should Not Be $null
            $timer.Script.ToString() | Should Be ({ Write-Host 'hello' }).ToString()
        }

        It 'Adds new timer to session with limit' {
            $PodeSession = @{ 'Timers' = @{}; }
            Timer -Name 'test' -Interval 3 -ScriptBlock { Write-Host 'hello' } -Limit 2 -Skip 1

            $timer = $PodeSession.Timers['test']
            $timer | Should Not Be $null
            $timer.Name | Should Be 'test'
            $timer.Interval | Should Be 3
            $timer.Limit | Should Be 3
            $timer.Count | Should Be 0
            $timer.Skip | Should Be 1
            $timer.Countable | Should Be $true
            $timer.NextTick | Should BeOfType System.DateTime
            $timer.Script | Should Not Be $null
            $timer.Script.ToString() | Should Be ({ Write-Host 'hello' }).ToString()
        }
    }
}