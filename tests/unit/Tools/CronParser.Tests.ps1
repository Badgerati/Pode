$path = $MyInvocation.MyCommand.Path
$src = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]unit[\\/]', '/src/'
Get-ChildItem "$($src)/*.ps1" | Resolve-Path | ForEach-Object { . $_ }

Describe 'Get-PodeCronFields' {
    It 'Returns valid cron fields' {
        Get-PodeCronFields | Should Be @(
            'Minute',
            'Hour',
            'DayOfMonth',
            'Month',
            'DayOfWeek'
        )
    }
}

Describe 'Get-PodeCronFieldConstraints' {
    It 'Returns valid cron field constraints' {
        $constraints = Get-PodeCronFieldConstraints
        $constraints | Should Not Be $null

        $constraints.MinMax | Should Be @(
            @(0, 59),
            @(0, 23),
            @(1, 31),
            @(1, 12),
            @(0, 6)
        )

        $constraints.DaysInMonths | Should Be @(
            31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31
        )

        $constraints.Months | Should Be @(
            'January', 'February', 'March', 'April', 'May', 'June', 'July',
            'August', 'September', 'October', 'November', 'December'
        )
    }
}

Describe 'Get-PodeCronPredefined' {
    It 'Returns valid predefined values' {
        $values = Get-PodeCronPredefined
        $values | Should Not Be $null

        $values['@minutely'] | Should Be '* * * * *'
        $values['@hourly'] | Should Be '0 * * * *'
        $values['@daily'] | Should Be '0 0 * * *'
        $values['@weekly'] | Should Be '0 0 * * 0'
        $values['@monthly'] | Should Be '0 0 1 * *'
        $values['@quaterly'] | Should Be '0 0 1 1,4,8,7,10'
        $values['@yearly'] | Should Be '0 0 1 1 *'
        $values['@annually'] | Should Be '0 0 1 1 *'
        $values['@twice-hourly'] | Should Be '0,30 * * * *'
        $values['@twice-daily'] | Should Be '0,12 0 * * *'
        $values['@twice-weekly'] | Should Be '0 0 * * 0,4'
        $values['@twice-monthly'] | Should Be '0 0 1,15 * *'
        $values['@twice-yearly'] | Should Be '0 0 1 1,6 *'
        $values['@twice-annually'] | Should Be '0 0 1 1,6 *'
    }
}

Describe 'Get-PodeCronFieldAliases' {
    It 'Returns valid aliases' {
        $aliases = Get-PodeCronFieldAliases
        $aliases | Should Not Be $null

        $aliases.Month.Jan | Should Be 1
        $aliases.Month.Feb | Should Be 2
        $aliases.Month.Mar | Should Be 3
        $aliases.Month.Apr | Should Be 4
        $aliases.Month.May | Should Be 5
        $aliases.Month.Jun | Should Be 6
        $aliases.Month.Jul | Should Be 7
        $aliases.Month.Aug | Should Be 8
        $aliases.Month.Sep | Should Be 9
        $aliases.Month.Oct | Should Be 10
        $aliases.Month.Nov | Should Be 11
        $aliases.Month.Dec | Should Be 12

        $aliases.DayOfWeek.Sun | Should Be 0
        $aliases.DayOfWeek.Mon | Should Be 1
        $aliases.DayOfWeek.Tue | Should Be 2
        $aliases.DayOfWeek.Wed | Should Be 3
        $aliases.DayOfWeek.Thu | Should Be 4
        $aliases.DayOfWeek.Fri | Should Be 5
        $aliases.DayOfWeek.Sat | Should Be 6
    }
}

