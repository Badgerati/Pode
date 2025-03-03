


<#
.SYNOPSIS
    Creates a new method for outputting logs (Deprecated).

.DESCRIPTION
    This function has been deprecated and will be removed in future versions. It creates various logging methods such as Terminal, File, Event Viewer, and Custom logging.
    Please use the appropriate new functions for each logging method:
    - `New-PodeTerminalLoggingMethod` for terminal logging.
    - `New-PodeFileLoggingMethod` for file logging.
    - `New-PodeEventViewerLoggingMethod` for Event Viewer logging.
    - `New-PodeCustomLoggingMethod` for custom logging.

.PARAMETER Terminal
    Deprecated. Please use `New-PodeTerminalLoggingMethod` instead.
    If supplied, will use the inbuilt Terminal logging output method.

.PARAMETER File
    Deprecated. Please use `New-PodeFileLoggingMethod` instead.
    If supplied, will use the inbuilt File logging output method.

.PARAMETER EventViewer
    Deprecated. Please use `New-PodeEventViewerLoggingMethod` instead.
    If supplied, will use the inbuilt Event Viewer logging output method.


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


    # return info on appropriate logging type
    switch ($PSCmdlet.ParameterSetName.ToLowerInvariant()) {
        'terminal' {
            # WARNING: Function `New-PodeLoggingMethod` is deprecated. Please use '{0}' function instead.
            Write-PodeHost ($PodeLocale.deprecatedFunctionWarningMessage -f 'New-PodeLoggingMethod', 'New-PodeTerminalLoggingMethod')  -ForegroundColor Yellow

            return New-PodeTerminalLoggingMethod
        }

        'file' {
            # WARNING: Function `New-PodeLoggingMethod` is deprecated. Please use '{0}' function instead.
            Write-PodeHost ($PodeLocale.deprecatedFunctionWarningMessage -f 'New-PodeLoggingMethod', 'New-PodeFileLoggingMethod')  -ForegroundColor Yellow

            $fileParams = @{
                Path    = $PSBoundParameters['Path']
                Name    = $PSBoundParameters['Name']
                MaxDays = $PSBoundParameters['MaxDays']
                MaxSize = $PSBoundParameters['MaxSize']
            }
            return New-PodeFileLoggingMethod @fileParams
        }

        'eventviewer' {
            # WARNING: Function `New-PodeLoggingMethod` is deprecated. Please use '{0}' function instead.
            Write-PodeHost ($PodeLocale.deprecatedFunctionWarningMessage -f 'New-PodeLoggingMethod', 'New-PodeEventViewerLoggingMethod')  -ForegroundColor Yellow

            $eventViewerParams = @{
                EventLogName = $PSBoundParameters['EventLogName']
                Source       = $PSBoundParameters['Source']
                EventID      = $PSBoundParameters['EventID']
            }
            return New-PodeEventViewerLoggingMethod @eventViewerParams
        }

        'custom' {
            # WARNING: Function `New-PodeLoggingMethod` is deprecated. Please use '{0}' function instead.
            Write-PodeHost ($PodeLocale.deprecatedFunctionWarningMessage -f 'New-PodeLoggingMethod', 'New-PodeCustomLoggingMethod')  -ForegroundColor Yellow

            # Convert scoped variables for the script block if not using a runspace
            $ScriptBlock, $usingVars = Convert-PodeScopedVariables -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState

            return @{
                Id             = New-PodeGuid
                ScriptBlock    = $ScriptBlock
                UsingVariables = $usingVars
                Batch          = New-PodeLogBatchInfo
                Logger         = @()
                Arguments      = $ArgumentList
                NoRunspace     = $true
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
    If supplied, the log item returned will be the raw Request item as a hashtable and not a string.

.PARAMETER LogFormat
    The format to use for the log entries. Options are: Extended, Common, Combined, JSON (Default: Combined).

.EXAMPLE
    New-PodeLoggingMethod -Terminal | Enable-PodeRequestLogging
#>
function Enable-PodeRequestLogging {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [hashtable[]]
        $Method,

        [Parameter()]
        [string]
        $UsernameProperty,

        [switch]
        $Raw,

        [string]
        [ValidateSet('Extended', 'Common', 'Combined', 'JSON' )]
        $LogFormat = 'Combined'
    )
    begin {
        $pipelineMethods = @()

        Test-PodeIsServerless -FunctionName 'Enable-PodeRequestLogging' -ThrowError

        $name = [Pode.PodeLogger]::RequestLogName

        # error if it's already enabled
        if ($PodeContext.Server.Logging.Type.Contains($name)) {
            # Request Logging has already been enabled
            throw ($PodeLocale.loggingAlreadyEnabledExceptionMessage -f 'Request')
        }

        # username property
        if ([string]::IsNullOrWhiteSpace($UsernameProperty)) {
            $UsernameProperty = 'Username'
        }
    }
    process {
        # ensure the Method contains a scriptblock
        if ((! $PodeContext.Server.Logging.Method.ContainsKey($_.Id)) -and (! $_.ContainsKey('Scriptblock'))) {
            # The supplied output Method for Request Logging requires a valid ScriptBlock
            throw ($PodeLocale.loggingMethodRequiresValidScriptBlockExceptionMessage -f 'Request')
        }
        $pipelineMethods += $_
    }
    end {

        if ($pipelineMethods.Count -gt 1) {
            $Method = $pipelineMethods
        }

        # add the request logger
        $PodeContext.Server.Logging.Type[$name] = @{
            Method      = $Method
            ScriptBlock = (Get-PodeLoggingInbuiltType -Type Requests)
            Properties  = @{
                Username = $UsernameProperty
            }
            Arguments   = @{
                Raw        = $Raw.IsPresent
                DataFormat = $Method.Arguments.DataFormat
                LogFormat  = $LogFormat
            }
            Standard    = $true
        }

        $Method.ForEach({ $_.Logger += $name })
    }
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

.PARAMETER DisableDefaultLog
    If supplied, the error logs will NOT be duplicated to the default logging method.

.EXAMPLE
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging
#>
function Enable-PodeErrorLogging {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [hashtable[]]
        $Method,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('Error', 'Emergency', 'Alert', 'Critical', 'Warning', 'Notice', 'Informational', 'Verbose', 'Debug', '*')]
        [string[]]
        $Levels = @('Error'),

        [switch]
        $Raw,

        [switch]
        $DisableDefaultLog
    )

    begin {
        $pipelineMethods = @()
    }

    process {
        # ensure the Method contains a scriptblock
        if ((! $PodeContext.Server.Logging.Method.ContainsKey($_.Id)) -and (! $_.ContainsKey('Scriptblock'))) {
            # The supplied output Method for Error Logging requires a valid ScriptBlock
            throw ($PodeLocale.loggingMethodRequiresValidScriptBlockExceptionMessage -f 'Error')
        }
        $pipelineMethods += $_
    }

    end {

        if ($pipelineMethods.Count -gt 1) {
            $Method = $pipelineMethods
        }

        $logging = Enable-PodeLoggingInternal -Method $Method -Type Errors -Levels $Levels -Raw:$Raw


        $logging.DuplicateToDefaultLog = ! $DisableDefaultLog.IsPresent
        $Method.ForEach({ $_.Logger += $name })
    }
}

<#
.SYNOPSIS
    Enables Default Logging using a supplied output method.

.DESCRIPTION
    Enables Default Logging using a supplied output method.

.PARAMETER Method
    The Method to use for output the log entry (From New-PodeLoggingMethod).

.PARAMETER Levels
    The Levels that should be logged (default is 'Error', 'Emergency', 'Alert', 'Critical', 'Warning', 'Notice', 'Informational').

.PARAMETER Raw
    If supplied, the log item returned will be the raw Default item as a hashtable and not a string (for Custom methods).

.EXAMPLE
    New-PodeLoggingMethod -Terminal | Enable-PodeDefaultLogging
#>
function Enable-PodeDefaultLogging {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [hashtable[]]
        $Method,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('Error', 'Emergency', 'Alert', 'Critical', 'Warning', 'Notice', 'Informational', 'Verbose', 'Debug', '*')]
        [string[]]
        $Levels = @('Error', 'Emergency', 'Alert', 'Critical', 'Warning', 'Notice', 'Informational'),

        [switch]
        $Raw
    )

    begin {
        $pipelineMethods = @()
    }

    process {
        # ensure the Method contains a scriptblock
        if ((! $PodeContext.Server.Logging.Method.ContainsKey($_.Id)) -and (! $_.ContainsKey('Scriptblock'))) {
            # The supplied output Method for Error Logging requires a valid ScriptBlock
            throw ($PodeLocale.loggingMethodRequiresValidScriptBlockExceptionMessage -f 'Error')
        }
        $pipelineMethods += $_
    }

    end {

        if ($pipelineMethods.Count -gt 1) {
            $Method = $pipelineMethods
        }
        Enable-PodeLoggingInternal -Method $Method -Type Default -Levels $Levels -Raw:$Raw
        $Method.ForEach({ $_.Logger += $name })
    }
}
<#
.SYNOPSIS
    Enables a generic logging method in Pode.

