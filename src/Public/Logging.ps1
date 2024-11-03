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

.PARAMETER EventViewer
If supplied, will use the inbuilt Event Viewer logging output method.

.PARAMETER EventLogName
Optional Log Name for the Event Viewer (Default: Application)

.PARAMETER Source
Optional Source for the Event Viewer (Default: Pode)

.PARAMETER EventID
Optional EventID for the Event Viewer (Default: 0)

.PARAMETER Batch
An optional batch size to write log items in bulk (Default: 1)

.PARAMETER BatchTimeout
An optional batch timeout, in seconds, to send items off for writing if a log item isn't received (Default: 0)

.PARAMETER MaxDays
The maximum number of days to keep logs, before Pode automatically removes them.

.PARAMETER MaxSize
The maximum size of a log file, before Pode starts writing to a new log file.

.PARAMETER Custom
If supplied, will allow you to create a Custom Logging output method.

.PARAMETER ScriptBlock
The ScriptBlock that defines how to output a log item.

.PARAMETER ArgumentList
An array of arguments to supply to the Custom Logging output method's ScriptBlock.

.EXAMPLE
$term_logging = New-PodeLoggingMethod -Terminal

.EXAMPLE
$file_logging = New-PodeLoggingMethod -File -Path ./logs -Name 'requests'

