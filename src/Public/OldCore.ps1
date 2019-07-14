function Handler
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet('SMTP', 'TCP', 'Service')]
        [string]
        $Type,

        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [scriptblock]
        $ScriptBlock
    )

    # error if serverless
    Test-PodeIsServerless -FunctionName 'handler' -ThrowError

    # lower the type
    $Type = $Type.ToLowerInvariant()

    # ensure handler isn't already set
    if ($null -ne $PodeContext.Server.Handlers[$Type]) {
        throw "Handler for $($Type) already defined"
    }

    # add the handler
    $PodeContext.Server.Handlers[$Type] = $ScriptBlock
}

function Logger
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [Alias('n')]
        [string]
        $Name,

        [Parameter()]
        [Alias('d')]
        [object]
        $Details = $null,

        [switch]
        [Alias('c')]
        $Custom
    )

    # error if serverless
    Test-PodeIsServerless -FunctionName 'logger' -ThrowError

    # is logging disabled?
    if ($PodeContext.Server.Logging.Disabled) {
        Write-Host "Logging has been disabled for $($Name)" -ForegroundColor DarkCyan
        return
    }

    # set the logger as custom if flag is passed
    if ($Name -inotlike 'custom_*' -and $Custom) {
        $Name = "custom_$($Name)"
    }

    # lowercase the name
    $Name = $Name.ToLowerInvariant()

    # ensure the logger doesn't already exist
    if ($PodeContext.Server.Logging.Methods.ContainsKey($Name)) {
        throw "Logger called $($Name) already exists"
    }

    # ensure the details are of a correct type (inbuilt=hashtable, custom=scriptblock)
    $type = (Get-PodeType $Details)

    if ($Name -ilike 'custom_*') {
        if ($null -eq $Details) {
            throw 'For custom loggers, a ScriptBlock is required'
        }

        if ($type.Name -ine 'scriptblock') {
            throw "Custom logger details should be a ScriptBlock, but got: $($type.Name)"
        }
    }
    else {
        if ($null -ne $Details -and $type.Name -ine 'hashtable') {
            throw "Inbuilt logger details should be a HashTable, but got: $($type.Name)"
        }
    }

    # add the logger, along with any given details (hashtable/scriptblock)
    $PodeContext.Server.Logging.Methods[$Name] = $Details

    # if a file logger, create base directory (file is a dummy file, and won't be created)
    if ($Name -ieq 'file') {
        # has a specific logging path been supplied?
        if ($null -eq $Details -or (Test-IsEmpty $Details.Path)) {
            $path = (Split-Path -Parent -Path (Join-PodeServerRoot 'logs' 'tmp.txt'))
        }
        else {
            $path = $Details.Path
        }

        Write-Host "Log Path: $($path)" -ForegroundColor DarkCyan
        New-Item -Path $path -ItemType Directory -Force | Out-Null
    }
}

function Middleware
{
    param (
        [Parameter(Mandatory=$true, Position=0, ParameterSetName='Script')]
        [Parameter(Mandatory=$true, Position=1, ParameterSetName='ScriptRoute')]
        [ValidateNotNull()]
        [scriptblock]
        $ScriptBlock,

        [Parameter(Mandatory=$true, Position=0, ParameterSetName='ScriptRoute')]
        [Parameter(Mandatory=$true, Position=0, ParameterSetName='HashRoute')]
        [Alias('r')]
        [string]
        $Route,

        [Parameter(Mandatory=$true, Position=0, ParameterSetName='Hash')]
        [Parameter(Mandatory=$true, Position=1, ParameterSetName='HashRoute')]
        [Alias('h')]
        [hashtable]
        $HashTable,

        [Parameter()]
        [Alias('n')]
        [string]
        $Name,

        [switch]
        $Return
    )

    # if a name was supplied, ensure it doesn't already exist
    if (!(Test-IsEmpty $Name)) {
        if (($PodeContext.Server.Middleware | Where-Object { $_.Name -ieq $Name } | Measure-Object).Count -gt 0) {
            throw "Middleware with defined name of $($Name) already exists"
        }
    }

    # if route is empty, set it to root
    $Route = Protect-PodeValue -Value $Route -Default '/'
    $Route = Split-PodeRouteQuery -Path $Route
    $Route = Protect-PodeValue -Value $Route -Default '/'
    $Route = Update-PodeRouteSlashes -Path $Route
    $Route = Update-PodeRoutePlaceholders -Path $Route

    # create the middleware hash, or re-use a passed one
    if (Test-IsEmpty $HashTable)
    {
        $HashTable = @{
            'Name' = $Name;
            'Route' = $Route;
            'Logic' = $ScriptBlock;
        }
    }
    else
    {
        if (Test-IsEmpty $HashTable.Logic) {
            throw 'Middleware supplied has no Logic'
        }

        if (Test-IsEmpty $HashTable.Route) {
            $HashTable.Route = $Route
        }

        if (Test-IsEmpty $HashTable.Name) {
            $HashTable.Name = $Name
        }
    }

    # add the scriptblock to array of middleware that needs to be run
    if ($Return) {
        return $HashTable
    }
    else {
        $PodeContext.Server.Middleware += $HashTable
    }
}