.DESCRIPTION
    This function enables a generic logging method in Pode, allowing logs to be written based on the defined method and log levels. It ensures the method is not already enabled and validates the provided script block.

.PARAMETER Method
    The hashtable defining the logging method, including the ScriptBlock for log output.

.PARAMETER Levels
    An array of log levels to be enabled for the logging method (Default: 'Error', 'Emergency', 'Alert', 'Critical', 'Warning', 'Notice', 'Informational', 'Info', 'Verbose', 'Debug').

.PARAMETER Name
    The name of the logging method to be enabled.

.PARAMETER Raw
    If set, the raw log data will be included in the logging output.

.EXAMPLE
    $method = New-PodeLoggingMethod -syslog -Server 127.0.0.1 -Transport UDP
    $method | Add-PodeLoggingMethod -Name "mysyslog"
#>
function Add-PodeLoggingMethod {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [hashtable[]]
        $Method,

        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('Error', 'Emergency', 'Alert', 'Critical', 'Warning', 'Notice', 'Informational', 'Verbose', 'Debug', '*')]
        [string[]]
        $Levels = @('Error', 'Emergency', 'Alert', 'Critical', 'Warning', 'Notice', 'Informational'),

        [switch]
        $Raw
    )
    begin {
        $pipelineMethods = @()
        # error if it's already enabled
        if ($PodeContext.Server.Logging.Type.Contains($Name)) {
            throw ($PodeLocale.loggingAlreadyEnabledExceptionMessage -f $Name)
        }

        if ($Levels -contains '*') {
            $Levels = @('Error', 'Emergency', 'Alert', 'Critical', 'Warning', 'Notice', 'Informational', 'Info', 'Verbose', 'Debug')
        }

    }

    process {
        # ensure the Method contains a scriptblock
        if ((! $PodeContext.Server.Logging.Method.ContainsKey($_.Id)) -and (! $_.ContainsKey('Scriptblock'))) {
            # The supplied output Method for the '{0}' Logging method requires a valid ScriptBlock.
            throw ($PodeLocale.loggingMethodRequiresValidScriptBlockExceptionMessage -f $Name)
        }
        $pipelineMethods += $_
    }
    end {

        if ($pipelineMethods.Count -gt 1) {
            $Method = $pipelineMethods
        }

        # add the error logger
        $PodeContext.Server.Logging.Type[$Name] = @{
            Method      = $Method
            ScriptBlock = (Get-PodeLoggingInbuiltType -Type General)
            Arguments   = @{
                Raw        = $Raw.IsPresent
                Levels     = $Levels
                DataFormat = $Method.Arguments.DataFormat
            }
            Standard    = $true
        }

        $Method.ForEach({ $_.Logger += $Name })
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

    Remove-PodeLogger -Name ([Pode.PodeLogger]::RequestLogName)
}

