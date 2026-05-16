<#
.SYNOPSIS
Create a new method of outputting logs.

.DESCRIPTION
This function has been deprecated and will be removed in future versions. It creates various logging methods for outputting logs.
Please use the appropriate new functions for each logging method:
- New-PodeLogTerminalMethod
- New-PodeLogFileMethod
- New-PodeLogEventViewerMethod
- New-PodeLogCustomMethod

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
        [ValidateRange(0, [int]::MaxValue)]
        [int]
        $MaxDays = 0,

        [Parameter(ParameterSetName = 'File')]
        [ValidateRange(0, [int]::MaxValue)]
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
    $batchInfo = New-PodeLogBatchInfo -Size $Batch -Timeout $BatchTimeout

    # return info on appropriate logging type
    switch ($PSCmdlet.ParameterSetName.ToLowerInvariant()) {
        'terminal' {
            # WARNING: Function `New-PodeLoggingMethod` is deprecated.
            Write-PodeHost ($PodeLocale.deprecatedFunctionWarningMessage -f 'New-PodeLoggingMethod', 'New-PodeLogTerminalMethod')  -ForegroundColor Yellow

            return New-PodeLogTerminalMethod -BatchInfo $batchInfo
        }

        'file' {
            # WARNING: Function `New-PodeLoggingMethod` is deprecated.
            Write-PodeHost ($PodeLocale.deprecatedFunctionWarningMessage -f 'New-PodeLoggingMethod', 'New-PodeLogFileMethod')  -ForegroundColor Yellow

            return New-PodeLogFileMethod -Name $Name -Path $Path -MaxDays $MaxDays -MaxSize $MaxSize -BatchInfo $batchInfo
        }

        'eventviewer' {
            # WARNING: Function `New-PodeLoggingMethod` is deprecated.
            Write-PodeHost ($PodeLocale.deprecatedFunctionWarningMessage -f 'New-PodeLoggingMethod', 'New-PodeLogEventViewerMethod')  -ForegroundColor Yellow

            return New-PodeLogEventViewerMethod -EventLogName $EventLogName -Source $Source -EventID $EventID -BatchInfo $batchInfo
        }

        'custom' {
            # WARNING: Function `New-PodeLoggingMethod` is deprecated.
            Write-PodeHost ($PodeLocale.deprecatedFunctionWarningMessage -f 'New-PodeLoggingMethod', 'New-PodeLogCustomMethod')  -ForegroundColor Yellow

            return New-PodeLogCustomMethod -ScriptBlock $ScriptBlock -ArgumentList $ArgumentList -BatchInfo $batchInfo
        }
    }
}

<#
.SYNOPSIS
Enables Request Logging using a supplied output method.

.DESCRIPTION
Enables Request Logging using a supplied output method.

.PARAMETER Method
The logging Method to use for output the log entry.

.PARAMETER UsernameProperty
An optional property path within the $WebEvent.Auth.User object for the user's Username. (Default: Username).

.PARAMETER Raw
If supplied, the log item returned will be the raw Request item as a hashtable and not a string (for Custom methods).

.EXAMPLE
New-PodeLogTerminalMethod | Enable-PodeRequestLogging
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
The logging Method to use for output the log entry.

.PARAMETER Levels
The Levels of errors that should be logged (default is Error).

.PARAMETER Raw
If supplied, the log item returned will be the raw Error item as a hashtable and not a string (for Custom methods).

.EXAMPLE
New-PodeLogTerminalMethod | Enable-PodeErrorLogging
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
Adds a custom Logging type for parsing custom log items.

.DESCRIPTION
Adds a custom Logging type for parsing custom log items.

.PARAMETER Name
A unique Name for the Log type.

.PARAMETER Method
The logging Method to use for outputting the log entry.

.PARAMETER ScriptBlock
The ScriptBlock defining logic that transforms an item, and returns it for outputting.

.PARAMETER ArgumentList
An array of arguments to supply to the Custom Log type's ScriptBlock.

.EXAMPLE
New-PodeLogTerminalMethod | Add-PodeLogType -Name 'LogTypeName' -ScriptBlock { /* logic */ }
#>
function Add-PodeLogType {
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

if (!(Test-Path Alias:Add-PodeLogger)) {
    New-Alias Add-PodeLogger -Value Add-PodeLogType
}

<#
.SYNOPSIS
Removes a configured Logging method.

.DESCRIPTION
Removes a configured Logging method.

.PARAMETER Name
The Name of the Logging type to remove.

.EXAMPLE
Remove-PodeLogger -Name 'LogTypeName'
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
The Name of the Logging type to use.

.PARAMETER InputObject
The Object to write.

.EXAMPLE
$object | Write-PodeLog -Name 'LogTypeName'
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

<#
.SYNOPSIS
Create a new batch info object for logging.

.DESCRIPTION
Creates a new batch info object for logging, which can be used to configure batch processing of log items.

.PARAMETER Size
The number of log items to process in a single batch. (Default: 1)

.PARAMETER Timeout
The maximum amount of time, in seconds, to wait before processing a batch of log items. (Default: 0, which means no timeout)

.EXAMPLE
$batchInfo = New-PodeLogBatchInfo -Size 10 -Timeout 10
#>
function New-PodeLogBatchInfo {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter()]
        [int]
        $Size = 1,

        [Parameter()]
        [int]
        $Timeout = 0
    )

    return @{
        Size    = $Size
        Timeout = $Timeout
    }
}

<#
.SYNOPSIS
Create a new Terminal logging Method.

.DESCRIPTION
Creates a new Terminal logging Method for outputting log items to the terminal.
Can be used with Enable-PodeRequestLogging, Enable-PodeErrorLogging, or Add-PodeLogType.

