<#
.SYNOPSIS
    Provides a list of cron expression fields.

.DESCRIPTION
    This function returns an array of strings representing the different fields in a cron expression. These fields include 'Minute', 'Hour', 'DayOfMonth', 'Month', and 'DayOfWeek'.

.OUTPUTS
    Returns an array of strings representing cron expression fields.

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function Get-PodeCronField {
    [CmdletBinding()]
    [OutputType([string[]])]
    param()
    return [string[]]@(
        'Minute',
        'Hour',
        'DayOfMonth',
        'Month',
        'DayOfWeek'
    )
}

<#
.SYNOPSIS
    Provides constraints and information for cron expression fields.

.DESCRIPTION
    This function returns a hashtable containing constraints and information for various cron expression fields. It includes details such as valid ranges for minutes, hours, days of the month, months, and days of the week.

.OUTPUTS
    Returns a hashtable with constraints and information for cron expression fields.

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function Get-PodeCronFieldConstraint {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()
    return @{
        MinMax       = @(
            @(0, 59),
            @(0, 23),
            @(1, 31),
            @(1, 12),
            @(0, 6)
        )
        DaysInMonths = @(
            31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31
        )
        Months       = @(
            'January', 'February', 'March', 'April', 'May', 'June', 'July',
            'August', 'September', 'October', 'November', 'December'
        )
    }
}

function Get-PodeCronPredefined {
    return @{
        # normal
        '@minutely'       = '* * * * *'
        '@hourly'         = '0 * * * *'
        '@daily'          = '0 0 * * *'
        '@weekly'         = '0 0 * * 0'
        '@monthly'        = '0 0 1 * *'
        '@quarterly'      = '0 0 1 1,4,7,10 *'
        '@yearly'         = '0 0 1 1 *'
        '@annually'       = '0 0 1 1 *'

        # twice
        '@twice-hourly'   = '0,30 * * * *'
        '@twice-daily'    = '0 0,12 * * *'
        '@twice-weekly'   = '0 0 * * 0,4'
        '@twice-monthly'  = '0 0 1,15 * *'
        '@twice-yearly'   = '0 0 1 1,6 *'
        '@twice-annually' = '0 0 1 1,6 *'
    }
}

<#
.SYNOPSIS
    Provides aliases for cron expression fields.

.DESCRIPTION
    This function returns a hashtable containing aliases for cron expression fields. It includes mappings for month abbreviations (e.g., 'Jan' to 1) and day of the week abbreviations (e.g., 'Sun' to 0).

.OUTPUTS
    Returns a hashtable with aliases for cron expression fields.

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function Get-PodeCronFieldAlias {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()
    return @{
        Month     = @{
            Jan = 1
            Feb = 2
            Mar = 3
            Apr = 4
            May = 5
            Jun = 6
            Jul = 7
            Aug = 8
            Sep = 9
            Oct = 10
            Nov = 11
            Dec = 12
        }
        DayOfWeek = @{
            Sun = 0
            Mon = 1
            Tue = 2
            Wed = 3
            Thu = 4
            Fri = 5
            Sat = 6
        }
    }
}

<#
.SYNOPSIS
    Converts a Pode-style cron expression into a hashtable representation.

.DESCRIPTION
    This function takes an array of Pode-style cron expressions and converts them into a hashtable format. Each hashtable represents a cron expression with its individual components.

.PARAMETER Expression
    An array of Pode-style cron expressions to convert.

.OUTPUTS
    A hashtable representing the cron expression with the following keys:
    - 'Minute'
    - 'Hour'
    - 'DayOfMonth'
    - 'Month'
    - 'DayOfWeek'

.NOTES
    This is an internal function and may change in future releases of Pode.
#>

