[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
param()
BeforeAll {
    $path = $PSCommandPath
    $src = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]unit', '/src/'
    Get-ChildItem "$($src)/*.ps1" -Recurse | Resolve-Path | ForEach-Object { . $_ }
    Import-LocalizedData -BindingVariable PodeLocale -BaseDirectory (Join-Path -Path $src -ChildPath 'Locales') -FileName 'Pode'
}

Describe 'Get-PodeCronField' {
    It 'Returns valid cron fields' {
        Get-PodeCronField | Should -Be @(
            'Minute',
            'Hour',
            'DayOfMonth',
            'Month',
            'DayOfWeek'
        )
    }
}

Describe 'Get-PodeCronFieldConstraint' {
    It 'Returns valid cron field constraints' {
        $constraints = Get-PodeCronFieldConstraint
        $constraints | Should -Not -Be $null

        $constraints.MinMax | Should -Be @(
            @(0, 59),
            @(0, 23),
            @(1, 31),
            @(1, 12),
            @(0, 6)
        )

        $constraints.DaysInMonths | Should -Be @(
            31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31
        )

        $constraints.Months | Should -Be @(
            'January', 'February', 'March', 'April', 'May', 'June', 'July',
            'August', 'September', 'October', 'November', 'December'
        )
    }
}

Describe 'Get-PodeCronPredefined' {
    It 'Returns valid predefined values' {
        $values = Get-PodeCronPredefined
        $values | Should -Not -Be $null

        $values['@minutely'] | Should -Be '* * * * *'
        $values['@hourly'] | Should -Be '0 * * * *'
        $values['@daily'] | Should -Be '0 0 * * *'
        $values['@weekly'] | Should -Be '0 0 * * 0'
        $values['@monthly'] | Should -Be '0 0 1 * *'
        $values['@quarterly'] | Should -Be '0 0 1 1,4,7,10 *'
        $values['@yearly'] | Should -Be '0 0 1 1 *'
        $values['@annually'] | Should -Be '0 0 1 1 *'
        $values['@twice-hourly'] | Should -Be '0,30 * * * *'
        $values['@twice-daily'] | Should -Be '0 0,12 * * *'
        $values['@twice-weekly'] | Should -Be '0 0 * * 0,4'
        $values['@twice-monthly'] | Should -Be '0 0 1,15 * *'
        $values['@twice-yearly'] | Should -Be '0 0 1 1,6 *'
        $values['@twice-annually'] | Should -Be '0 0 1 1,6 *'
    }
}

Describe 'Get-PodeCronFieldAlias' {
    It 'Returns valid aliases' {
        $aliases = Get-PodeCronFieldAlias
        $aliases | Should -Not -Be $null

        $aliases.Month.Jan | Should -Be 1
        $aliases.Month.Feb | Should -Be 2
        $aliases.Month.Mar | Should -Be 3
        $aliases.Month.Apr | Should -Be 4
        $aliases.Month.May | Should -Be 5
        $aliases.Month.Jun | Should -Be 6
        $aliases.Month.Jul | Should -Be 7
        $aliases.Month.Aug | Should -Be 8
        $aliases.Month.Sep | Should -Be 9
        $aliases.Month.Oct | Should -Be 10
        $aliases.Month.Nov | Should -Be 11
        $aliases.Month.Dec | Should -Be 12

        $aliases.DayOfWeek.Sun | Should -Be 0
        $aliases.DayOfWeek.Mon | Should -Be 1
        $aliases.DayOfWeek.Tue | Should -Be 2
        $aliases.DayOfWeek.Wed | Should -Be 3
        $aliases.DayOfWeek.Thu | Should -Be 4
        $aliases.DayOfWeek.Fri | Should -Be 5
        $aliases.DayOfWeek.Sat | Should -Be 6
    }
}

