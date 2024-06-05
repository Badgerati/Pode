[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
param()

BeforeAll {
    $path = $PSCommandPath
    $src = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]unit', '/src/'
    Get-ChildItem "$($src)/*.ps1" -Recurse | Resolve-Path | ForEach-Object { . $_ }
    Import-LocalizedData -BindingVariable PodeLocale -BaseDirectory (Join-Path -Path $src -ChildPath 'Locales') -UICulture 'en-us' -FileName 'Pode'
}
Describe 'Find-PodeSchedule' {
    Context 'Invalid parameters supplied' {
        It 'Throw null name parameter error' {
            { Find-PodeSchedule -Name $null } | Should -Throw -ExpectedMessage '*The argument is null or empty*'
        }

        It 'Throw empty name parameter error' {
            { Find-PodeSchedule -Name ([string]::Empty) } | Should -Throw -ExpectedMessage '*The argument is null or empty*'
        }
    }

    Context 'Valid values supplied' {
        It 'Returns null as the schedule does not exist' {
            $PodeContext = @{ 'Schedules' = @{ Items = @{} }; }
            Find-PodeSchedule -Name 'test' | Should -Be $null
        }

        It 'Returns schedule for name' {
            $PodeContext = @{ 'Schedules' = @{ Items = @{ 'test' = @{ 'Name' = 'test'; }; } }; }
            $result = (Find-PodeSchedule -Name 'test')

            $result | Should -BeOfType System.Collections.Hashtable
            $result.Name | Should -Be 'test'
        }
    }
}

