[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
param()

BeforeAll {
    $path = $PSCommandPath
    $src = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]unit', '/src/'
    Get-ChildItem "$($src)/*.ps1" -Recurse | Resolve-Path | ForEach-Object { . $_ }
    Import-LocalizedData -BindingVariable msgTable -BaseDirectory (Join-Path -Path $src -ChildPath 'Locales') -UICulture 'en-us' -FileName 'Pode'

    $PodeContext = @{ 'Server' = $null; }
}

Describe 'Find-PodeTimer' {
    Context 'Invalid parameters supplied' {
        It 'Throw null name parameter error' {
            { Find-PodeTimer -Name $null } | Should -Throw -ExpectedMessage '*The argument is null or empty*'
        }

        It 'Throw empty name parameter error' {
            { Find-PodeTimer -Name ([string]::Empty) } | Should -Throw -ExpectedMessage  '*The argument is null or empty*'
        }
    }

    Context 'Valid values supplied' {
        It 'Returns null as the timer does not exist' {
            $PodeContext = @{ 'Timers' = @{ Items = @{} }; }
            Find-PodeTimer -Name 'test' | Should -Be $null
        }

        It 'Returns timer for name' {
            $PodeContext = @{ 'Timers' = @{ Items = @{ 'test' = @{ 'Name' = 'test'; }; } }; }
            $result = (Find-PodeTimer -Name 'test')

            $result | Should -BeOfType System.Collections.Hashtable
            $result.Name | Should -Be 'test'
        }
    }
}

Describe 'Add-PodeTimer' {
    It 'Throws error because timer already exists' {
        $PodeContext = @{ 'Timers' = @{ Items = @{ 'test' = $null }; } }
        { Add-PodeTimer -Name 'test' -Interval 1 -ScriptBlock {} } | Should -Throw -ExpectedMessage '*already defined*'
    }

    It 'Throws error because interval is 0' {
        $PodeContext = @{ 'Timers' = @{ Items = @{} }; }
        { Add-PodeTimer -Name 'test' -Interval 0 -ScriptBlock {} } | Should -Throw -ExpectedMessage '*interval must be greater than 0*'
    }

    It 'Throws error because interval is less than 0' {
        $PodeContext = @{ 'Timers' = @{ Items = @{} }; }
        { Add-PodeTimer -Name 'test' -Interval -1 -ScriptBlock {} } | Should -Throw -ExpectedMessage '*interval must be greater than 0*'
    }

    It 'Throws error because limit is negative' {
        $PodeContext = @{ 'Timers' = @{ Items = @{} }; }
        { Add-PodeTimer -Name 'test' -Interval 1 -ScriptBlock {} -Limit -1 } | Should -Throw -ExpectedMessage '*negative limit*'
    }

    It 'Throws error because skip is negative' {
        $PodeContext = @{ 'Timers' = @{ Items = @{} }; }
        { Add-PodeTimer -Name 'test' -Interval 1 -ScriptBlock {} -Skip -1 } | Should -Throw -ExpectedMessage '*negative skip*'
    }

    It 'Adds new timer to session with no limit' {
        $PodeContext = @{ 'Timers' = @{ Items = @{} }; }
        Add-PodeTimer -Name 'test' -Interval 1 -ScriptBlock { Write-Host 'hello' } -Limit 0 -Skip 1

        $timer = $PodeContext.Timers.Items['test']
        $timer | Should -Not -Be $null
        $timer.Name | Should -Be 'test'
        $timer.Interval | Should -Be 1
        $timer.Limit | Should -Be 0
        $timer.Count | Should -Be 0
        $timer.Skip | Should -Be 1
        $timer.NextTriggerTime | Should -BeOfType System.DateTime
        $timer.Script | Should -Not -Be $null
        $timer.Script.ToString() | Should -Be ({ Write-Host 'hello' }).ToString()
    }

    It 'Adds new timer to session with limit' {
        $PodeContext = @{ 'Timers' = @{ Items = @{} }; }
        Add-PodeTimer -Name 'test' -Interval 3 -ScriptBlock { Write-Host 'hello' } -Limit 2 -Skip 1

        $timer = $PodeContext.Timers.Items['test']
        $timer | Should -Not -Be $null
        $timer.Name | Should -Be 'test'
        $timer.Interval | Should -Be 3
        $timer.Limit | Should -Be 2
        $timer.Count | Should -Be 0
        $timer.Skip | Should -Be 1
        $timer.NextTriggerTime | Should -BeOfType System.DateTime
        $timer.Script | Should -Not -Be $null
        $timer.Script.ToString() | Should -Be ({ Write-Host 'hello' }).ToString()
    }
}