function Schedule
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $Cron,

        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [Alias('l')]
        [int]
        $Limit = 0,

        [Parameter()]
        [Alias('start', 's')]
        $StartTime = $null,

        [Parameter()]
        [Alias('end', 'e')]
        $EndTime = $null
    )

    # error if serverless
    Test-PodeIsServerless -FunctionName 'schedule' -ThrowError

    # lower the name
    $Name = $Name.ToLowerInvariant()

    # ensure the schedule doesn't already exist
    if ($PodeContext.Schedules.ContainsKey($Name)) {
        throw "Schedule called $($Name) already exists"
    }

    # ensure the limit is valid
    if ($Limit -lt 0) {
        throw "Schedule $($Name) cannot have a negative limit"
    }

    # ensure the start/end dates are valid
    if ($null -ne $EndTime -and $EndTime -lt [DateTime]::Now) {
        throw "Schedule $($Name) must have an EndTime in the future"
    }

    if ($null -ne $StartTime -and $null -ne $EndTime -and $EndTime -lt $StartTime) {
        throw "Schedule $($Name) cannot have a StartTime after the EndTime"
    }

    # add the schedule
    $PodeContext.Schedules[$Name] = @{
        'Name' = $Name;
        'StartTime' = $StartTime;
        'EndTime' = $EndTime;
        'Crons' = (ConvertFrom-PodeCronExpressions -Expressions @($Cron));
        'Limit' = $Limit;
        'Count' = 0;
        'Countable' = ($Limit -gt 0);
        'Script' = $ScriptBlock;
    }
}

function Timer
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name,

        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [Alias('i')]
        [int]
        $Interval,

        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [Alias('l')]
        [int]
        $Limit = 0,

        [Parameter()]
        [Alias('s')]
        [int]
        $Skip = 0
    )

    # error if serverless
    Test-PodeIsServerless -FunctionName 'timer' -ThrowError

    # lower the name
    $Name = $Name.ToLowerInvariant()

    # ensure the timer doesn't already exist
    if ($PodeContext.Timers.ContainsKey($Name)) {
        throw "Timer called $($Name) already exists"
    }

    # is the interval valid?
    if ($Interval -le 0) {
        throw "Timer $($Name) cannot have an interval less than or equal to 0"
    }

    # is the limit valid?
    if ($Limit -lt 0) {
        throw "Timer $($Name) cannot have a negative limit"
    }

    if ($Limit -ne 0) {
        $Limit += $Skip
    }

    # is the skip valid?
    if ($Skip -lt 0) {
        throw "Timer $($Name) cannot have a negative skip value"
    }

    # run script if it's not being skipped
    if ($Skip -eq 0) {
        Invoke-PodeScriptBlock -ScriptBlock $ScriptBlock -Arguments @{ 'Lockable' = $PodeContext.Lockable } -Scoped
    }

    # add the timer
    $PodeContext.Timers[$Name] = @{
        'Name' = $Name;
        'Interval' = $Interval;
        'Limit' = $Limit;
        'Count' = 0;
        'Skip' = $Skip;
        'Countable' = ($Skip -gt 0 -or $Limit -gt 0);
        'NextTick' = [DateTime]::Now.AddSeconds($Interval);
        'Script' = $ScriptBlock;
    }
}