Describe 'Add-PodeSchedule' {
    BeforeAll {
        Mock 'Get-PodeCronNextEarliestTrigger' { [datetime]::new(2020, 1, 1) }
    }
    It 'Throws error because schedule already exists' {
        $PodeContext = @{ 'Schedules' = @{ Items = @{ 'test' = $null }; } }
        { Add-PodeSchedule -Name 'test' -Cron '@hourly' -ScriptBlock {} } | Should -Throw -ExpectedMessage '*already defined*'
    }

    It 'Throws error because end time in the past' {
        $PodeContext = @{ 'Schedules' = @{ Items = @{} }; }
        $end = ([DateTime]::Now.AddHours(-1))
        { Add-PodeSchedule -Name 'test' -Cron '@hourly' -ScriptBlock {} -EndTime $end } | Should -Throw -ExpectedMessage '*the EndTime value must be in the future*'
    }

    It 'Throws error because start time is after end time' {
        $PodeContext = @{ 'Schedules' = @{ Items = @{} }; }
        $start = ([DateTime]::Now.AddHours(3))
        $end = ([DateTime]::Now.AddHours(1))
        $expectedMessage = ($PodeLocale.scheduleStartTimeAfterEndTimeExceptionMessage -f 'test') -replace '\[', '`[' -replace '\]', '`]'
        { Add-PodeSchedule -Name 'test' -Cron '@hourly' -ScriptBlock {} -StartTime $start -EndTime $end } | Should -Throw -ExpectedMessage  $expectedMessage # [Schedule] {0}: Cannot have a 'StartTime' after the 'EndTime'
    }

    It 'Adds new schedule supplying everything' {
        $PodeContext = @{ 'Schedules' = @{ Items = @{} }; }
        $start = ([DateTime]::Now.AddHours(3))
        $end = ([DateTime]::Now.AddHours(5))

        Add-PodeSchedule -Name 'test' -Cron '@hourly' -ScriptBlock { Write-Host 'hello' } -StartTime $start -EndTime $end

        $schedule = $PodeContext.Schedules.Items['test']
        $schedule | Should -Not -Be $null
        $schedule.Name | Should -Be 'test'
        $schedule.StartTime | Should -Be $start
        $schedule.EndTime | Should -Be $end
        $schedule.Script | Should -Not -Be $null
        $schedule.Script.ToString() | Should -Be ({ Write-Host 'hello' }).ToString()
        $schedule.Crons.Length | Should -Be 1
    }

    It 'Adds new schedule with no start time' {
        $PodeContext = @{ 'Schedules' = @{ Items = @{} }; }
        $end = ([DateTime]::Now.AddHours(5))

        Add-PodeSchedule -Name 'test' -Cron '@hourly' -ScriptBlock { Write-Host 'hello' } -EndTime $end

        $schedule = $PodeContext.Schedules.Items['test']
        $schedule | Should -Not -Be $null
        $schedule.Name | Should -Be 'test'
        $schedule.StartTime | Should -Be $null
        $schedule.EndTime | Should -Be $end
        $schedule.Script | Should -Not -Be $null
        $schedule.Script.ToString() | Should -Be ({ Write-Host 'hello' }).ToString()
        $schedule.Crons.Length | Should -Be 1
    }

    It 'Adds new schedule with no end time' {
        $PodeContext = @{ 'Schedules' = @{ Items = @{} }; }
        $start = ([DateTime]::Now.AddHours(3))

        Add-PodeSchedule -Name 'test' -Cron '@hourly' -ScriptBlock { Write-Host 'hello' } -StartTime $start

        $schedule = $PodeContext.Schedules.Items['test']
        $schedule | Should -Not -Be $null
        $schedule.Name | Should -Be 'test'
        $schedule.StartTime | Should -Be $start
        $schedule.EndTime | Should -Be $null
        $schedule.Script | Should -Not -Be $null
        $schedule.Script.ToString() | Should -Be ({ Write-Host 'hello' }).ToString()
        $schedule.Crons.Length | Should -Be 1
    }

    It 'Adds new schedule with just a cron' {
        $PodeContext = @{ 'Schedules' = @{ Items = @{} }; }

        Add-PodeSchedule -Name 'test' -Cron '@hourly' -ScriptBlock { Write-Host 'hello' }

        $schedule = $PodeContext.Schedules.Items['test']
        $schedule | Should -Not -Be $null
        $schedule.Name | Should -Be 'test'
        $schedule.StartTime | Should -Be $null
        $schedule.EndTime | Should -Be $null
        $schedule.Script | Should -Not -Be $null
        $schedule.Script.ToString() | Should -Be ({ Write-Host 'hello' }).ToString()
        $schedule.Crons.Length | Should -Be 1
    }

    It 'Adds new schedule with two crons' {
        $PodeContext = @{ 'Schedules' = @{ Items = @{} }; }
        $start = ([DateTime]::Now.AddHours(3))
        $end = ([DateTime]::Now.AddHours(5))

        Add-PodeSchedule -Name 'test' -Cron @('@minutely', '@hourly') -ScriptBlock { Write-Host 'hello' } -StartTime $start -EndTime $end

        $schedule = $PodeContext.Schedules.Items['test']
        $schedule | Should -Not -Be $null
        $schedule.Name | Should -Be 'test'
        $schedule.StartTime | Should -Be $start
        $schedule.EndTime | Should -Be $end
        $schedule.Script | Should -Not -Be $null
        $schedule.Script.ToString() | Should -Be ({ Write-Host 'hello' }).ToString()
        $schedule.Crons.Length | Should -Be 2
    }
}