<#
.SYNOPSIS
    Disables a generic logging method in Pode.

.DESCRIPTION
    This function disables a generic logging method in Pode.

.PARAMETER Name
    The name of the logging method to be disable.

.EXAMPLE
    Remove-PodeLoggingMethod -Name 'TestLog'
#>
function Remove-PodeLoggingMethod {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    Remove-PodeLogger -Name $Name
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

    Remove-PodeLogger -Name ([Pode.PodeLogger]::ErrorLogName)

}


<#
.SYNOPSIS
Disables Default Logging.

.DESCRIPTION
Disables Default Logging.

.EXAMPLE
Disable-PodeDefaultLogging
#>
function Disable-PodeDefaultLogging {
    [CmdletBinding()]
    param()

    Remove-PodeLogger -Name ([Pode.PodeLogger]::DefaultLogName)

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
    New-PodeLoggingMethod -Terminal | Add-PodeLogger -Name 'Default' -ScriptBlock { /* logic */ }
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

    Begin {
        $pipelineItemCount = 0
    }

    Process {
        $pipelineItemCount++
    }

    End {
        if ($pipelineItemCount -gt 1) {
            throw ($PodeLocale.fnDoesNotAcceptArrayAsPipelineInputExceptionMessage -f $($MyInvocation.MyCommand.Name))
        }

        # ensure the name doesn't already exist
        if ($PodeContext.Server.Logging.Type.ContainsKey($Name)) {
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
        $PodeContext.Server.Logging.Type[$Name] = @{
            Method         = $Method
            ScriptBlock    = $ScriptBlock
            UsingVariables = $usingVars
            Arguments      = $ArgumentList
        }
    }
}

<#
.SYNOPSIS
    Removes a configured Logging method.

.DESCRIPTION
    Removes a configured Logging method by its name.
    This function handles the removal of the logging method and ensures that any associated runspaces and script blocks are properly disposed of if they are no longer in use.

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
    Process {

        # Check if the specified logging type exists
        if ($PodeContext.Server.Logging.Type.Contains($Name)) {
            # Retrieve the method associated with the logging type
            $method = $PodeContext.Server.Logging.Type[$Name].Method
            # If it's not a legacy method remove the runspace
            if (! $method.NoRunspace) {
                # Remove the logger name from the method's logger collection
                if ($method.Logger.Count -eq 1) {
                    $method.Logger = @()
                }
                else {
                    $method.Logger = $method.Logger | Where-Object { $_ -ne $Name }
                }

                # Check if there are no more loggers associated with the method
                if ($method.Logger.Count -eq 0) {
                    # If the method's runspace is still active, stop and dispose of it
                    if ($PodeContext.Server.Logging.Method.ContainsKey($method.Id)) {
                        $PodeContext.Server.Logging.Method[$method.Id].Runspace.Pipeline.Stop()
                        $PodeContext.Server.Logging.Method[$method.Id].Runspace.Pipeline.Dispose()

                        # Decrease the maximum runspaces for the 'logs' pool if applicable
                        $maxRunspaces = $PodeContext.RunspacePools['logs'].Pool.GetMaxRunspaces
                        if ($maxRunspaces -gt 1) {
                            $PodeContext.RunspacePools['logs'].Pool.SetMaxRunspaces($maxRunspaces - 1)
                        }
                        # Remove the method's script block if it exists
                        $PodeContext.Server.Logging.Method.Remove($method.Id)
                    }
                }
            }

            # Finally, remove the logging type from the Types collection
            $null = $PodeContext.Server.Logging.Type.Remove($Name)
        }
        else {
            throw $PodeLocale.loggerDoesNotExistExceptionMessage
        }
    }
}

