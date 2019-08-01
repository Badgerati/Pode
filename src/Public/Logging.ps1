function New-PodeLoggingType
{
    [CmdletBinding(DefaultParameterSetName='Terminal')]
    param (
        [Parameter(ParameterSetName='Terminal')]
        [switch]
        $Terminal,

        [Parameter(ParameterSetName='File')]
        [switch]
        $File,

        [Parameter(ParameterSetName='File')]
        [string]
        $Path = './logs',

        [Parameter(Mandatory=$true, ParameterSetName='File')]
        [string]
        $Name,

        [Parameter(ParameterSetName='File')]
        [ValidateScript({
            if ($_ -lt 0) {
                throw "MaxDays must be 0 or greater, but got: $($_)s"
            }

            return $true
        })]
        [int]
        $MaxDays = 0,

        [Parameter(ParameterSetName='File')]
        [ValidateScript({
            if ($_ -lt 0) {
                throw "MaxSize must be 0 or greater, but got: $($_)s"
            }

            return $true
        })]
        [int]
        $MaxSize = 0,

        [Parameter(ParameterSetName='Custom')]
        [switch]
        $Custom,

        [Parameter(Mandatory=$true, ParameterSetName='Custom')]
        [ValidateScript({
            if (Test-IsEmpty $_) {
                throw "A non-empty ScriptBlock is required for the Custom logging type"
            }

            return $true
        })]
        [scriptblock]
        $ScriptBlock,

        [Parameter(ParameterSetName='Custom')]
        [hashtable]
        $Options
    )

    switch ($PSCmdlet.ParameterSetName.ToLowerInvariant()) {
        'terminal' {
            return @{
                ScriptBlock = (Get-PodeLoggingTerminalType)
                Options = @{}
            }
        }

        'file' {
            $Path = (Protect-PodeValue -Value $Path -Default './logs')
            $Path = (Get-PodeRelativePath -Path $Path -JoinRoot)
            New-Item -Path $Path -ItemType Directory -Force | Out-Null

            return @{
                ScriptBlock = (Get-PodeLoggingFileType)
                Options = @{
                    Name = $Name
                    Path = $Path
                    MaxDays = $MaxDays
                    MaxSize = $MaxSize
                    FileId = 0
                    Date = $null
                    NextClearDown = [datetime]::Now.Date
                }
            }
        }

        'custom' {
            return @{
                ScriptBlock = $ScriptBlock
                Options = $Options
            }
        }
    }
}

function Enable-PodeRequestLogging
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [hashtable]
        $Type
    )

    $name = Get-PodeRequestLoggingName

    # error if it's already enabled
    if ($PodeContext.Server.Logging.Methods.Contains($name)) {
        throw 'Request Logging has already been enabled'
    }

    # ensure the Type contains a scriptblock
    if (Test-IsEmpty $Type.ScriptBlock) {
        throw "The supplied Type for Request Logging requires a valid ScriptBlock"
    }

    # add the request logger
    $PodeContext.Server.Logging.Methods[$name] = @{
        Type = $Type
        ScriptBlock = (Get-PodeLoggingInbuiltMethod -Type Requests)
        Options = @{}
    }
}

function Enable-PodeErrorLogging
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [hashtable]
        $Type
    )

    $name = Get-PodeErrorLoggingName

    # error if it's already enabled
    if ($PodeContext.Server.Logging.Methods.Contains($name)) {
        throw 'Error Logging has already been enabled'
    }

    # ensure the Type contains a scriptblock
    if (Test-IsEmpty $Type.ScriptBlock) {
        throw "The supplied Type for Error Logging requires a valid ScriptBlock"
    }

    # add the error logger
    $PodeContext.Server.Logging.Methods[$name] = @{
        Type = $Type
        ScriptBlock = (Get-PodeLoggingInbuiltMethod -Type Errors)
        Options = @{}
    }
}

function Add-PodeLogger
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Name,

        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [hashtable]
        $Type,

        [Parameter(Mandatory=$true)]
        [ValidateScript({
            if (Test-IsEmpty $_) {
                throw "A non-empty ScriptBlock is required for the logging method"
            }

            return $true
        })]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [hashtable]
        $Options
    )

    # ensure the name doesn't already exist
    if ($PodeContext.Server.Logging.Methods.ContainsKey($Name)) {
        throw "Logging method already defined: $($Name)"
    }

    # ensure the Type contains a scriptblock
    if (Test-IsEmpty $Type.ScriptBlock) {
        throw "The supplied Type for the '$($Name)' Logging method requires a valid ScriptBlock"
    }

    # add logging method to server
    $PodeContext.Server.Logging.Methods[$Name] = @{
        Type = $Type
        ScriptBlock = $ScriptBlock
        Options = $Options
    }
}

function Remove-PodeLogger
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [string]
        $Name
    )

    $PodeContext.Server.Logging.Methods.Remove($Name) | Out-Null
}

function Clear-PodeLoggers
{
    [CmdletBinding()]
    param()

    $PodeContext.Server.Logging.Methods.Clear()
}

function Write-PodeErrorLog
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true, ParameterSetName='Exception')]
        [System.Exception]
        $Exception,

        [Parameter(Mandatory=$true, ValueFromPipeline=$true, ParameterSetName='Error')]
        [System.Management.Automation.ErrorRecord]
        $ErrorRecord
    )

    # do nothing if logging is disabled, or error logging isn't setup
    $name = Get-PodeErrorLoggingName
    if (!(Test-PodeLoggerEnabled -Name $name)) {
        return
    }

    # build error object for what we need
    switch ($PSCmdlet.ParameterSetName.ToLowerInvariant()) {
        'exception' {
            $item = @{
                Category = $Exception.Source
                Message = $Exception.Message
                StackTrace = $Exception.StackTrace
            }
        }

        'error' {
            $item = @{
                Category = $ErrorRecord.CategoryInfo.ToString()
                Message = $ErrorRecord.Exception.Message
                StackTrace = $ErrorRecord.ScriptStackTrace
            }
        }
    }

    # add the item to be processed
    $PodeContext.LogsToProcess.Add(@{
        Name = $name
        Item = $item
    }) | Out-Null
}

function Write-PodeLog
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Name,

        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [object]
        $InputObject
    )

    # do nothing if logging is disabled, or logger isn't setup
    if (!(Test-PodeLoggerEnabled -Name $Name)) {
        return
    }

    # add the item to be processed
    $PodeContext.LogsToProcess.Add(@{
        Name = $Name
        Item = $InputObject
    }) | Out-Null
}