Describe 'ConvertFrom-PodeCronExpression' {
    Context 'Invalid parameters supplied' {
        It 'Throw null expression parameter error' {
            { ConvertFrom-PodeCronExpression -Expression $null } | Should -Throw -ErrorId 'ParameterArgumentValidationError,ConvertFrom-PodeCronExpression'
        }

        It 'Throw empty expression parameter error' {
            { ConvertFrom-PodeCronExpression -Expression ([string]::Empty) } | Should -Throw -ErrorId 'ParameterArgumentValidationError,ConvertFrom-PodeCronExpression'
        }
    }

    Context 'Valid schedule parameters' {
        It 'Throws error for too few number of cron atoms' {
            { ConvertFrom-PodeCronExpression -Expression '* * *' } | Should -Throw -ExpectedMessage ($PodeLocale.cronExpressionInvalidExceptionMessage -f '* * *') #'*Cron expression should only consist of 5 parts*'
        }

        It 'Throws error for too many number of cron atoms' {
            { ConvertFrom-PodeCronExpression -Expression '* * * * * *' } | Should -Throw -ExpectedMessage ($PodeLocale.cronExpressionInvalidExceptionMessage -f '* * * * * *') #'*Cron expression should only consist of 5 parts*'
        }

        It 'Throws error for range atom with min>max' {
            { ConvertFrom-PodeCronExpression -Expression '* * 20-15 * *' } | Should -Throw -ExpectedMessage ($PodeLocale.minValueGreaterThanMaxExceptionMessage -f 'DayOfMonth') #'*should not be greater than the max value*'
        }

        It 'Throws error for range atom with invalid min' {
            { ConvertFrom-PodeCronExpression -Expression '* * 0-5 * *' } | Should -Throw -ExpectedMessage ($PodeLocale.minValueInvalidExceptionMessage -f 0,'DayOfMonth',1) # '*is invalid, should be greater than/equal to*'
        }

        It 'Throws error for range atom with invalid max' {
            { ConvertFrom-PodeCronExpression -Expression '* * 1-32 * *' } | Should -Throw -ExpectedMessage ($PodeLocale.maxValueInvalidExceptionMessage -f 32,'DayOfMonth',31) #'*is invalid, should be less than/equal to*'
        }

        It 'Throws error for atom with invalid min' {
            { ConvertFrom-PodeCronExpression -Expression '* * 0 * *' } | Should -Throw -ExpectedMessage ($PodeLocale.valueOutOfRangeExceptionMessage -f '','DayOfMonth',1,31) # '*invalid, should be between*'
        }

        It 'Throws error for atom with invalid max' {
            { ConvertFrom-PodeCronExpression -Expression '* * 32 * *' } | Should -Throw -ExpectedMessage ($PodeLocale.valueOutOfRangeExceptionMessage -f '','DayOfMonth',1,31)#'*invalid, should be between*'
        }


        It 'Returns a valid cron object for predefined' {
            $cron = ConvertFrom-PodeCronExpression -Expression '@minutely'

            $cron.Month.Values | Should -Be $null
            $cron.Month.Range.Min | Should -Be 1
            $cron.Month.Range.Max | Should -Be 12
            $cron.Month.Constraints[0] | Should -Be 1
            $cron.Month.Constraints[1] | Should -Be 12
            $cron.Month.Random | Should -Be $false

            $cron.DayOfWeek.Values | Should -Be $null
            $cron.DayOfWeek.Range.Min | Should -Be 0
            $cron.DayOfWeek.Range.Max | Should -Be 6
            $cron.DayOfWeek.Constraints[0] | Should -Be 0
            $cron.DayOfWeek.Constraints[1] | Should -Be 6
            $cron.DayOfWeek.Random | Should -Be $false

            $cron.Minute.Values | Should -Be $null
            $cron.Minute.Range.Min | Should -Be 0
            $cron.Minute.Range.Max | Should -Be 59
            $cron.Minute.Constraints[0] | Should -Be 0
            $cron.Minute.Constraints[1] | Should -Be 59
            $cron.Minute.Random | Should -Be $false

            $cron.Hour.Values | Should -Be $null
            $cron.Hour.Range.Min | Should -Be 0
            $cron.Hour.Range.Max | Should -Be 23
            $cron.Hour.Constraints[0] | Should -Be 0
            $cron.Hour.Constraints[1] | Should -Be 23
            $cron.Hour.Random | Should -Be $false

            $cron.Random | Should -Be $false

            $cron.DayOfMonth.Values | Should -Be $null
            $cron.DayOfMonth.Range.Min | Should -Be 1
            $cron.DayOfMonth.Range.Max | Should -Be 31
            $cron.DayOfMonth.Constraints[0] | Should -Be 1
            $cron.DayOfMonth.Constraints[1] | Should -Be 31
            $cron.DayOfMonth.Random | Should -Be $false
        }

        It 'Returns a valid cron object for expression' {
            $cron = ConvertFrom-PodeCronExpression -Expression '0/10 * * * 2'

            $cron.Month.Values | Should -Be $null
            $cron.Month.Range.Min | Should -Be 1
            $cron.Month.Range.Max | Should -Be 12
            $cron.Month.Constraints[0] | Should -Be 1
            $cron.Month.Constraints[1] | Should -Be 12
            $cron.Month.Random | Should -Be $false

            $cron.DayOfWeek.Values | Should -Be 2
            $cron.DayOfWeek.Range.Min | Should -Be $null
            $cron.DayOfWeek.Range.Max | Should -Be $null
            $cron.DayOfWeek.Constraints[0] | Should -Be 0
            $cron.DayOfWeek.Constraints[1] | Should -Be 6
            $cron.DayOfWeek.Random | Should -Be $false

            $cron.Minute.Values | Should -Be @(0, 10, 20, 30, 40, 50)
            $cron.Minute.Range.Min | Should -Be $null
            $cron.Minute.Range.Max | Should -Be $null
            $cron.Minute.Constraints[0] | Should -Be 0
            $cron.Minute.Constraints[1] | Should -Be 59
            $cron.Minute.Random | Should -Be $false

            $cron.Hour.Values | Should -Be $null
            $cron.Hour.Range.Min | Should -Be 0
            $cron.Hour.Range.Max | Should -Be 23
            $cron.Hour.Constraints[0] | Should -Be 0
            $cron.Hour.Constraints[1] | Should -Be 23
            $cron.Hour.Random | Should -Be $false

            $cron.Random | Should -Be $false

            $cron.DayOfMonth.Values | Should -Be $null
            $cron.DayOfMonth.Range.Min | Should -Be 1
            $cron.DayOfMonth.Range.Max | Should -Be 31
            $cron.DayOfMonth.Constraints[0] | Should -Be 1
            $cron.DayOfMonth.Constraints[1] | Should -Be 31
            $cron.DayOfMonth.Random | Should -Be $false
        }

        It 'Returns a valid cron object for expression using wildcard' {
            $cron = ConvertFrom-PodeCronExpression -Expression '*/10 * * * 2'

            $cron.Month.Values | Should -Be $null
            $cron.Month.Range.Min | Should -Be 1
            $cron.Month.Range.Max | Should -Be 12
            $cron.Month.Constraints[0] | Should -Be 1
            $cron.Month.Constraints[1] | Should -Be 12
            $cron.Month.Random | Should -Be $false

            $cron.DayOfWeek.Values | Should -Be 2
            $cron.DayOfWeek.Range.Min | Should -Be $null
            $cron.DayOfWeek.Range.Max | Should -Be $null
            $cron.DayOfWeek.Constraints[0] | Should -Be 0
            $cron.DayOfWeek.Constraints[1] | Should -Be 6
            $cron.DayOfWeek.Random | Should -Be $false

            $cron.Minute.Values | Should -Be @(0, 10, 20, 30, 40, 50)
            $cron.Minute.Range.Min | Should -Be $null
            $cron.Minute.Range.Max | Should -Be $null
            $cron.Minute.Constraints[0] | Should -Be 0
            $cron.Minute.Constraints[1] | Should -Be 59
            $cron.Minute.Random | Should -Be $false

            $cron.Hour.Values | Should -Be $null
            $cron.Hour.Range.Min | Should -Be 0
            $cron.Hour.Range.Max | Should -Be 23
            $cron.Hour.Constraints[0] | Should -Be 0
            $cron.Hour.Constraints[1] | Should -Be 23
            $cron.Hour.Random | Should -Be $false

            $cron.Random | Should -Be $false

            $cron.DayOfMonth.Values | Should -Be $null
            $cron.DayOfMonth.Range.Min | Should -Be 1
            $cron.DayOfMonth.Range.Max | Should -Be 31
            $cron.DayOfMonth.Constraints[0] | Should -Be 1
            $cron.DayOfMonth.Constraints[1] | Should -Be 31
            $cron.DayOfMonth.Random | Should -Be $false
        }
    }
}