Describe 'Get-PodeTimer' {
    It 'Returns no timers' {
        $PodeContext = @{ Timers = @{ Items = @{} } }
        $timers = Get-PodeTimer
        $timers.Length | Should -Be 0
    }

    It 'Returns 1 timer by name' {
        $PodeContext = @{ Timers = @{ Items = @{} } }

        Add-PodeTimer -Name 'test1' -Interval 1 -ScriptBlock { Write-Host 'hello' } -Limit 0 -Skip 1
        $timers = Get-PodeTimer
        $timers.Length | Should -Be 1

        $timers.Name | Should -Be 'test1'
        $timers.Interval | Should -Be 1
        $timers.Skip | Should -Be 1
        $timers.Limit | Should -Be 0
    }

    It 'Returns 2 timers by name' {
        $PodeContext = @{ Timers = @{ Items = @{} } }

        Add-PodeTimer -Name 'test1' -Interval 1 -ScriptBlock { Write-Host 'hello' } -Limit 0 -Skip 1
        Add-PodeTimer -Name 'test2' -Interval 1 -ScriptBlock { Write-Host 'hello' } -Limit 0 -Skip 1
        Add-PodeTimer -Name 'test3' -Interval 1 -ScriptBlock { Write-Host 'hello' } -Limit 0 -Skip 1

        $timers = Get-PodeTimer -Name test1, test2
        $timers.Length | Should -Be 2
    }

    It 'Returns all timers' {
        $PodeContext = @{ Timers = @{ Items = @{} } }

        Add-PodeTimer -Name 'test1' -Interval 1 -ScriptBlock { Write-Host 'hello' } -Limit 0 -Skip 1
        Add-PodeTimer -Name 'test2' -Interval 1 -ScriptBlock { Write-Host 'hello' } -Limit 0 -Skip 1
        Add-PodeTimer -Name 'test3' -Interval 1 -ScriptBlock { Write-Host 'hello' } -Limit 0 -Skip 1

        $timers = Get-PodeTimer
        $timers.Length | Should -Be 3
    }
}

Describe 'Remove-PodeTimer' {
    It 'Adds new timer and then removes it' {
        $PodeContext = @{ 'Timers' = @{ Items = @{} }; }
        Add-PodeTimer -Name 'test' -Interval 1 -ScriptBlock { Write-Host 'hello' }

        $timer = $PodeContext.Timers.Items['test']
        $timer.Name | Should -Be 'test'
        $timer.Script.ToString() | Should -Be ({ Write-Host 'hello' }).ToString()

        Remove-PodeTimer -Name 'test'

        $timer = $PodeContext.Timers.Items['test']
        $timer | Should -Be $null
    }
}

Describe 'Clear-PodeTimers' {
    It 'Adds new timers and then removes them' {
        $PodeContext = @{ 'Timers' = @{ Items = @{} }; }
        Add-PodeTimer -Name 'test1' -Interval 1 -ScriptBlock { Write-Host 'hello1' }
        Add-PodeTimer -Name 'test2' -Interval 1 -ScriptBlock { Write-Host 'hello2' }

        $PodeContext.Timers.Items.Count | Should -Be 2

        Clear-PodeTimers

        $PodeContext.Timers.Items.Count | Should -Be 0
    }
}

Describe 'Edit-PodeTimer' {
    It 'Adds a new timer, then edits the interval' {
        $PodeContext = @{ 'Timers' = @{ Items = @{} }; }
        Add-PodeTimer -Name 'test1' -Interval 1 -ScriptBlock { Write-Host 'hello1' }
        $PodeContext.Timers.Items['test1'].Interval | Should -Be 1
        $PodeContext.Timers.Items['test1'].Script.ToString() | Should -Be ({ Write-Host 'hello1' }).ToString()

        Edit-PodeTimer -Name 'test1' -Interval 3
        $PodeContext.Timers.Items['test1'].Interval | Should -Be 3
        $PodeContext.Timers.Items['test1'].Script.ToString() | Should -Be ({ Write-Host 'hello1' }).ToString()
    }

    It 'Adds a new timer, then edits the script' {
        $PodeContext = @{ 'Timers' = @{ Items = @{} }; }
        Add-PodeTimer -Name 'test1' -Interval 1 -ScriptBlock { Write-Host 'hello1' }
        $PodeContext.Timers.Items['test1'].Interval | Should -Be 1
        $PodeContext.Timers.Items['test1'].Script.ToString() | Should -Be ({ Write-Host 'hello1' }).ToString()

        Edit-PodeTimer -Name 'test1' -ScriptBlock { Write-Host 'hello2' }
        $PodeContext.Timers.Items['test1'].Interval | Should -Be 1
        $PodeContext.Timers.Items['test1'].Script.ToString() | Should -Be ({ Write-Host 'hello2' }).ToString()
    }
}