function ConvertFrom-PodeCronExpression {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $Expression
    )
    $cronList = @()

    foreach ($item in $Expression) {
        if ([string]::IsNullOrEmpty($item)) {
            continue
        }
        $item = $item.Trim()

        # check predefineds
        $predef = Get-PodeCronPredefined
        if (!(Test-PodeIsEmpty $predef[$item])) {
            $item = $predef[$item]
        }

        # split and check atoms length
        $atoms = @($item -isplit '\s+')
        if ($atoms.Length -ne 5) {
            # Cron expression should only consist of 5 parts
            throw ($PodeLocale.cronExpressionInvalidExceptionMessage -f $Expression)
        }

        # basic variables
        $aliasRgx = '(?<tag>[a-z]{3})'

        # get cron obj and validate atoms
        $fields = Get-PodeCronField
        $constraints = Get-PodeCronFieldConstraint
        $aliases = Get-PodeCronFieldAlias
        $cron = @{}

        for ($i = 0; $i -lt $atoms.Length; $i++) {
            $_cronExp = @{
                Range       = $null
                Values      = $null
                Constraints = $null
                Random      = $false
                WildCard    = $false
            }

            $_atom = $atoms[$i]
            $_field = $fields[$i]
            $_constraint = $constraints.MinMax[$i]
            $_aliases = $aliases[$_field]

        # replace day of week and months with numbers
        if (@('month', 'dayofweek') -icontains $_field) {
            while ($_atom -imatch $aliasRgx) {
                $_alias = $_aliases[$Matches['tag']]
                if ($null -eq $_alias) {
                    # Invalid $($_field) alias found: $($Matches['tag'])
                    throw ($PodeLocale.invalidAliasFoundExceptionMessage -f $_field, $Matches['tag'])
                }

                    $_atom = $_atom -ireplace $Matches['tag'], $_alias
                    $null = $_atom -imatch $aliasRgx
                }
            }

        # ensure atom is a valid value
        if (!($_atom -imatch '^[\d|/|*|\-|,r]+$')) {
            # Invalid atom character
            throw ($PodeLocale.invalidAtomCharacterExceptionMessage -f $_atom)
        }

            # replace * with min/max constraint
            if ($_atom -ieq '*') {
                $_cronExp.WildCard = $true
                $_atom = ($_constraint -join '-')
            }

            # parse the atom for either a literal, range, array, or interval
            # literal
            if ($_atom -imatch '^(\d+|r)$') {
                # check if it's random
                if ($_atom -ieq 'r') {
                    $_cronExp.Values = @(Get-Random -Minimum $_constraint[0] -Maximum ($_constraint[1] + 1))
                    $_cronExp.Random = $true
                }
                else {
                    $_cronExp.Values = @([int]$_atom)
                }
            }

            # range
            elseif ($_atom -imatch '^(?<min>\d+)\-(?<max>\d+)$') {
                $_cronExp.Range = @{ 'Min' = [int]($Matches['min'].Trim()); 'Max' = [int]($Matches['max'].Trim()); }
            }

            # array
            elseif ($_atom -imatch '^[\d,]+$') {
                $_cronExp.Values = [int[]](@($_atom -split ',').Trim())
            }

            # interval
            elseif ($_atom -imatch '(?<start>(\d+|\*))\/(?<interval>(\d+|r))$') {
                $start = $Matches['start']
                $interval = $Matches['interval']

                if ($interval -ieq '0') {
                    $interval = '1'
                }

                if ([string]::IsNullOrWhiteSpace($start) -or ($start -ieq '*')) {
                    $start = '0'
                }

                # set the initial trigger value
                $_cronExp.Values = @([int]$start)

                # check if it's random
                if ($interval -ieq 'r') {
                    $_cronExp.Random = $true
                }
                else {
                    # loop to get all next values
                    $next = [int]$start + [int]$interval
                    while ($next -le $_constraint[1]) {
                        $_cronExp.Values += $next
                        $next += [int]$interval
                    }
                }
            }

        # error
        else {
            # Invalid cron atom format found
            throw ($PodeLocale.invalidCronAtomFormatExceptionMessage -f $_atom)
        }

        # ensure cron expression values are valid
        if ($null -ne $_cronExp.Range) {
            if ($_cronExp.Range.Min -gt $_cronExp.Range.Max) {
                # Min value should not be greater than the max value
                throw ($PodeLocale.minValueGreaterThanMaxExceptionMessage -f $_field)
            }

            if ($_cronExp.Range.Min -lt $_constraint[0]) {
                # Min value for $($_field) is invalid, should be greater than/equal
                throw ($PodeLocale.minValueInvalidExceptionMessage -f $_cronExp.Range.Min, $_field, $_constraint[0])
            }

            if ($_cronExp.Range.Max -gt $_constraint[1]) {
                # Max value for $($_field) is invalid, should be greater than/equal
                throw ($PodeLocale.maxValueInvalidExceptionMessage -f $_cronExp.Range.Max, $_field, $_constraint[1])
            }
        }

        if ($null -ne $_cronExp.Values) {
            $_cronExp.Values | ForEach-Object {
                if ($_ -lt $_constraint[0] -or $_ -gt $_constraint[1]) {
                    # Value is invalid, should be between
                    throw ($PodeLocale.valueOutOfRangeExceptionMessage -f $value, $_field, $_constraint[0], $_constraint[1])
                }
            }
        }

            # assign value
            $_cronExp.Constraints = $_constraint
            $cron[$_field] = $_cronExp
        }

    # post validation for month/days in month
    if (($null -ne $cron['Month'].Values) -and ($null -ne $cron['DayOfMonth'].Values)) {
        foreach ($mon in $cron['Month'].Values) {
            foreach ($day in $cron['DayOfMonth'].Values) {
                if ($day -gt $constraints.DaysInMonths[$mon - 1]) {
                    # $($constraints.Months[$mon - 1]) only has $($constraints.DaysInMonths[$mon - 1]) days, but $($day) was supplied
                    throw ($PodeLocale.daysInMonthExceededExceptionMessage -f $constraints.Months[$mon - 1], $constraints.DaysInMonths[$mon - 1], $day)
                }
            }
        }
    }

        # flag if this cron contains a random atom
        $cron['Random'] = (($cron.Values | Where-Object { $_.Random } | Measure-Object).Count -gt 0)

        # add the cron to the list
        $cronList += $cron
    }

    # return the cronlist
    return $cronList
}