Describe 'Test-PodeCronExpression' {

    BeforeAll {
        $inputDate = [datetime]::parseexact('2019-02-05 14:30', 'yyyy-MM-dd HH:mm', $null)
    }
    Context 'Passing test with fix cron' {

        It 'Returns true for a Tuesdays' {
            $cron = ConvertFrom-PodeCronExpression -Expression '* * * * 2'

            Test-PodeCronExpression -Expression $cron -DateTime $inputDate | Should -Be $true
        }

        It 'Returns true for Feb' {
            $cron = ConvertFrom-PodeCronExpression -Expression '* * * 2 *'

            Test-PodeCronExpression -Expression $cron -DateTime $inputDate | Should -Be $true
        }

        It 'Returns true for 5th day of month' {
            $cron = ConvertFrom-PodeCronExpression -Expression '* * 5 * *'

            Test-PodeCronExpression -Expression $cron -DateTime $inputDate | Should -Be $true
        }

        It 'Returns true for 5th day of Feb' {
            $cron = ConvertFrom-PodeCronExpression -Expression '* * 5 2 *'

            Test-PodeCronExpression -Expression $cron -DateTime $inputDate | Should -Be $true
        }

        It 'Returns true for 14th hour' {
            $cron = ConvertFrom-PodeCronExpression -Expression '* 14 * * *'

            Test-PodeCronExpression -Expression $cron -DateTime $inputDate | Should -Be $true
        }

        It 'Returns true for 30th minute' {
            $cron = ConvertFrom-PodeCronExpression -Expression '30 * * * *'

            Test-PodeCronExpression -Expression $cron -DateTime $inputDate | Should -Be $true
        }

        It 'Returns true for all values set' {
            $cron = ConvertFrom-PodeCronExpression -Expression '30 14 5 2 2'

            Test-PodeCronExpression -Expression $cron -DateTime $inputDate | Should -Be $true
        }
    }

    Context 'Failing test with fix cron' {

        It 'Returns false for Jan' {
            $cron = ConvertFrom-PodeCronExpression -Expression '* * * 1 *'

            Test-PodeCronExpression -Expression $cron -DateTime $inputDate | Should -Be $false
        }

        It 'Returns false for 4th day of Jan' {
            $cron = ConvertFrom-PodeCronExpression -Expression '* * 4 1 *'

            Test-PodeCronExpression -Expression $cron -DateTime $inputDate | Should -Be $false
        }

        It 'Returns false for 13th hour' {
            $cron = ConvertFrom-PodeCronExpression -Expression '* 13 * * *'

            Test-PodeCronExpression -Expression $cron -DateTime $inputDate | Should -Be $false
        }

        It 'Returns false for 20th minute' {
            $cron = ConvertFrom-PodeCronExpression -Expression '20 * * * *'

            Test-PodeCronExpression -Expression $cron -DateTime $inputDate | Should -Be $false
        }

        It 'Returns false for all values set' {
            $cron = ConvertFrom-PodeCronExpression -Expression '20 13 4 1 3'

            Test-PodeCronExpression -Expression $cron -DateTime $inputDate | Should -Be $false
        }
    }

    Context 'Passing test with set of values cron' {
        It 'Returns true for a Mondays and Tuesdays' {
            $cron = ConvertFrom-PodeCronExpression -Expression '* * * * 1,2'

            Test-PodeCronExpression -Expression $cron -DateTime $inputDate | Should -Be $true
        }

        It 'Returns true for Feb and Mar' {
            $cron = ConvertFrom-PodeCronExpression -Expression '* * * 2,3 *'

            Test-PodeCronExpression -Expression $cron -DateTime $inputDate | Should -Be $true
        }

        It 'Returns true for 5th day of month and the 7th' {
            $cron = ConvertFrom-PodeCronExpression -Expression '* * 5,7 * *'

            Test-PodeCronExpression -Expression $cron -DateTime $inputDate | Should -Be $true
        }

        It 'Returns true for 5th day of Feb and the 7th day of Mar' {
            $cron = ConvertFrom-PodeCronExpression -Expression '* * 5,7 2,3 *'

            Test-PodeCronExpression -Expression $cron -DateTime $inputDate | Should -Be $true
        }

        It 'Returns true for 14th hour and the 16th hour' {
            $cron = ConvertFrom-PodeCronExpression -Expression '* 14,16 * * *'

            Test-PodeCronExpression -Expression $cron -DateTime $inputDate | Should -Be $true
        }

        It 'Returns true for 30th minute and the 40th' {
            $cron = ConvertFrom-PodeCronExpression -Expression '30,40 * * * *'

            Test-PodeCronExpression -Expression $cron -DateTime $inputDate | Should -Be $true
        }

        It 'Returns true for all values set' {
            $cron = ConvertFrom-PodeCronExpression -Expression '30,40 14,16 5,7 2,3 1,2'

            Test-PodeCronExpression -Expression $cron -DateTime $inputDate | Should -Be $true
        }
    }

    Context 'Failing test with set of values cron' {
        It 'Returns false for Jan and Mar' {
            $cron = ConvertFrom-PodeCronExpression -Expression '* * * 1,3 *'

            Test-PodeCronExpression -Expression $cron -DateTime $inputDate | Should -Be $false
        }

        It 'Returns false for 4th day of Jan and 5th day of Mar' {
            $cron = ConvertFrom-PodeCronExpression -Expression '* * 4,5 1,3 *'

            Test-PodeCronExpression -Expression $cron -DateTime $inputDate | Should -Be $false
        }

        It 'Returns false for 13th hour and 15th' {
            $cron = ConvertFrom-PodeCronExpression -Expression '* 13,15 * * *'

            Test-PodeCronExpression -Expression $cron -DateTime $inputDate | Should -Be $false
        }

        It 'Returns false for 20th minute and 29th' {
            $cron = ConvertFrom-PodeCronExpression -Expression '20,29 * * * *'

            Test-PodeCronExpression -Expression $cron -DateTime $inputDate | Should -Be $false
        }

        It 'Returns false for all values set' {
            $cron = ConvertFrom-PodeCronExpression -Expression '20,29 13,15 4,5 1,3 3,4'

            Test-PodeCronExpression -Expression $cron -DateTime $inputDate | Should -Be $false
        }
    }

    Context 'Passing test with range cron' {
        It 'Returns true for a Mondays to Tuesdays' {
            $cron = ConvertFrom-PodeCronExpression -Expression '* * * * 1-2'

            Test-PodeCronExpression -Expression $cron -DateTime $inputDate | Should -Be $true
        }

        It 'Returns true for Feb to Mar' {
            $cron = ConvertFrom-PodeCronExpression -Expression '* * * 2-3 *'

            Test-PodeCronExpression -Expression $cron -DateTime $inputDate | Should -Be $true
        }

        It 'Returns true for 5th day of month to the 7th' {
            $cron = ConvertFrom-PodeCronExpression -Expression '* * 5-7 * *'

            Test-PodeCronExpression -Expression $cron -DateTime $inputDate | Should -Be $true
        }

        It 'Returns true for 5th day of Feb to the 7th day of Mar' {
            $cron = ConvertFrom-PodeCronExpression -Expression '* * 5-7 2-3 *'

            Test-PodeCronExpression -Expression $cron -DateTime $inputDate | Should -Be $true
        }

        It 'Returns true for 14th hour to the 16th hour' {
            $cron = ConvertFrom-PodeCronExpression -Expression '* 14-16 * * *'

            Test-PodeCronExpression -Expression $cron -DateTime $inputDate | Should -Be $true
        }

        It 'Returns true for 30th minute to the 40th' {
            $cron = ConvertFrom-PodeCronExpression -Expression '30-40 * * * *'

            Test-PodeCronExpression -Expression $cron -DateTime $inputDate | Should -Be $true
        }

        It 'Returns true for all values set' {
            $cron = ConvertFrom-PodeCronExpression -Expression '30-40 14-16 5-7 2-3 1-2'

            Test-PodeCronExpression -Expression $cron -DateTime $inputDate | Should -Be $true
        }
    }

    Context 'Failing test with range cron' {
        It 'Returns false for Mar to Dec' {
            $cron = ConvertFrom-PodeCronExpression -Expression '* * * 3-12 *'

            Test-PodeCronExpression -Expression $cron -DateTime $inputDate | Should -Be $false
        }

        It 'Returns false for 3rd day of Mar to 4th day of Dec' {
            $cron = ConvertFrom-PodeCronExpression -Expression '* * 3-4 3-12 *'

            Test-PodeCronExpression -Expression $cron -DateTime $inputDate | Should -Be $false
        }

        It 'Returns false for 13th hour to 23rd' {
            $cron = ConvertFrom-PodeCronExpression -Expression '* 15-23 * * *'

            Test-PodeCronExpression -Expression $cron -DateTime $inputDate | Should -Be $false
        }

        It 'Returns false for 20th minute to 29th' {
            $cron = ConvertFrom-PodeCronExpression -Expression '20-29 * * * *'

            Test-PodeCronExpression -Expression $cron -DateTime $inputDate | Should -Be $false
        }

        It 'Returns false for all values set' {
            $cron = ConvertFrom-PodeCronExpression -Expression '20-29 15-23 3-4 3-12 3-4'

            Test-PodeCronExpression -Expression $cron -DateTime $inputDate | Should -Be $false
        }
    }
}