<#
.SYNOPSIS
Clears all Logging methods that have been configured.

.DESCRIPTION
Clears all Logging methods that have been configured.

.EXAMPLE
Clear-PodeLogger
#>
function Clear-PodeLogger {
    [CmdletBinding()]
    param()

    $PodeContext.Server.Logging.Type.Clear()
}

# Create the alias for back compatibility
if (!(Test-Path Alias:Clear-PodeLoggers)) {
    New-Alias Clear-PodeLoggers -Value  Clear-PodeLogger
}

<#
.SYNOPSIS
    Logs an Exception, ErrorRecord, or a custom error message using Pode's built-in logging mechanism.

.DESCRIPTION
    This function logs exceptions, error records, or custom error messages with optional error categories and levels. It can also log inner exceptions and associate the error with a specific thread ID. Error levels can be set, and inner exceptions can be checked for more detailed logging.

.PARAMETER Exception
    The exception object to log. This is used when logging caught exceptions.

.PARAMETER ErrorRecord
    The error record to log. This is used when handling errors through PowerShell's error handling mechanism.

.PARAMETER Level
    The logging level for the error. Supported levels are: Error, Warning, Informational, Verbose, Debug (Default: Error).

.PARAMETER CheckInnerException
    If specified, logs any inner exceptions associated with the provided exception.