Describe 'ConvertFrom-PodeCronExpression' {
    Context 'Invalid parameters supplied' {
        It 'Throw null expression parameter error' {
            { ConvertFrom-PodeCronExpression -Expression $null } | Should Throw 'The argument is null or empty'
        }

        It 'Throw empty expression parameter error' {
            { ConvertFrom-PodeCronExpression -Expression ([string]::Empty) } | Should Throw 'The argument is null or empty'
        }
    }

    Context 'Valid schedule parameters' {
        It 'Throws error for too few number of cron atoms' {
            { ConvertFrom-PodeCronExpression -Expression '* * *' } | Should Throw 'Cron expression should only consist of 5 parts'
        }

        It 'Throws error for too many number of cron atoms' {
            { ConvertFrom-PodeCronExpression -Expression '* * * * * *' } | Should Throw 'Cron expression should only consist of 5 parts'
        }

        It 'Throws error for range atom with min>max' {
            { ConvertFrom-PodeCronExpression -Expression '* * 20-15 * *' } | Should Throw 'should not be greater than the max value'
        }

        It 'Throws error for range atom with invalid min' {
            { ConvertFrom-PodeCronExpression -Expression '* * 0-5 * *' } | Should Throw 'is invalid, should be greater than/equal to'
        }

        It 'Throws error for range atom with invalid max' {
            { ConvertFrom-PodeCronExpression -Expression '* * 1-32 * *' } | Should Throw 'is invalid, should be less than/equal to'
        }

        It 'Throws error for atom with invalid min' {
            { ConvertFrom-PodeCronExpression -Expression '* * 0 * *' } | Should Throw 'invalid, should be between'
        }

        It 'Throws error for atom with invalid max' {
            { ConvertFrom-PodeCronExpression -Expression '* * 32 * *' } | Should Throw 'invalid, should be between'
        }

        It 'Returns a valid cron object for predefined' {
            $cron = ConvertFrom-PodeCronExpression -Expression '@minutely'

            $cron.Month.Values | Should Be $null
            $cron.Month.Range.Min | Should Be 1
            $cron.Month.Range.Max | Should Be 12
            $cron.Month.Constraints[0] | Should Be 1
            $cron.Month.Constraints[1] | Should Be 12
            $cron.Month.Random | Should Be $false

            $cron.DayOfWeek.Values | Should Be $null
            $cron.DayOfWeek.Range.Min | Should Be 0
            $cron.DayOfWeek.Range.Max | Should Be 6
            $cron.DayOfWeek.Constraints[0] | Should Be 0
            $cron.DayOfWeek.Constraints[1] | Should Be 6
            $cron.DayOfWeek.Random | Should Be $false

            $cron.Minute.Values | Should Be $null
            $cron.Minute.Range.Min | Should Be 0
            $cron.Minute.Range.Max | Should Be 59
            $cron.Minute.Constraints[0] | Should Be 0
            $cron.Minute.Constraints[1] | Should Be 59
            $cron.Minute.Random | Should Be $false

            $cron.Hour.Values | Should Be $null
            $cron.Hour.Range.Min | Should Be 0
            $cron.Hour.Range.Max | Should Be 23
            $cron.Hour.Constraints[0] | Should Be 0
            $cron.Hour.Constraints[1] | Should Be 23
            $cron.Hour.Random | Should Be $false

            $cron.Random | Should Be $false

            $cron.DayOfMonth.Values | Should Be $null
            $cron.DayOfMonth.Range.Min | Should Be 1
            $cron.DayOfMonth.Range.Max | Should Be 31
            $cron.DayOfMonth.Constraints[0] | Should Be 1
            $cron.DayOfMonth.Constraints[1] | Should Be 31
            $cron.DayOfMonth.Random | Should Be $false
        }

        It 'Returns a valid cron object for expression' {
            $cron = ConvertFrom-PodeCronExpression -Expression '0/10 * * * 2'

            $cron.Month.Values | Should Be $null
            $cron.Month.Range.Min | Should Be 1
            $cron.Month.Range.Max | Should Be 12
            $cron.Month.Constraints[0] | Should Be 1
            $cron.Month.Constraints[1] | Should Be 12
            $cron.Month.Random | Should Be $false

            $cron.DayOfWeek.Values | Should Be 2
            $cron.DayOfWeek.Range.Min | Should Be $null
            $cron.DayOfWeek.Range.Max | Should Be $null
            $cron.DayOfWeek.Constraints[0] | Should Be 0
            $cron.DayOfWeek.Constraints[1] | Should Be 6
            $cron.DayOfWeek.Random | Should Be $false

            $cron.Minute.Values | Should Be @(0, 10, 20, 30, 40, 50)
            $cron.Minute.Range.Min | Should Be $null
            $cron.Minute.Range.Max | Should Be $null
            $cron.Minute.Constraints[0] | Should Be 0
            $cron.Minute.Constraints[1] | Should Be 59
            $cron.Minute.Random | Should Be $false

            $cron.Hour.Values | Should Be $null
            $cron.Hour.Range.Min | Should Be 0
            $cron.Hour.Range.Max | Should Be 23
            $cron.Hour.Constraints[0] | Should Be 0
            $cron.Hour.Constraints[1] | Should Be 23
            $cron.Hour.Random | Should Be $false

            $cron.Random | Should Be $false

            $cron.DayOfMonth.Values | Should Be $null
            $cron.DayOfMonth.Range.Min | Should Be 1
            $cron.DayOfMonth.Range.Max | Should Be 31
            $cron.DayOfMonth.Constraints[0] | Should Be 1
            $cron.DayOfMonth.Constraints[1] | Should Be 31
            $cron.DayOfMonth.Random | Should Be $false
        }
    }
}