Describe 'Get-PodeCronNextTrigger' {
    Describe 'InputDate 2020-01-01' {
        BeforeEach {
            $inputDate = [datetime]::new(2020, 1, 1)
        }
        It 'Returns the next minute' {
            $exp = '* * * * *'
            $cron = ConvertFrom-PodeCronExpression -Expression $exp
            Get-PodeCronNextTrigger -Expression $cron -StartTime $inputDate | Should -Be ([datetime]::new(2020, 1, 1, 0, 1, 0))
        }

        It 'Returns the next hour' {
            $exp = '0 * * * *'
            $cron = ConvertFrom-PodeCronExpression -Expression $exp
            Get-PodeCronNextTrigger -Expression $cron -StartTime $inputDate | Should -Be ([datetime]::new(2020, 1, 1, 1, 0, 0))
        }

        It 'Returns the next day' {
            $exp = '0 0 * * *'
            $cron = ConvertFrom-PodeCronExpression -Expression $exp
            Get-PodeCronNextTrigger -Expression $cron -StartTime $inputDate | Should -Be ([datetime]::new(2020, 1, 2, 0, 0, 0))
        }

        It 'Returns the next month' {
            $exp = '0 0 1 * *'
            $cron = ConvertFrom-PodeCronExpression -Expression $exp
            Get-PodeCronNextTrigger -Expression $cron -StartTime $inputDate | Should -Be ([datetime]::new(2020, 2, 1, 0, 0, 0))
        }

        It 'Returns the next year' {
            $exp = '0 0 1 1 *'
            $cron = ConvertFrom-PodeCronExpression -Expression $exp
            Get-PodeCronNextTrigger -Expression $cron -StartTime $inputDate | Should -Be ([datetime]::new(2021, 1, 1, 0, 0, 0))
        }

        It 'Returns the friday 3rd' {
            $exp = '0 0 * 1 FRI'
            $cron = ConvertFrom-PodeCronExpression -Expression $exp
            Get-PodeCronNextTrigger -Expression $cron -StartTime $inputDate | Should -Be ([datetime]::new(2020, 1, 3, 0, 0, 0))
        }

        It 'Returns the 2023 friday' {
            $exp = '0 0 13 1 FRI'
            $cron = ConvertFrom-PodeCronExpression -Expression $exp
            Get-PodeCronNextTrigger -Expression $cron -StartTime $inputDate | Should -Be ([datetime]::new(2023, 1, 13, 0, 0, 0))
        }

        It 'Returns the null for after end time' {
            $exp = '0 0 20 1 FRI'
            $end = [datetime]::new(2020, 1, 19)
            $cron = ConvertFrom-PodeCronExpression -Expression $exp
            Get-PodeCronNextTrigger -Expression $cron -StartTime $inputDate -EndTime $end | Should -Be $null
        }
    }

    Describe 'InputDate 2020-01-15 02:30:00' {
        BeforeEach {
            $inputDate = [datetime]::new(2020, 1, 15, 2, 30, 0)
        }
        It 'Returns the minute but next hour' {
            $exp = '20 * * * *'
            $cron = ConvertFrom-PodeCronExpression -Expression $exp
            Get-PodeCronNextTrigger -Expression $cron -StartTime $inputDate | Should -Be ([datetime]::new(2020, 1, 15, 3, 20, 0))
        }

        It 'Returns the later minute but same hour' {
            $exp = '20,40 * * * *'
            $cron = ConvertFrom-PodeCronExpression -Expression $exp
            Get-PodeCronNextTrigger -Expression $cron -StartTime $inputDate | Should -Be ([datetime]::new(2020, 1, 15, 2, 40, 0))
        }

        It 'Returns the next minute but same hour' {
            $exp = '20-40 * * * *'
            $cron = ConvertFrom-PodeCronExpression -Expression $exp
            Get-PodeCronNextTrigger -Expression $cron -StartTime $inputDate | Should -Be ([datetime]::new(2020, 1, 15, 2, 31, 0))
        }

        It 'Returns the a very specific date' {
            $exp = '37 13 5 2 FRI'
            $cron = ConvertFrom-PodeCronExpression -Expression $exp
            Get-PodeCronNextTrigger -Expression $cron -StartTime $inputDate | Should -Be ([datetime]::new(2021, 2, 5, 13, 37, 0))
        }

        It 'Returns the 30 March' {
            $inputDate = [datetime]::new(2020, 1, 31, 0, 0, 0)
            $cron = ConvertFrom-PodeCronExpression -Expression '* * 30 * *'
            Get-PodeCronNextTrigger -Expression $cron -StartTime $inputDate | Should -Be ([datetime]::new(2020, 3, 30, 0, 0, 0))
        }

        It 'Returns the 28 Feb' {
            $inputDate = [datetime]::new(2020, 1, 31, 0, 0, 0)
            $cron = ConvertFrom-PodeCronExpression -Expression '* * 28 * *'
            Get-PodeCronNextTrigger -Expression $cron -StartTime $inputDate | Should -Be ([datetime]::new(2020, 2, 28, 0, 0, 0))
        }
    }
}