Describe 'Get-PodeSchedule' {
    It 'Returns no schedules' {
        $PodeContext = @{ Schedules = @{ Items = @{} } }
        $schedules = Get-PodeSchedule
        $schedules.Length | Should -Be 0
    }

    It 'Returns 1 schedule by name' {
        $PodeContext = @{ Schedules = @{ Items = @{} } }
        $start = ([DateTime]::Now.AddHours(3))
        $end = ([DateTime]::Now.AddHours(5))

        Add-PodeSchedule -Name 'test1' -Cron '@hourly' -ScriptBlock { Write-Host 'hello' } -StartTime $start -EndTime $end
        $schedules = Get-PodeSchedule
        $schedules.Length | Should -Be 1

        $schedules.Name | Should -Be 'test1'
        $schedules.StartTime | Should -Be $start
        $schedules.EndTime | Should -Be $end
        $schedules.Limit | Should -Be 0
    }

    It 'Returns 1 schedule by start time' {
        $PodeContext = @{ Schedules = @{ Items = @{} } }
        $start = ([DateTime]::Now.AddHours(3))
        $end = ([DateTime]::Now.AddHours(5))

        Add-PodeSchedule -Name 'test1' -Cron '@hourly' -ScriptBlock { Write-Host 'hello' } -StartTime $start -EndTime $end
        $schedules = Get-PodeSchedule -StartTime $start.AddHours(1)
        $schedules.Length | Should -Be 1

        $schedules.Name | Should -Be 'test1'
        $schedules.StartTime | Should -Be $start
        $schedules.EndTime | Should -Be $end
        $schedules.Limit | Should -Be 0
    }

    It 'Returns 1 schedule by end time' {
        $PodeContext = @{ Schedules = @{ Items = @{} } }
        $start = ([DateTime]::Now.AddHours(3))
        $end = ([DateTime]::Now.AddHours(5))

        Add-PodeSchedule -Name 'test1' -Cron '@hourly' -ScriptBlock { Write-Host 'hello' } -StartTime $start -EndTime $end
        $schedules = Get-PodeSchedule -EndTime $end
        $schedules.Length | Should -Be 1

        $schedules.Name | Should -Be 'test1'
        $schedules.StartTime | Should -Be $start
        $schedules.EndTime | Should -Be $end
        $schedules.Limit | Should -Be 0
    }

    It 'Returns 1 schedule by both start and end time' {
        $PodeContext = @{ Schedules = @{ Items = @{} } }
        $start = ([DateTime]::Now.AddHours(3))
        $end = ([DateTime]::Now.AddHours(5))

        Add-PodeSchedule -Name 'test1' -Cron '@hourly' -ScriptBlock { Write-Host 'hello' } -StartTime $start -EndTime $end
        $schedules = Get-PodeSchedule -StartTime $start.AddHours(1) -EndTime $end
        $schedules.Length | Should -Be 1

        $schedules.Name | Should -Be 'test1'
        $schedules.StartTime | Should -Be $start
        $schedules.EndTime | Should -Be $end
        $schedules.Limit | Should -Be 0
    }

    It 'Returns no schedules by end time before start' {
        $PodeContext = @{ Schedules = @{ Items = @{} } }
        $start = ([DateTime]::Now.AddHours(3))
        $end = ([DateTime]::Now.AddHours(5))

        Add-PodeSchedule -Name 'test1' -Cron '@hourly' -ScriptBlock { Write-Host 'hello' } -StartTime $start -EndTime $end
        $schedules = Get-PodeSchedule -EndTime $start.AddHours(-1)
        $schedules.Length | Should -Be 0
    }

    It 'Returns no schedules by start time after end' {
        $PodeContext = @{ Schedules = @{ Items = @{} } }
        $start = ([DateTime]::Now.AddHours(3))
        $end = ([DateTime]::Now.AddHours(5))

        Add-PodeSchedule -Name 'test1' -Cron '@hourly' -ScriptBlock { Write-Host 'hello' } -StartTime $start -EndTime $end
        $schedules = Get-PodeSchedule -StartTime $end.AddHours(1)
        $schedules.Length | Should -Be 0
    }

    It 'Returns 2 schedules by name' {
        $PodeContext = @{ Schedules = @{ Items = @{} } }
        $start = ([DateTime]::Now.AddHours(3))
        $end = ([DateTime]::Now.AddHours(5))

        Add-PodeSchedule -Name 'test1' -Cron '@hourly' -ScriptBlock { Write-Host 'hello' } -StartTime $start -EndTime $end
        Add-PodeSchedule -Name 'test2' -Cron '@hourly' -ScriptBlock { Write-Host 'hello' } -StartTime $start -EndTime $end
        Add-PodeSchedule -Name 'test3' -Cron '@hourly' -ScriptBlock { Write-Host 'hello' } -StartTime $start -EndTime $end

        $schedules = Get-PodeSchedule -Name test1, test2
        $schedules.Length | Should -Be 2
    }

    It 'Returns all schedules' {
        $PodeContext = @{ Schedules = @{ Items = @{} } }
        $start = ([DateTime]::Now.AddHours(3))
        $end = ([DateTime]::Now.AddHours(5))

        Add-PodeSchedule -Name 'test1' -Cron '@hourly' -ScriptBlock { Write-Host 'hello' } -StartTime $start -EndTime $end
        Add-PodeSchedule -Name 'test2' -Cron '@hourly' -ScriptBlock { Write-Host 'hello' } -StartTime $start -EndTime $end
        Add-PodeSchedule -Name 'test3' -Cron '@hourly' -ScriptBlock { Write-Host 'hello' } -StartTime $start -EndTime $end

        $schedules = Get-PodeSchedule
        $schedules.Length | Should -Be 3
    }
}

