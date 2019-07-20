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