Describe 'Get-PodeCronNextEarliestTrigger' {
    BeforeEach {
        $inputDate = [datetime]::new(2020, 1, 1)
    }

    It 'Returns the earliest trigger when both valid' {
        $crons = ConvertFrom-PodeCronExpression -Expression '* * 11 * FRI', '* * 10 * WED'
        Get-PodeCronNextEarliestTrigger -Expressions $crons -StartTime $inputDate | Should -Be ([datetime]::new(2020, 6, 10, 0, 0, 0))
    }

    It 'Returns the earliest trigger when one after end time' {
        $end = [datetime]::new(2020, 1, 9)
        $crons = ConvertFrom-PodeCronExpression -Expression '* * 8 * WED', '* * 10 * FRi'
        Get-PodeCronNextEarliestTrigger -Expressions $crons -StartTime $inputDate -EndTime $end | Should -Be ([datetime]::new(2020, 1, 8, 0, 0, 0))
    }

    It 'Returns the null when all after end time' {
        $end = [datetime]::new(2020, 1, 7)
        $crons = ConvertFrom-PodeCronExpression -Expression '* * 8 * WED', '* * 10 * FRi'
        Get-PodeCronNextEarliestTrigger -Expressions $crons -StartTime $inputDate -EndTime $end | Should -Be $null
    }
}