.PARAMETER BatchInfo
An optional hashtable containing batch configuration for writing log items in bulk.
Should be created using New-PodeLogBatchInfo.

.EXAMPLE
$method = New-PodeLogTerminalMethod

.EXAMPLE
$batchInfo = New-PodeLogBatchInfo -Size 10 -Timeout 10
$method = New-PodeLogTerminalMethod -BatchInfo $batchInfo
#>
function New-PodeLogTerminalMethod {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter()]
        [hashtable]
        $BatchInfo = $null
    )

    return @{
        ScriptBlock = Get-PodeLoggingTerminalMethod
        Batch       = $BatchInfo | New-PodeLogBatchConfig
        Arguments   = @{}
    }
}

<#
.SYNOPSIS
Create a new File logging Method.

.DESCRIPTION
Creates a new File logging Method for outputting log items to files.
Can be used with Enable-PodeRequestLogging, Enable-PodeErrorLogging, or Add-PodeLogType.

.PARAMETER Name
The File Name to prepend new log files using.

.PARAMETER Path
The File Path of where to store the logs.

.PARAMETER BatchInfo
An optional hashtable containing batch configuration for writing log items in bulk.
Should be created using New-PodeLogBatchInfo.

.PARAMETER MaxDays
The maximum number of days to keep logs, before Pode automatically removes them.

.PARAMETER MaxSize
The maximum size of a log file, before Pode starts writing to a new log file.

.EXAMPLE
$method = New-PodeLogFileMethod -Name 'requests'

.EXAMPLE
$batchInfo = New-PodeLogBatchInfo -Size 10 -Timeout 10
$method = New-PodeLogFileMethod -Name 'requests' -BatchInfo $batchInfo -MaxDays 7 -MaxSize 10MB
#>
function New-PodeLogFileMethod {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $Path = './logs',

        [Parameter()]
        [ValidateRange(0, [int]::MaxValue)]
        [int]
        $MaxDays = 0,

        [Parameter()]
        [ValidateRange(0, [int]::MaxValue)]
        [int]
        $MaxSize = 0,

        [Parameter()]
        [hashtable]
        $BatchInfo = $null
    )

    # resolve path and ensure it exists
    $Path = Get-PodeRelativePath -Path $Path -JoinRoot
    $null = New-Item -Path $Path -ItemType Directory -Force

    return @{
        ScriptBlock = Get-PodeLoggingFileMethod
        Batch       = $BatchInfo | New-PodeLogBatchConfig
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

<#
.SYNOPSIS
Create a new Event Viewer logging Method.

.DESCRIPTION
Creates a new Event Viewer logging Method for outputting log items to the Windows Event Viewer.
Can be used with Enable-PodeRequestLogging, Enable-PodeErrorLogging, or Add-PodeLogType.

.PARAMETER EventLogName
An Optional Log Name for the Event Viewer (Default: Application)

.PARAMETER Source
An Optional Source for the Event Viewer (Default: Pode)

.PARAMETER EventID
An Optional EventID for the Event Viewer (Default: 0)

.PARAMETER BatchInfo
An optional hashtable containing batch configuration for writing log items in bulk.
Should be created using New-PodeLogBatchInfo.

.EXAMPLE
$method = New-PodeLogEventViewerMethod

.EXAMPLE
$batchInfo = New-PodeLogBatchInfo -Size 10 -Timeout 10
$method = New-PodeLogEventViewerMethod -EventLogName 'MyLog' -Source 'MyApp' -EventID 1001 -BatchInfo $batchInfo
#>
function New-PodeLogEventViewerMethod {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter()]
        [string]
        $EventLogName = 'Application',

        [Parameter()]
        [string]
        $Source = 'Pode',

        [Parameter()]
        [int]
        $EventID = 0,

        [Parameter()]
        [hashtable]
        $BatchInfo = $null
    )

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
        ScriptBlock = Get-PodeLoggingEventViewerMethod
        Batch       = $BatchInfo | New-PodeLogBatchConfig
        Arguments   = @{
            LogName = $EventLogName
            Source  = $Source
            ID      = $EventID
        }
    }
}

<#
.SYNOPSIS
Create a new Custom logging Method.

.DESCRIPTION
Creates a new Custom logging Method for outputting log items using custom logic defined in a ScriptBlock.
Can be used with Enable-PodeRequestLogging, Enable-PodeErrorLogging, or Add-PodeLogType.

.PARAMETER ScriptBlock
The ScriptBlock that defines how to output a log item.

.PARAMETER ArgumentList
An array of arguments to supply to the Custom Logging output method's ScriptBlock.

.EXAMPLE
$method = New-PodeLogCustomMethod -ScriptBlock { /* logic */ }

.EXAMPLE
$arguments = @('arg1', 'arg2')
$method = New-PodeLogCustomMethod -ScriptBlock { param($args) /* logic using $args */ } -ArgumentList $arguments

.EXAMPLE
$batchInfo = New-PodeLogBatchInfo -Size 10 -Timeout 10
$method = New-PodeLogCustomMethod -ScriptBlock { /* logic */ } -BatchInfo $batchInfo
#>
function New-PodeLogCustomMethod {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({
                if (Test-PodeIsEmpty $_) {
                    # A non-empty ScriptBlock is required for the Custom logging output method
                    throw ($PodeLocale.nonEmptyScriptBlockRequiredForCustomLoggingExceptionMessage)
                }

                return $true
            })]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [object[]]
        $ArgumentList,

        [Parameter()]
        [hashtable]
        $BatchInfo = $null
    )

    $ScriptBlock, $usingVars = Convert-PodeScopedVariables -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState

    return @{
        ScriptBlock    = $ScriptBlock
        UsingVariables = $usingVars
        Batch          = $BatchInfo | New-PodeLogBatchConfig
        Arguments      = $ArgumentList
    }
}