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
}