Describe 'Get-PodeScheduleNextTrigger' {
    It 'Returns next trigger time' {
        $PodeContext = @{ Schedules = @{ Items = @{} } }
        $start = ([DateTime]::Now.AddHours(3))
        $end = ([DateTime]::Now.AddHours(5))

        Add-PodeSchedule -Name 'test1' -Cron '@hourly' -ScriptBlock { Write-Host 'hello' } -StartTime $start -EndTime $end
        $trigger = Get-PodeScheduleNextTrigger -Name 'test1'

        $expected = $start.AddHours(1)
        $expected = [datetime]::new($expected.Year, $expected.Month, $expected.Day, $expected.Hour, 0, 0)
        $trigger | Should -Be $expected
    }

    It 'Returns next trigger time from date' {
        $PodeContext = @{ Schedules = @{ Items = @{} } }
        $start = ([DateTime]::Now.AddHours(3))
        $end = ([DateTime]::Now.AddHours(5))

        Add-PodeSchedule -Name 'test1' -Cron '@hourly' -ScriptBlock { Write-Host 'hello' } -StartTime $start -EndTime $end
        $trigger = Get-PodeScheduleNextTrigger -Name 'test1' -DateTime $start.AddHours(1)

        $expected = $start.AddHours(2)
        $expected = [datetime]::new($expected.Year, $expected.Month, $expected.Day, $expected.Hour, 0, 0)
        $trigger | Should -Be $expected
    }
}

Describe 'Remove-PodeSchedule' {
    It 'Adds new schedule and then removes it' {
        $PodeContext = @{ 'Schedules' = @{ Items = @{} }; }

        Add-PodeSchedule -Name 'test' -Cron '@hourly' -ScriptBlock { Write-Host 'hello' }

        $PodeContext.Schedules.Items['test'] | Should -Not -Be $null

        Remove-PodeSchedule -Name 'test'

        $PodeContext.Schedules.Items['test'] | Should -Be $null
    }
}


Describe 'Clear-PodeSchedules' {
    It 'Adds new schedules and then removes them' {
        $PodeContext = @{ 'Schedules' = @{ Items = @{} }; }

        Add-PodeSchedule -Name 'test1' -Cron '@hourly' -ScriptBlock { Write-Host 'hello1' }
        Add-PodeSchedule -Name 'test2' -Cron '@hourly' -ScriptBlock { Write-Host 'hello2' }

        $PodeContext.Schedules.Items['test1'] | Should -Not -Be $null
        $PodeContext.Schedules.Items['test2'] | Should -Not -Be $null

        Clear-PodeSchedules

        $PodeContext.Schedules.Items.Count | Should -Be 0
    }
}

Describe 'Edit-PodeSchedule' {
    It 'Adds a new schedule, then edits the cron' {
        $PodeContext = @{ 'Schedules' = @{ Items = @{} }; }
        Add-PodeSchedule -Name 'test1' -Cron '@hourly' -ScriptBlock { Write-Host 'hello1' }
        $PodeContext.Schedules.Items['test1'].Crons.Length | Should -Be 1
        $PodeContext.Schedules.Items['test1'].Script.ToString() | Should -Be ({ Write-Host 'hello1' }).ToString()

        Edit-PodeSchedule -Name 'test1' -Cron @('@minutely', '@hourly')
        $PodeContext.Schedules.Items['test1'].Crons.Length | Should -Be 2
        $PodeContext.Schedules.Items['test1'].Script.ToString() | Should -Be ({ Write-Host 'hello1' }).ToString()
    }

    It 'Adds a new schedule, then edits the script' {
        $PodeContext = @{ 'Schedules' = @{ Items = @{} }; }
        Add-PodeSchedule -Name 'test1' -Cron '@hourly' -ScriptBlock { Write-Host 'hello1' }
        $PodeContext.Schedules.Items['test1'].Crons.Length | Should -Be 1
        $PodeContext.Schedules.Items['test1'].Script.ToString() | Should -Be ({ Write-Host 'hello1' }).ToString()

        Edit-PodeSchedule -Name 'test1' -ScriptBlock { Write-Host 'hello2' }
        $PodeContext.Schedules.Items['test1'].Crons.Length | Should -Be 1
        $PodeContext.Schedules.Items['test1'].Script.ToString() | Should -Be ({ Write-Host 'hello2' }).ToString()
    }
}