function Reset-PodeRandomCronExpressions {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        $Expressions
    )

    return @(@($Expressions) | ForEach-Object {
            Reset-PodeRandomCronExpression -Expression $_
        })
}

function Reset-PodeRandomCronExpression {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        $Expression
    )

    function Reset-Atom($Atom) {
        if (!$Atom.Random) {
            return $Atom
        }

        if ($Atom.Random) {
            $Atom.Values = @(Get-Random -Minimum $Atom.Constraints[0] -Maximum ($Atom.Constraints[1] + 1))
        }

        return $Atom
    }

    if (!$Expression.Random) {
        return $Expression
    }

    $Expression.Minute = (Reset-Atom -Atom $Expression.Minute)
    $Expression.Hour = (Reset-Atom -Atom $Expression.Hour)
    $Expression.DayOfMonth = (Reset-Atom -Atom $Expression.DayOfMonth)
    $Expression.Month = (Reset-Atom -Atom $Expression.Month)
    $Expression.DayOfWeek = (Reset-Atom -Atom $Expression.DayOfWeek)

    return $Expression
}

function Test-PodeCronExpressions {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        $Expressions,

        [Parameter()]
        $DateTime = $null
    )

    return ((@($Expressions) | Where-Object {
                Test-PodeCronExpression -Expression $_ -DateTime $DateTime
            } | Measure-Object).Count -gt 0)
}

function Test-PodeCronExpression {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        $Expression,

        [Parameter()]
        $DateTime = $null
    )

    function Test-RangeAndValue($AtomContraint, $NowValue) {
        if ($null -ne $AtomContraint.Range) {
            return (!(($NowValue -lt $AtomContraint.Range.Min) -or ($NowValue -gt $AtomContraint.Range.Max)))
        }

        return ($AtomContraint.Values -icontains $NowValue)
    }

    # current time
    if ($null -eq $DateTime) {
        $DateTime = [datetime]::Now
    }

    # check day of month
    if (!(Test-RangeAndValue -AtomContraint $Expression.DayOfMonth -NowValue $DateTime.Day)) {
        return $false
    }

    # check day of week
    if (!(Test-RangeAndValue -AtomContraint $Expression.DayOfWeek -NowValue ([int]$DateTime.DayOfWeek))) {
        return $false
    }

    # check month
    if (!(Test-RangeAndValue -AtomContraint $Expression.Month -NowValue $DateTime.Month)) {
        return $false
    }

    # check hour
    if (!(Test-RangeAndValue -AtomContraint $Expression.Hour -NowValue $DateTime.Hour)) {
        return $false
    }

    # check minute
    if (!(Test-RangeAndValue -AtomContraint $Expression.Minute -NowValue $DateTime.Minute)) {
        return $false
    }

    # date is valid
    return $true
}

function Get-PodeCronNextEarliestTrigger {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        $Expressions,

        [Parameter()]
        $StartTime = $null,

        [Parameter()]
        $EndTime = $null
    )

    return (@($Expressions) | Foreach-Object {
            Get-PodeCronNextTrigger -Expression $_ -StartTime $StartTime -EndTime $EndTime
        } | Where-Object { $null -ne $_ } | Sort-Object | Select-Object -First 1)
}

