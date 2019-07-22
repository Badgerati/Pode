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