.PARAMETER ThreadId
    The ID of the thread where the error occurred. If not specified, the current thread's ID is used.

.PARAMETER Tag
    A string that identifies the source application, service, or process generating the log message.
    The tag helps distinguish log messages from different sources, making it easier to filter and analyze logs. Default is '-'.

.PARAMETER SuppressDefaultLog
    A switch to suppress writing the error to the default log.

.EXAMPLE
    try {
        # Some operation
    } catch {
        $_ | Write-PodeErrorLog
    }

.EXAMPLE
    [System.Exception]::new('Custom error message') | Write-PodeErrorLog -CheckInnerException

#>

function Write-PodeErrorLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = 'Exception')]
        [System.Exception] $Exception,

        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = 'ErrorRecord')]
        [System.Management.Automation.ErrorRecord] $ErrorRecord,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('Error', 'Emergency', 'Alert', 'Critical', 'Warning', 'Notice', 'Informational', 'Info', 'Verbose', 'Debug' )]
        [string] $Level = 'Error',

        [Parameter(ParameterSetName = 'Exception')]
        [switch] $CheckInnerException,

        [Parameter()]
        [int] $ThreadId,

        [string]
        $Tag = '-',

        [Parameter()]
        [switch]
        $SuppressDefaultLog
    )

    Process {
        $name = [Pode.PodeLogger]::ErrorLogName
        if (Test-PodeLoggerEnabled -Name $name) {
            Write-PodeLog @PSBoundParameters -name $name -SuppressErrorLog
            if ($PodeContext.Server.Logging.Type[$name].DuplicateToDefaultLog -and ! $SuppressDefaultLog) {
                Write-PodeLog @PSBoundParameters -name ([Pode.PodeLogger]::DefaultLogName) -SuppressErrorLog
            }
        }
    }
}

<#
.SYNOPSIS
    Writes an object, exception, or custom message to a configured custom or built-in logging method.

.DESCRIPTION
    This function writes an object, custom log message, or exception to a logging method in Pode.
    It supports both custom and built-in logging methods, allowing structured logging with different log levels, messages, tags, and additional details like thread ID.
    The logging method can be used to write errors, warnings, and informational logs in a structured manner, depending on the log level and source of the log.
    Optionally, it can suppress reporting of errors to the error log if the same error is logged.

.PARAMETER Name
    The name of the logging method (e.g., 'Console', 'File', 'Syslog').