Describe 'Test-PodeCronExpression'{
    $inputDate = [datetime]::parseexact('2019-02-05 14:30', 'yyyy-MM-dd HH:mm', $null)

    Context 'Passing test with fix cron' {

        It 'Returns true for a Tuesdays' {
            $cron = ConvertFrom-PodeCronExpression -Expression '* * * * 2'

            Test-PodeCronExpression -Expression $cron -DateTime $inputDate | Should Be $true
        }

        It 'Returns true for Feb' {
            $cron = ConvertFrom-PodeCronExpression -Expression '* * * 2 *'

            Test-PodeCronExpression -Expression $cron -DateTime $inputDate | Should Be $true
        }

        It 'Returns true for 5th day of month' {
            $cron = ConvertFrom-PodeCronExpression -Expression '* * 5 * *'

            Test-PodeCronExpression -Expression $cron -DateTime $inputDate | Should Be $true
        }

        It 'Returns true for 5th day of Feb' {
            $cron = ConvertFrom-PodeCronExpression -Expression '* * 5 2 *'

            Test-PodeCronExpression -Expression $cron -DateTime $inputDate | Should Be $true
        }

        It 'Returns true for 14th hour' {
            $cron = ConvertFrom-PodeCronExpression -Expression '* 14 * * *'

            Test-PodeCronExpression -Expression $cron -DateTime $inputDate | Should Be $true
        }

        It 'Returns true for 30th minute' {
            $cron = ConvertFrom-PodeCronExpression -Expression '30 * * * *'

            Test-PodeCronExpression -Expression $cron -DateTime $inputDate | Should Be $true
        }

        It 'Returns true for all values set' {
            $cron = ConvertFrom-PodeCronExpression -Expression '30 14 5 2 2'

            Test-PodeCronExpression -Expression $cron -DateTime $inputDate | Should Be $true
        }
    }

    Context 'Failing test with fix cron' {

        It 'Returns false for Jan' {
            $cron = ConvertFrom-PodeCronExpression -Expression '* * * 1 *'

            Test-PodeCronExpression -Expression $cron -DateTime $inputDate | Should Be $false
        }

        It 'Returns false for 4th day of Jan' {
            $cron = ConvertFrom-PodeCronExpression -Expression '* * 4 1 *'

            Test-PodeCronExpression -Expression $cron -DateTime $inputDate | Should Be $false
        }

        It 'Returns false for 13th hour' {
            $cron = ConvertFrom-PodeCronExpression -Expression '* 13 * * *'

            Test-PodeCronExpression -Expression $cron -DateTime $inputDate | Should Be $false
        }

        It 'Returns false for 20th minute' {
            $cron = ConvertFrom-PodeCronExpression -Expression '20 * * * *'

            Test-PodeCronExpression -Expression $cron -DateTime $inputDate | Should Be $false
        }

        It 'Returns false for all values set' {
            $cron = ConvertFrom-PodeCronExpression -Expression '20 13 4 1 3'

            Test-PodeCronExpression -Expression $cron -DateTime $inputDate | Should Be $false
        }
    }
}