.EXAMPLE
$custom_logging = New-PodeLoggingMethod -Custom -ScriptBlock { /* logic */ }
#>
function New-PodeLoggingMethod {
    [CmdletBinding(DefaultParameterSetName = 'Terminal')]
    [OutputType([hashtable])]
    param(
        [Parameter(ParameterSetName = 'Terminal')]
        [switch]
        $Terminal,

        [Parameter(ParameterSetName = 'File')]
        [switch]
        $File,

        [Parameter(ParameterSetName = 'File')]
        [string]
        $Path = './logs',

        [Parameter(Mandatory = $true, ParameterSetName = 'File')]
        [string]
        $Name,

        [Parameter(ParameterSetName = 'EventViewer')]
        [switch]
        $EventViewer,

        [Parameter(ParameterSetName = 'EventViewer')]
        [string]
        $EventLogName = 'Application',

        [Parameter(ParameterSetName = 'EventViewer')]
        [string]
        $Source = 'Pode',

        [Parameter(ParameterSetName = 'EventViewer')]
        [int]
        $EventID = 0,

        [Parameter()]
        [int]
        $Batch = 1,

        [Parameter()]
        [int]
        $BatchTimeout = 0,

        [Parameter(ParameterSetName = 'File')]
        [ValidateScript({
                if ($_ -lt 0) {
                    # MaxDays must be 0 or greater, but got
                    throw ($PodeLocale.maxDaysInvalidExceptionMessage -f $MaxDays)
                }

                return $true
            })]
        [int]
        $MaxDays = 0,

        [Parameter(ParameterSetName = 'File')]
        [ValidateScript({
                if ($_ -lt 0) {
                    # MaxSize must be 0 or greater, but got
                    throw ($PodeLocale.maxSizeInvalidExceptionMessage -f $MaxSize)
                }

                return $true
            })]
        [int]
        $MaxSize = 0,

        [Parameter(ParameterSetName = 'Custom')]
        [switch]
        $Custom,

        [Parameter(Mandatory = $true, ParameterSetName = 'Custom')]
        [ValidateScript({
                if (Test-PodeIsEmpty $_) {
                    # A non-empty ScriptBlock is required for the Custom logging output method
                    throw ($PodeLocale.nonEmptyScriptBlockRequiredForCustomLoggingExceptionMessage)
                }

                return $true
            })]
        [scriptblock]
        $ScriptBlock,

        [Parameter(ParameterSetName = 'Custom')]
        [object[]]
        $ArgumentList
    )

    # batch details
    $batchInfo = @{
        Size       = $Batch
        Timeout    = $BatchTimeout
        LastUpdate = $null
        Items      = @()
        RawItems   = @()
    }

    # return info on appropriate logging type
    switch ($PSCmdlet.ParameterSetName.ToLowerInvariant()) {
        'terminal' {
            return @{
                ScriptBlock = (Get-PodeLoggingTerminalMethod)
                Batch       = $batchInfo
                Arguments   = @{}
            }
        }

        'file' {
            $Path = (Protect-PodeValue -Value $Path -Default './logs')
            $Path = (Get-PodeRelativePath -Path $Path -JoinRoot)
            $null = New-Item -Path $Path -ItemType Directory -Force

            return @{
                ScriptBlock = (Get-PodeLoggingFileMethod)
                Batch       = $batchInfo
                Arguments   = @{
                    Name          = $Name
                    Path          = $Path
                    MaxDays       = $MaxDays
                    MaxSize       = $MaxSize
                    FileId        = 0
                    Date          = $null
                    NextClearDown = [datetime]::Now.Date
                }
            }
        }

        'eventviewer' {
            # only windows
            if (!(Test-PodeIsWindows)) {
                # Event Viewer logging only supported on Windows
                throw ($PodeLocale.eventViewerLoggingSupportedOnWindowsOnlyExceptionMessage)
            }

            # create source
            if (![System.Diagnostics.EventLog]::SourceExists($Source)) {
                $null = [System.Diagnostics.EventLog]::CreateEventSource($Source, $EventLogName)
            }

            return @{
                ScriptBlock = (Get-PodeLoggingEventViewerMethod)
                Batch       = $batchInfo
                Arguments   = @{
                    LogName = $EventLogName
                    Source  = $Source
                    ID      = $EventID
                }
            }
        }

        'custom' {
            $ScriptBlock, $usingVars = Convert-PodeScopedVariables -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState

            return @{
                ScriptBlock    = $ScriptBlock
                UsingVariables = $usingVars
                Batch          = $batchInfo
                Arguments      = $ArgumentList
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

.PARAMETER UsernameProperty
An optional property path within the $WebEvent.Auth.User object for the user's Username. (Default: Username).

.PARAMETER Raw
If supplied, the log item returned will be the raw Request item as a hashtable and not a string (for Custom methods).

.EXAMPLE
New-PodeLoggingMethod -Terminal | Enable-PodeRequestLogging
#>
function Enable-PodeRequestLogging {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [hashtable]
        $Method,

        [Parameter()]
        [string]
        $UsernameProperty,

        [switch]
        $Raw
    )

    Test-PodeIsServerless -FunctionName 'Enable-PodeRequestLogging' -ThrowError

    $name = Get-PodeRequestLoggingName

    # error if it's already enabled
    if ($PodeContext.Server.Logging.Types.Contains($name)) {
        # Request Logging has already been enabled
        throw ($PodeLocale.requestLoggingAlreadyEnabledExceptionMessage)
    }

    # ensure the Method contains a scriptblock
    if (Test-PodeIsEmpty $Method.ScriptBlock) {
        # The supplied output Method for Request Logging requires a valid ScriptBlock
        throw ($PodeLocale.loggingMethodRequiresValidScriptBlockExceptionMessage -f 'Request')
    }

    # username property
    if ([string]::IsNullOrWhiteSpace($UsernameProperty)) {
        $UsernameProperty = 'Username'
    }

    # add the request logger
    $PodeContext.Server.Logging.Types[$name] = @{
        Method      = $Method
        ScriptBlock = (Get-PodeLoggingInbuiltType -Type Requests)
        Properties  = @{
            Username = $UsernameProperty
        }
        Arguments   = @{
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
function Disable-PodeRequestLogging {
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
function Enable-PodeErrorLogging {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [hashtable]
        $Method,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('Error', 'Warning', 'Informational', 'Verbose', 'Debug', '*')]
        [string[]]
        $Levels = @('Error'),

        [switch]
        $Raw
    )

    $name = Get-PodeErrorLoggingName

    # error if it's already enabled
    if ($PodeContext.Server.Logging.Types.Contains($name)) {
        # Error Logging has already been enabled
        throw ($PodeLocale.errorLoggingAlreadyEnabledExceptionMessage)
    }

    # ensure the Method contains a scriptblock
    if (Test-PodeIsEmpty $Method.ScriptBlock) {
        # The supplied output Method for Error Logging requires a valid ScriptBlock
        throw ($PodeLocale.loggingMethodRequiresValidScriptBlockExceptionMessage -f 'Error')
    }

    # all errors?
    if ($Levels -contains '*') {
        $Levels = @('Error', 'Warning', 'Informational', 'Verbose', 'Debug')
    }

    # add the error logger
    $PodeContext.Server.Logging.Types[$name] = @{
        Method      = $Method
        ScriptBlock = (Get-PodeLoggingInbuiltType -Type Errors)
        Arguments   = @{
            Raw    = $Raw
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
function Disable-PodeErrorLogging {
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

.PARAMETER ArgumentList
An array of arguments to supply to the Custom Logger's ScriptBlock.

.EXAMPLE
New-PodeLoggingMethod -Terminal | Add-PodeLogger -Name 'Main' -ScriptBlock { /* logic */ }
#>
function Add-PodeLogger {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [hashtable]
        $Method,

        [Parameter(Mandatory = $true)]
        [ValidateScript({
                if (Test-PodeIsEmpty $_) {
                    # A non-empty ScriptBlock is required for the logging method
                    throw ($PodeLocale.nonEmptyScriptBlockRequiredForLoggingMethodExceptionMessage)
                }

                return $true
            })]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [object[]]
        $ArgumentList
    )

    # ensure the name doesn't already exist
    if ($PodeContext.Server.Logging.Types.ContainsKey($Name)) {
        # Logging method already defined
        throw ($PodeLocale.loggingMethodAlreadyDefinedExceptionMessage -f $Name)
    }

    # ensure the Method contains a scriptblock
    if (Test-PodeIsEmpty $Method.ScriptBlock) {
        # The supplied output Method for the Logging method requires a valid ScriptBlock
        throw ($PodeLocale.loggingMethodRequiresValidScriptBlockExceptionMessage -f $Name)
    }

    # check for scoped vars
    $ScriptBlock, $usingVars = Convert-PodeScopedVariables -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState

    # add logging method to server
    $PodeContext.Server.Logging.Types[$Name] = @{
        Method         = $Method
        ScriptBlock    = $ScriptBlock
        UsingVariables = $usingVars
        Arguments      = $ArgumentList
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
function Remove-PodeLogger {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]
        $Name
    )

    $null = $PodeContext.Server.Logging.Types.Remove($Name)
}

<#
.SYNOPSIS
Clears all Logging methods that have been configured.

.DESCRIPTION
Clears all Logging methods that have been configured.

.EXAMPLE
Clear-PodeLoggers
#>
function Clear-PodeLoggers {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
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

.PARAMETER CheckInnerException
If supplied, any exceptions are check for inner exceptions. If one is present, this is also logged.

.EXAMPLE
try { /* logic */ } catch { $_ | Write-PodeErrorLog }

.EXAMPLE
[System.Exception]::new('error message') | Write-PodeErrorLog
#>
function Write-PodeErrorLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = 'Exception')]
        [System.Exception]
        $Exception,

        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = 'Error')]
        [System.Management.Automation.ErrorRecord]
        $ErrorRecord,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('Error', 'Warning', 'Informational', 'Verbose', 'Debug')]
        [string]
        $Level = 'Error',

        [Parameter(ParameterSetName = 'Exception')]
        [switch]
        $CheckInnerException
    )

    # do nothing if logging is disabled, or error logging isn't setup
    $name = Get-PodeErrorLoggingName
    if (!(Test-PodeLoggerEnabled -Name $name)) {
        return
    }

    # do nothing if the error level isn't present
    $levels = @(Get-PodeErrorLoggingLevel)
    if ($levels -inotcontains $Level) {
        return
    }

    # build error object for what we need
    switch ($PSCmdlet.ParameterSetName.ToLowerInvariant()) {
        'exception' {
            $item = @{
                Category   = $Exception.Source
                Message    = $Exception.Message
                StackTrace = $Exception.StackTrace
            }
        }

        'error' {
            $item = @{
                Category   = $ErrorRecord.CategoryInfo.ToString()
                Message    = $ErrorRecord.Exception.Message
                StackTrace = $ErrorRecord.ScriptStackTrace
            }
        }
    }

    # add general info
    $item['Server'] = $PodeContext.Server.ComputerName
    $item['Level'] = $Level
    $item['Date'] = [datetime]::Now
    $item['ThreadId'] = [int]$ThreadId

    # add the item to be processed
    $null = $PodeContext.LogsToProcess.Add(@{
            Name = $name
            Item = $item
        })

    # for exceptions, check the inner exception
    if ($CheckInnerException -and ($null -ne $Exception.InnerException) -and ![string]::IsNullOrWhiteSpace($Exception.InnerException.Message)) {
        $Exception.InnerException | Write-PodeErrorLog
    }
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
function Write-PodeLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [object]
        $InputObject
    )

    # do nothing if logging is disabled, or logger isn't setup
    if (!(Test-PodeLoggerEnabled -Name $Name)) {
        return
    }

    # add the item to be processed
    $null = $PodeContext.LogsToProcess.Add(@{
            Name = $Name
            Item = $InputObject
        })
}

<#
.SYNOPSIS
Masks values within a log item to protect sensitive information.

.DESCRIPTION
Masks values within a log item, or any string, to protect sensitive information.
Patterns, and the Mask, can be configured via the server.psd1 configuration file.

.PARAMETER Item
The string Item to mask values.

.EXAMPLE
$value = Protect-PodeLogItem -Item 'Username=Morty, Password=Hunter2'
#>
function Protect-PodeLogItem {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(ValueFromPipeline = $true)]
        [string]
        $Item
    )

    # do nothing if there are no masks
    if (Test-PodeIsEmpty $PodeContext.Server.Logging.Masking.Patterns) {
        return $item
    }

    # attempt to apply each mask
    foreach ($mask in $PodeContext.Server.Logging.Masking.Patterns) {
        if ($Item -imatch $mask) {
            # has both keep before/after
            if ($Matches.ContainsKey('keep_before') -and $Matches.ContainsKey('keep_after')) {
                $Item = ($Item -ireplace $mask, "`${keep_before}$($PodeContext.Server.Logging.Masking.Mask)`${keep_after}")
            }

            # has just keep before
            elseif ($Matches.ContainsKey('keep_before')) {
                $Item = ($Item -ireplace $mask, "`${keep_before}$($PodeContext.Server.Logging.Masking.Mask)")
            }

            # has just keep after
            elseif ($Matches.ContainsKey('keep_after')) {
                $Item = ($Item -ireplace $mask, "$($PodeContext.Server.Logging.Masking.Mask)`${keep_after}")
            }

            # normal mask
            else {
                $Item = ($Item -ireplace $mask, $PodeContext.Server.Logging.Masking.Mask)
            }
        }
    }

    return $Item
}

<#
.SYNOPSIS
Automatically loads logging ps1 files

.DESCRIPTION
Automatically loads logging ps1 files from either a /logging folder, or a custom folder. Saves space dot-sourcing them all one-by-one.

.PARAMETER Path
Optional Path to a folder containing ps1 files, can be relative or literal.

.EXAMPLE
Use-PodeLogging

.EXAMPLE
Use-PodeLogging -Path './my-logging'
#>
function Use-PodeLogging {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Path
    )

    Use-PodeFolder -Path $Path -DefaultPath 'logging'
}