.PARAMETER InputObject
    The object to write to the logging method. This is the default parameter set.

.PARAMETER Level
    The log level for the custom logging method (Default: 'Informational'). Log levels include 'Informational', 'Warning', 'Error', etc.

.PARAMETER Message
    The log message for the custom logging method. Required for custom logging.

.PARAMETER Tag
    A string that identifies the source application, service, or process generating the log message.
    The tag helps distinguish log messages from different sources, making it easier to filter and analyze logs. Default is '-'.

.PARAMETER ThreadId
    The ID of the thread where the log entry is generated. If not specified, the current thread ID will be used.

.PARAMETER Exception
    An exception object to log. Required for the 'Exception' parameter set.

.PARAMETER ErrorRecord
    The error record to log. This is used when handling errors through PowerShell's error handling mechanism.

.PARAMETER Category
    The category of the custom error message (Default: NotSpecified).

.PARAMETER CheckInnerException
    If specified, any inner exceptions of the provided exception are also logged.

.PARAMETER SuppressErrorLog
    A switch to suppress writing the error to the error log if it has already been logged by this function. Useful to prevent duplicate error logging.

.EXAMPLE
    $object | Write-PodeLog -Name 'LogName'

.EXAMPLE
    Write-PodeLog -Name 'CustomLog' -Level 'Error' -Message 'An error occurred.'

.EXAMPLE
    try {
        # Some code that throws an exception
    } catch {
        Write-PodeLog -Name 'Syslog' -Exception $_ -SuppressErrorLog
    }
