function Get-CronFields
{
    return @(
        'Minute',
        'Hour',
        'DayOfMonth',
        'Month',
        'DayOfWeek'
    )
}

function Get-CronFieldConstraints
{
    return @{
        'MinMax' = @(
            @(0, 59),
            @(0, 23),
            @(1, 31),
            @(1, 12),
            @(0, 6)
        );
        'DaysInMonths' = @(
            31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31
        );
        'Months' = @(
            'January', 'February', 'March', 'April', 'May', 'June', 'July',
            'August', 'September', 'October', 'November', 'December'
        )
    }
}

function Get-CronPredefined
{
    return @{
        # normal
        '@minutely' = '* * * * *';
        '@hourly' = '0 * * * *';
        '@daily' = '0 0 * * *';
        '@weekly' = '0 0 * * 0';
        '@monthly' = '0 0 1 * *';
        '@quaterly' = '0 0 1 1,4,8,7,10';
        '@yearly' = '0 0 1 1 *';
        '@annually' = '0 0 1 1 *';

        # twice
        '@twice-hourly' = '0,30 * * * *';
        '@twice-daily' = '0,12 0 * * *';
        '@twice-weekly' = '0 0 * * 0,4';
        '@twice-monthly' = '0 0 1,15 * *';
        '@twice-yearly' = '0 0 1 1,6 *';
        '@twice-annually' = '0 0 1 1,6 *';
    }
}

function Get-CronFieldAliases
{
    return @{
        'Month' = @{
            'Jan' = 1;
            'Feb' = 2;
            'Mar' = 3;
            'Apr' = 4;
            'May' = 5;
            'Jun' = 6;
            'Jul' = 7;
            'Aug' = 8;
            'Sep' = 9;
            'Oct' = 10;
            'Nov' = 11;
            'Dec' = 12;
        };
        'DayOfWeek' = @{
            'Sun' = 0;
            'Mon' = 1;
            'Tue' = 2;
            'Wed' = 3;
            'Thu' = 4;
            'Fri' = 5;
            'Sat' = 6;
        };
    }
}

function ConvertFrom-CronExpression
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Expression
    )

    $Expression = $Expression.Trim()

    # check predefineds
    $predef = Get-CronPredefined
    if (!(Test-Empty $predef[$Expression])) {
        $Expression = $predef[$Expression]
    }

    # split and check atoms length
    $atoms = @($Expression -isplit '\s+')
    if ($atoms.Length -ne 5) {
        throw "Cron expression should only consist of 5 parts: $($Expression)"
    }

    # basic variables
    $aliasRgx = '(?<tag>[a-z]{3})'

    # get cron obj and validate atoms
    $fields = Get-CronFields
    $constraints = Get-CronFieldConstraints
    $aliases = Get-CronFieldAliases
    $cron = @{}

    for ($i = 0; $i -lt $atoms.Length; $i++)
    {
        $_cronExp = @{
            'Range' = $null;
            'Values' = $null;
            'Constraints' = $null;
            'Random' = $false;
        }

        $_atom = $atoms[$i]
        $_field = $fields[$i]
        $_constraint = $constraints.MinMax[$i]
        $_aliases = $aliases[$_field]

        # replace day of week and months with numbers
        switch ($_field)
        {
            { $_field -ieq 'month' -or $_field -ieq 'dayofweek' }
                {
                    while ($_atom -imatch $aliasRgx) {
                        $_alias = $_aliases[$Matches['tag']]
                        if ($null -eq $_alias) {
                            throw "Invalid $($_field) alias found: $($Matches['tag'])"
                        }

                        $_atom = $_atom -ireplace $Matches['tag'], $_alias
                        $_atom -imatch $aliasRgx | Out-Null
                    }
                }
        }

        # ensure atom is a valid value
        if (!($_atom -imatch '^[\d|/|*|\-|,r]+$')) {
            throw "Invalid atom character: $($_atom)"
        }

        # replace * with min/max constraint
        $_atom = $_atom -ireplace '\*', ($_constraint -join '-')

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

            if ([string]::IsNullOrWhiteSpace($start) -or $start -ieq '*') {
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
            throw "Invalid cron atom format found: $($_atom)"
        }

        # ensure cron expression values are valid
        if ($null -ne $_cronExp.Range) {
            if ($_cronExp.Range.Min -gt $_cronExp.Range.Max) {
                throw "Min value for $($_field) should not be greater than the max value"
            }

            if ($_cronExp.Range.Min -lt $_constraint[0]) {
                throw "Min value '$($_cronExp.Range.Min)' for $($_field) is invalid, should be greater than/equal to $($_constraint[0])"
            }

            if ($_cronExp.Range.Max -gt $_constraint[1]) {
                throw "Max value '$($_cronExp.Range.Max)' for $($_field) is invalid, should be less than/equal to $($_constraint[1])"
            }
        }

        if ($null -ne $_cronExp.Values) {
            $_cronExp.Values | ForEach-Object {
                if ($_ -lt $_constraint[0] -or $_ -gt $_constraint[1]) {
                    throw "Value '$($_)' for $($_field) is invalid, should be between $($_constraint[0]) and $($_constraint[1])"
                }
            }
        }

        # assign value
        $_cronExp.Constraints = $_constraint
        $cron[$_field] = $_cronExp
    }

    # post validation for month/days in month
    if ($null -ne $cron['Month'].Values -and $null -ne $cron['DayOfMonth'].Values)
    {
        foreach ($mon in $cron['Month'].Values) {
            foreach ($day in $cron['DayOfMonth'].Values) {
                if ($day -gt $constraints.DaysInMonths[$mon - 1]) {
                    throw "$($constraints.Months[$mon - 1]) only has $($constraints.DaysInMonths[$mon - 1]) days, but $($day) was supplied"
                }
            }
        }
    }

    # flag if this cron contains a random atom
    $cron['Random'] = (($cron.Values | Where-Object { $_.Random } | Measure-Object).Count -gt 0)

    # return the parsed cron expression
    return $cron
}

function Reset-RandomCronExpression
{
    param (
        [Parameter(Mandatory=$true)]
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

function Test-CronExpression
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        $Expression,

        [Parameter()]
        $DateTime = $null
    )

    function Test-RangeAndValue($AtomContraint, $NowValue) {
        if ($null -ne $AtomContraint.Range) {
            if ($NowValue -lt $AtomContraint.Range.Min -or $NowValue -gt $AtomContraint.Range.Max) {
                return $false
            }
        }
        elseif ($AtomContraint.Values -inotcontains $NowValue) {
            return $false
        }

        return $true
    }

    # current time
    if ($null -eq $DateTime) {
        $DateTime = [datetime]::Now
    }

    # check day of week and day of month (both must fail)
    if (!(Test-RangeAndValue -AtomContraint $Expression.DayOfWeek -NowValue ([int]$DateTime.DayOfWeek)) -and
        !(Test-RangeAndValue -AtomContraint $Expression.DayOfMonth -NowValue $DateTime.Day)) {
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