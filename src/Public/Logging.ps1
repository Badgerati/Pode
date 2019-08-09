<#
.SYNOPSIS
Create a new method of outputting logs.

.DESCRIPTION
Create a new method of outputting logs.

.PARAMETER Terminal
If supplied, will use the inbuilt Terminal logging output method.

.PARAMETER File
If supplied, will use the inbuilt File logging output method.

.PARAMETER Path
The File Path of where to store the logs.

.PARAMETER Name
The File Name to prepend new log files using.

.PARAMETER MaxDays
The maximum number of days to keep logs, before Pode automatically removes them.

.PARAMETER MaxSize
The maximum size of a log file, before Pode starts writing to a new log file.

.PARAMETER Custom
If supplied, will allow you to create a Custom Logging output method.

.PARAMETER ScriptBlock
The ScriptBlock that defines how to output a log item.

.PARAMETER Options
Any custom Options to supply to a Custom Logging output method's ScriptBlock.

.EXAMPLE
$term_logging = New-PodeLoggingMethod -Terminal

.EXAMPLE
$file_logging = New-PodeLoggingMethod -File -Path ./logs -Name 'requests'

.EXAMPLE
$custom_logging = New-PodeLoggingMethod -Custom -ScriptBlock { /* logic */ }
#>
function New-PodeLoggingMethod
{
    [CmdletBinding(DefaultParameterSetName='Terminal')]
    [OutputType([hashtable])]
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
                throw "A non-empty ScriptBlock is required for the Custom logging output method"
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
                ScriptBlock = (Get-PodeLoggingTerminalMethod)
                Options = @{}
            }
        }

        'file' {
            $Path = (Protect-PodeValue -Value $Path -Default './logs')
            $Path = (Get-PodeRelativePath -Path $Path -JoinRoot)
            New-Item -Path $Path -ItemType Directory -Force | Out-Null

            return @{
                ScriptBlock = (Get-PodeLoggingFileMethod)
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


<#
.SYNOPSIS
Enables Request Logging using a supplied output method.

.DESCRIPTION
Enables Request Logging using a supplied output method.

.PARAMETER Method
The Method to use for output the log entry (From New-PodeLoggingMethod).

.PARAMETER Raw
If supplied, the log item returned will be the raw Request item as a hashtable and not a string (for Custom methods).

.EXAMPLE
New-PodeLoggingMethod -Terminal | Enable-PodeRequestLogging
#>
function Enable-PodeRequestLogging
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [hashtable]
        $Method,

        [switch]
        $Raw
    )

    Test-PodeIsServerless -FunctionName 'Enable-PodeRequestLogging' -ThrowError

    $name = Get-PodeRequestLoggingName

    # error if it's already enabled
    if ($PodeContext.Server.Logging.Types.Contains($name)) {
        throw 'Request Logging has already been enabled'
    }

    # ensure the Method contains a scriptblock
    if (Test-IsEmpty $Method.ScriptBlock) {
        throw "The supplied output Method for Request Logging requires a valid ScriptBlock"
    }

    # add the request logger
    $PodeContext.Server.Logging.Types[$name] = @{
        Method = $Method
        ScriptBlock = (Get-PodeLoggingInbuiltType -Type Requests)
        Options = @{
            Raw = $Raw
        }
    }
}

<#
.SYNOPSIS
Disables Request Logging.

.DESCRIPTION
Disables Request Logging.

.EXAMPLE
Disable-PodeRequestLogging
#>
function Disable-PodeRequestLogging
{
    [CmdletBinding()]
    param()

    Remove-PodeLogger -Name (Get-PodeRequestLoggingName)
}

<#
.SYNOPSIS
Enables Error Logging using a supplied output method.

.DESCRIPTION
Enables Error Logging using a supplied output method.

.PARAMETER Method
The Method to use for output the log entry (From New-PodeLoggingMethod).

.PARAMETER Levels
The Levels of errors that should be logged (default is Error).

.PARAMETER Raw
If supplied, the log item returned will be the raw Error item as a hashtable and not a string (for Custom methods).

.EXAMPLE
New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging
#>
function Enable-PodeErrorLogging
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [hashtable]
        $Method,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('Error', 'Warning', 'Informational', 'Verbose', 'Debug')]
        [string[]]
        $Levels = @('Error'),

        [switch]
        $Raw
    )

    $name = Get-PodeErrorLoggingName

    # error if it's already enabled
    if ($PodeContext.Server.Logging.Types.Contains($name)) {
        throw 'Error Logging has already been enabled'
    }

    # ensure the Method contains a scriptblock
    if (Test-IsEmpty $Method.ScriptBlock) {
        throw "The supplied output Method for Error Logging requires a valid ScriptBlock"
    }

    # add the error logger
    $PodeContext.Server.Logging.Types[$name] = @{
        Method = $Method
        ScriptBlock = (Get-PodeLoggingInbuiltType -Type Errors)
        Options = @{
            Raw = $Raw
            Levels = $Levels
        }
    }
}