#>
function Write-PodeLog {
    [CmdletBinding(DefaultParameterSetName = 'Message')]
    param(
        [Parameter()]
        [string]
        $Name,

        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = 'InputObject')]
        [psobject]
        $InputObject,

        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = 'Exception')]
        [System.Exception]
        $Exception,

        [Parameter(ParameterSetName = 'Exception')]
        [switch]
        $CheckInnerException,

        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = 'ErrorRecord')]
        [System.Management.Automation.ErrorRecord] $ErrorRecord,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('Error', 'Emergency', 'Alert', 'Critical', 'Warning', 'Notice', 'Informational', 'Info', 'Verbose', 'Debug')]
        [string]
        $Level,

        [Parameter( Mandatory = $true, ParameterSetName = 'Message')]
        [string]
        $Message,

        [Parameter(ParameterSetName = 'ErrorRecord')]
        [Parameter(ParameterSetName = 'Message')]
        [Parameter(ParameterSetName = 'Exception')]
        [Parameter()]
        [string]
        $Tag,

        [Parameter(ParameterSetName = 'InputObject')]
        [Parameter(ParameterSetName = 'Message')]
        [System.Management.Automation.ErrorCategory] $Category = [System.Management.Automation.ErrorCategory]::NotSpecified,

        [Parameter()]
        [int]
        $ThreadId,

        [Parameter()]
        [switch]
        $SuppressErrorLog

    )
    begin {
        if ($null -eq $PodeContext.Server.Logging) {
            Write-Debug 'Pode not yet initialised'
            return
        }

        if (!$Name) {
            $Name = [Pode.PodeLogger]::DefaultLogName
        }

        if (!$PodeContext.Server.Logging.Type.ContainsKey($Name)) {
            throw $PodeLocale.loggerDoesNotExistExceptionMessage
        }
        # Get the configured log method.
        $log = $PodeContext.Server.Logging.Type[$Name]

    }
    Process {
        # Define the log item based on the selected parameter set.
        switch ($PSCmdlet.ParameterSetName.ToLowerInvariant()) {
            'inputobject' {
                if (!$Level) { $Level = 'Informational' } # Default to Informational.
                if ( @(Get-PodeLoggingLevel -Name $Name) -inotcontains $Level) { return } # If the level is not configured, use the

                $logItem = @{
                    Name  = $Name
                    Item  = $InputObject
                    Level = $Level
                }
                break
            }
            'message' {
                if (!$Level) { $Level = 'Informational' } # Default to Informational.
                if ( @(Get-PodeLoggingLevel -Name $Name) -inotcontains $Level) { return } # If the log level is not configured, return.

                $logItem = @{
                    Name = $Name
                    Item = @{
                        Category = $Category.ToString()
                        Level    = $Level
                        Message  = $Message
                        Tag      = $Tag
                    }
                }
                break
            }
            'exception' {
                if (!$Level) { $Level = 'Error' } # Default to Error.
                if ( @(Get-PodeLoggingLevel -Name $Name) -inotcontains $Level) { return } # If the level is not supported, return.

                $logItem = @{
                    Name = $Name
                    Item = @{
                        Level   = $Level
                        Message = $Exception.Message
                        Tag     = $Tag
                    }
                }
                break
            }
            'errorrecord' {
                if (!$Level) { $Level = 'Error' } # Default to Error.
                if ( @(Get-PodeLoggingLevel -Name $Name) -inotcontains $Level) { return } # If the level is not supported, return.

                $logItem = @{
                    Name = $Name
                    Item = @{
                        Level   = $Level
                        Message = $ErrorRecord.Exception.Message
                        Tag     = $Tag
                    }
                }
                break
            }
        }
        if ($log.Standard) {
            # Add server details to the log item.
            $logItem.Item.Server = $PodeContext.Server.ComputerName

            # Add the current date and time (UTC or local) to the log item.
            $logItem.Item.Date = if ($log.Method.Arguments.AsUTC) { [datetime]::UtcNow } else { [datetime]::Now }

            # Set the thread ID if provided, otherwise use the current thread ID.
            $logItem.Item.ThreadId = if ($ThreadId) { $ThreadId } else { [System.Threading.Thread]::CurrentThread.ManagedThreadId }

            # If error logging is not suppressed, log errors or exceptions.
            if ((! $SuppressErrorLog.IsPresent) -and (Test-PodeErrorLoggingEnabled)) {
                if ($PSCmdlet.ParameterSetName.ToLowerInvariant() -eq 'exception') {
                    [Pode.PodeLogger]::Enqueue( @{
                            Name = [Pode.PodeLogger]::ErrorLogName
                            Item = @{
                                Server     = $logItem.Item.Server
                                Level      = $Level
                                Date       = $(if ($PodeContext.Server.Logging.Type[$Name].Method.Arguments.AsUTC) { $logItem.Item.Date.ToUniversalTime() }else { $logItem.Item.Date.ToLocaltime() })
                                Category   = $Exception.Source
                                Message    = $Exception.Message
                                StackTrace = $Exception.StackTrace
                                Tag        = $Tag
                                ThreadId   = $logItem.Item.ThreadId
                            }
                        })

                }
                elseif ($PSCmdlet.ParameterSetName.ToLowerInvariant() -eq 'errorrecord') {
                    [Pode.PodeLogger]::Enqueue( @{
                            Name = [Pode.PodeLogger]::ErrorLogName
                            Item = @{
                                Server     = $logItem.Item.Server
                                Level      = $Level
                                Date       = $(if ($PodeContext.Server.Logging.Type[$Name].Method.Arguments.AsUTC) { $logItem.Item.Date.ToUniversalTime() }else { $logItem.Item.Date.ToLocaltime() })
                                Category   = $ErrorRecord.CategoryInfo.ToString()
                                Message    = $ErrorRecord.Exception.Message
                                StackTrace = $ErrorRecord.ScriptStackTrace
                                Tag        = $Tag
                                ThreadId   = $logItem.Item.ThreadId
                            }
                        })
                }
                elseif ($Level -eq 'Error') {
                    [Pode.PodeLogger]::Enqueue( @{
                            Name = [Pode.PodeLogger]::ErrorLogName
                            Item = @{
                                Server   = $logItem.Item.Server
                                Level    = $Level
                                Date     = $(if ($PodeContext.Server.Logging.Type[$Name].Method.Arguments.AsUTC) { $logItem.Item.Date.ToUniversalTime() }else { $logItem.Item.Date.ToLocaltime() })
                                Category = $Category.ToString()
                                Message  = $Message
                                Tag      = $Tag
                                ThreadId = $logItem.Item.ThreadId
                            }
                        })
                }
            }
        }

        # Enqueue the log item for processing.
        [Pode.PodeLogger]::Enqueue($logItem)
    }
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

    Process {

        return ([pode.PodeLogger]::ProtectLogItem($Item, $PodeContext.Server.Logging.Masking))
    }
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
    Enables logging in Pode.