function Get-PodeCronNextTrigger {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        $Expression,

        [Parameter()]
        $StartTime = $null,

        [Parameter()]
        $EndTime = $null
    )

    # start from the current time, if a start time not defined
    if ($null -eq $StartTime) {
        $StartTime = [datetime]::Now
    }
    $StartTime = $StartTime.AddMinutes(1)

    # the next time to trigger
    $NextTime = [datetime]::new($StartTime.Year, $StartTime.Month, $StartTime.Day, $StartTime.Hour, $StartTime.Minute, 0)

    # first, is the current time valid?
    if (Test-PodeCronExpression -Expression $Expression -DateTime $NextTime) {
        return $NextTime
    }

    # functions for getting the closest value
    function Get-ClosestValue($AtomContraint, $NowValue) {
        $_values = $AtomContraint.Values
        if ($null -eq $_values) {
            $_values = ($AtomContraint.Range.Min..$AtomContraint.Range.Max)
        }

        if (($_values.Length -eq 1) -or ($_values[-1] -lt $NowValue) -or ($_values[0] -gt $NowValue)) {
            return $_values[0]
        }

        return ($_values -ge $NowValue)[0]
    }

    # loop until we get a date
    while ($true) {
        # check the minute
        if (!$Expression.Minute.WildCard) {
            $minute = Get-ClosestValue -AtomContraint $Expression.Minute -NowValue $NextTime.Minute
            if ($minute -lt $NextTime.Minute) {
                $NextTime = $NextTime.AddHours(1)
            }

            $NextTime = $NextTime.AddMinutes($minute - $NextTime.Minute)
        }

        # check hour
        if (!$Expression.Hour.WildCard) {
            $hour = Get-ClosestValue -AtomContraint $Expression.Hour -NowValue $NextTime.Hour
            if ($hour -lt $NextTime.Hour) {
                $NextTime = $NextTime.AddDays(1)
            }

            $_hour = $NextTime.Hour
            $NextTime = $NextTime.AddHours($hour - $NextTime.Hour)
            if ($_hour -ne $hour) {
                $NextTime = [datetime]::new($NextTime.Year, $NextTime.Month, $NextTime.Day, $NextTime.Hour, 0, 0)
                continue
            }
        }

        # check day
        if (!$Expression.DayOfMonth.WildCard) {
            $day = Get-ClosestValue -AtomContraint $Expression.DayOfMonth -NowValue $NextTime.Day
            if (($day -lt $NextTime.Day) -or ($day -gt [datetime]::DaysInMonth($NextTime.Year, $NextTime.Month))) {
                $NextTime = $NextTime.AddMonths(1)
            }

            if ($day -gt [datetime]::DaysInMonth($NextTime.Year, $NextTime.Month)) {
                $NextTime = [datetime]::new($NextTime.Year, $NextTime.Month, 1, 0, 0, 0)
                continue
            }

            $_day = $NextTime.Day
            $NextTime = $NextTime.AddDays($day - $NextTime.Day)
            if ($_day -ne $day) {
                $NextTime = [datetime]::new($NextTime.Year, $NextTime.Month, $NextTime.Day, 0, 0, 0)
                continue
            }
        }

        # check month
        if (!$Expression.Month.WildCard) {
            $month = Get-ClosestValue -AtomContraint $Expression.Month -NowValue $NextTime.Month
            if ($month -lt $NextTime.Month) {
                $NextTime = $NextTime.AddYears(1)
            }

            $_month = $NextTime.Month
            $NextTime = $NextTime.AddMonths($month - $NextTime.Month)
            if ($_month -ne $month) {
                $NextTime = [datetime]::new($NextTime.Year, $NextTime.Month, 1, 0, 0, 0)
                continue
            }
        }

        # check day of week
        if (!$Expression.DayOfWeek.WildCard) {
            $doweek = Get-ClosestValue -AtomContraint $Expression.DayOfWeek -NowValue $NextTime.DayOfWeek

            $_doweek = $NextTime.DayOfWeek
            if ($doweek -lt $NextTime.DayOfWeek) {
                $NextTime = $NextTime.AddDays(7 - ($NextTime.DayOfWeek - $doweek))
            }
            elseif ($doweek -gt $NextTime.DayOfWeek) {
                $NextTime = $NextTime.AddDays($doweek - $NextTime.DayOfWeek)
            }

            if ($_doweek -ne $doweek) {
                $NextTime = [datetime]::new($NextTime.Year, $NextTime.Month, $NextTime.Day, 0, 0, 0)
                continue
            }
        }

        break
    }

    # before we return, make sure the time is valid
    if (!(Test-PodeCronExpression -Expression $Expression -DateTime $NextTime)) {
        throw ($PodeLocale.nextTriggerCalculationErrorExceptionMessage -f $NextTime) #"Looks like something went wrong trying to calculate the next trigger datetime: $($NextTime)"
    }

    # if before the start or after end then return null
    if (($NextTime -lt $StartTime) -or (($null -ne $EndTime) -and ($NextTime -gt $EndTime))) {
        return $null
    }

    return $NextTime
}