<#
.SYNOPSIS
Disables Error Logging.

.DESCRIPTION
Disables Error Logging.

.EXAMPLE
Disable-PodeErrorLogging
#>
function Disable-PodeErrorLogging
{
    [CmdletBinding()]
    param()

    Remove-PodeLogger -Name (Get-PodeErrorLoggingName)
}

<#
.SYNOPSIS
Adds a custom Logging method for parsing custom log items.

.DESCRIPTION
Adds a custom Logging method for parsing custom log items.

.PARAMETER Name
A unique Name for the Logging method.

.PARAMETER Method
The Method to use for output the log entry (From New-PodeLoggingMethod).

.PARAMETER ScriptBlock
The ScriptBlock defining logic that transforms an item, and returns it for outputting.

.PARAMETER Options
Any custom Options to supply to the ScriptBlock.

.EXAMPLE
New-PodeLoggingMethod -Terminal | Add-PodeLogger -Name 'Main' -ScriptBlock { /* logic */ }
#>
function Add-PodeLogger
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Name,

        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [hashtable]
        $Method,

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
    if ($PodeContext.Server.Logging.Types.ContainsKey($Name)) {
        throw "Logging method already defined: $($Name)"
    }

    # ensure the Method contains a scriptblock
    if (Test-IsEmpty $Method.ScriptBlock) {
        throw "The supplied output Method for the '$($Name)' Logging method requires a valid ScriptBlock"
    }

    # add logging method to server
    $PodeContext.Server.Logging.Types[$Name] = @{
        Method = $Method
        ScriptBlock = $ScriptBlock
        Options = $Options
    }
}

<#
.SYNOPSIS
Removes a configured Logging method.

.DESCRIPTION
Removes a configured Logging method.

.PARAMETER Name
The Name of the Logging method.

.EXAMPLE
Remove-PodeLogger -Name 'LogName'
#>
function Remove-PodeLogger
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [string]
        $Name
    )

    $PodeContext.Server.Logging.Types.Remove($Name) | Out-Null
}

<#
.SYNOPSIS
Clears all Logging methods that have been configured.

.DESCRIPTION
Clears all Logging methods that have been configured.

.EXAMPLE
Clear-PodeLoggers
#>
function Clear-PodeLoggers
{
    [CmdletBinding()]
    param()

    $PodeContext.Server.Logging.Types.Clear()
}

<#
.SYNOPSIS
Writes and Exception or ErrorRecord using the inbuilt error logging.

.DESCRIPTION
Writes and Exception or ErrorRecord using the inbuilt error logging.

.PARAMETER Exception
An Exception to write.

.PARAMETER ErrorRecord
An ErrorRecord to write.

.PARAMETER Level
The Level of the error being logged.

.EXAMPLE
try { /* logic */ } catch { $_ | Write-PodeErrorLog }

.EXAMPLE
[System.Exception]::new('error message') | Write-PodeErrorLog
#>
function Write-PodeErrorLog
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true, ParameterSetName='Exception')]
        [System.Exception]
        $Exception,

        [Parameter(Mandatory=$true, ValueFromPipeline=$true, ParameterSetName='Error')]
        [System.Management.Automation.ErrorRecord]
        $ErrorRecord,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('Error', 'Warning', 'Informational', 'Verbose', 'Debug')]
        [string]
        $Level = 'Error'
    )

    # do nothing if logging is disabled, or error logging isn't setup
    $name = Get-PodeErrorLoggingName
    if (!(Test-PodeLoggerEnabled -Name $name)) {
        return
    }

    # do nothing if the error level isn't present
    $options = (Get-PodeLogger -Name $name).Options
    if (@($Options.Levels) -inotcontains $Level) {
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

    # add general info
    $item['Server'] = $env:COMPUTERNAME
    $item['Level'] = $Level
    $item['Date'] = [datetime]::Now

    # add the item to be processed
    $PodeContext.LogsToProcess.Add(@{
        Name = $name
        Item = $item
    }) | Out-Null
}

<#
.SYNOPSIS
Write an object to a configured custom Logging method.

.DESCRIPTION
Write an object to a configured custom Logging method.

.PARAMETER Name
The Name of the Logging method.

.PARAMETER InputObject
The Object to write.

.EXAMPLE
$object | Write-PodeLog -Name 'LogName'
#>
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