.DESCRIPTION
    This function enables logging in Pode by setting the appropriate flags in the Pode context.

.PARAMETER Terminal
    A switch parameter that, if specified, enables terminal logging for the Pode C# listener.

.EXAMPLE
    Enable-PodeLog
    This example enables all logging except terminal logging.

.EXAMPLE
    Enable-PodeLog -Terminal
    This example enables all logging including terminal logging for the Pode C# listener.
#>
function Enable-PodeLog {
    param(
        [switch]
        $Terminal
    )

    # Enable Pode logging
    [pode.PodeLogger]::Enabled = $true
    $PodeContext.Server.Logging.Enabled = $true

    # Enable terminal logging for the Pode C# listener if the Terminal switch is specified
    [pode.PodeLogger]::Terminal = $Terminal.IsPresent
}


<#
.SYNOPSIS
    Disables logging in Pode.

.DESCRIPTION
    This function disables logging in Pode by setting the appropriate flags in the Pode context.
    It allows you to optionally keep terminal logging enabled.

.PARAMETER KeepTerminal
    A switch parameter that, if specified, keeps terminal logging enabled for the Pode C# listener even when other logging is disabled.

.EXAMPLE
    Disable-PodeLog
    This example disables all logging including terminal logging.

.EXAMPLE
    Disable-PodeLog -KeepTerminal
    This example disables all logging except terminal logging.
#>
function Disable-PodeLog {
    param(
        [switch]
        $KeepTerminal
    )

    # Disable Pode logging
    [pode.PodeLogger]::Enabled = $false
    $PodeContext.Server.Logging.Enabled = $false

    # Optionally disable terminal logging if the KeepTerminal switch is not specified
    if (! $KeepTerminal.IsPresent) {
        [pode.PodeLogger]::Terminal = $false
    }
}



<#
.SYNOPSIS
    Clears the Pode logging.

.DESCRIPTION
    This function clears all the logs in Pode by calling the Clear method on the PodeLogger class.

.EXAMPLE
    Clear-PodeLogging
#>
function Clear-PodeLogging {
    $PodeContext.Server.Logging.Type.Clear()
    $PodeContext.Server.Logging.Method.Clear()
    [pode.PodeLogger]::Clear()
}

<#
.SYNOPSIS
    Retrieves the logging levels for a specified Pode logger.

.DESCRIPTION
    The `Get-PodeLoggingLevel` function takes the name of a logger and returns its associated logging levels. This function verifies whether the logger exists before attempting to retrieve its levels.

.PARAMETER Name
    The name of the logger for which to retrieve the logging levels. This parameter is mandatory.

.OUTPUTS
    An array of strings representing the logging levels of the specified Pode logger. If the logger does not exist, an empty array is returned.

.EXAMPLE
    Get-PodeLoggingLevel -Name 'FileLogger'

    This command retrieves the logging levels for the logger named 'FileLogger'.
#>
function Get-PodeLoggingLevel {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    if (Test-PodeLoggerEnabled -Name $Name) {
        return (Get-PodeLogger -Name $Name).Arguments.Levels
    }
    return @()
}