using namespace Pode.Utilities.Logging

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

.PARAMETER Id
An optional ID to assign to the logging method. If not supplied, a random ID will be generated.

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
$term_logging_id = New-PodeLoggingMethod -Terminal

.EXAMPLE
$file_logging_id = New-PodeLoggingMethod -File -Path ./logs -Name 'requests'

.EXAMPLE
$custom_logging_id = New-PodeLoggingMethod -Custom -ScriptBlock { /* logic */ }
#>
function New-PodeLoggingMethod {
    [CmdletBinding(DefaultParameterSetName = 'Terminal')]
    [OutputType([string])]
    param(
        [Parameter()]
        [string]
        $Id,

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

            return New-PodeLogTerminalMethod -Id $Id -BatchInfo $batchInfo
        }

        'file' {
            # WARNING: Function `New-PodeLoggingMethod` is deprecated.
            Write-PodeHost ($PodeLocale.deprecatedFunctionWarningMessage -f 'New-PodeLoggingMethod', 'New-PodeLogFileMethod')  -ForegroundColor Yellow

            return New-PodeLogFileMethod -Id $Id -Name $Name -Path $Path -MaxDays $MaxDays -MaxSize $MaxSize -BatchInfo $batchInfo
        }

        'eventviewer' {
            # WARNING: Function `New-PodeLoggingMethod` is deprecated.
            Write-PodeHost ($PodeLocale.deprecatedFunctionWarningMessage -f 'New-PodeLoggingMethod', 'New-PodeLogEventViewerMethod')  -ForegroundColor Yellow

            return New-PodeLogEventViewerMethod -Id $Id -EventLogName $EventLogName -Source $Source -EventID $EventID -BatchInfo $batchInfo
        }

        'custom' {
            # WARNING: Function `New-PodeLoggingMethod` is deprecated.
            Write-PodeHost ($PodeLocale.deprecatedFunctionWarningMessage -f 'New-PodeLoggingMethod', 'New-PodeLogCustomMethod')  -ForegroundColor Yellow

            return New-PodeLogCustomMethod -Id $Id -ScriptBlock $ScriptBlock -ArgumentList $ArgumentList -BatchInfo $batchInfo
        }
    }
}

<#
.SYNOPSIS
Enables Request Logging using a supplied output method.

.DESCRIPTION
Enables Request Logging using a supplied output method.

.PARAMETER Method
One or more logging Method IDs to use for outputting the log entry.

.PARAMETER UsernameProperty
An optional property path within the $WebEvent.Auth.User object for the user's Username. (Default: Username).

.PARAMETER LogFormat
The format to use for the log output. (Default: Server default, or 'None' if no default set).

.PARAMETER SerialiseFormat
Specifies the format to use for serialising the log entry. (Default: Server default, or 'Custom' if no default set, or 'None' if Raw is supplied).

.PARAMETER SerialiseScriptBlock
A ScriptBlock to use for custom serialisation of the log entry.

.PARAMETER ScriptBlock
A ScriptBlock to use for custom data selection and transforming of the log entry. (Default: inbuilt logic).

.PARAMETER ArgumentList
An array of arguments to supply to the Custom Log type's ScriptBlock and SerialiseScriptBlock.

.PARAMETER SyslogInfo
A hashtable containing Syslog configuration information, built using New-PodeSyslogInfo.

.PARAMETER Raw
If supplied, the log item returned will be the raw Request item as a hashtable and not a string (for Custom methods).

.EXAMPLE
New-PodeLogTerminalMethod | Enable-PodeRequestLogType

.EXAMPLE
New-PodeLogTerminalMethod | Enable-PodeRequestLogType -SerialiseFormat 'Json'

.EXAMPLE
New-PodeLogTerminalMethod | Enable-PodeRequestLogType -SerialiseFormat 'Custom' -SerialiseScriptBlock {
    param($data)
    return "$($data.Host) $($data.Identifier) $($data.User) [$($data.Date)] `"$($data.RequestLine)`" $($data.StatusCode) $($data.Size) `"$($data.Referrer)`" `"$($data.UserAgent)`""
}

.EXAMPLE
New-PodeLogTerminalMethod | Enable-PodeRequestLogType -ScriptBlock {
    param($logEvent)
    return @{
        HttpMethod = $logEvent.Data.HttpMethod
    }
}

.EXAMPLE
$syslogInfo = New-PodeLogSyslogInfo -Format RFC3164
New-PodeLogTerminalMethod | Enable-PodeRequestLogType -LogFormat Syslog -SyslogInfo $syslogInfo
#>
function Enable-PodeRequestLogType {
    [CmdletBinding(DefaultParameterSetName = 'ScriptBlock')]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string[]]
        $Method,

        [Parameter()]
        [string]
        $UsernameProperty,

        [Parameter()]
        [Pode.Utilities.Logging.PodeLogFormat]
        $LogFormat = 'None',

        [Parameter()]
        [Pode.Utilities.Logging.PodeSerialiseFormat]
        $SerialiseFormat = 'Custom',

        [Parameter()]
        [scriptblock]
        $SerialiseScriptBlock,

        [Parameter(ParameterSetName = 'ScriptBlock')]
        [scriptblock]
        $ScriptBlock,

        [Parameter(ParameterSetName = 'ScriptBlock')]
        [object[]]
        $ArgumentList,

        [Parameter()]
        [hashtable]
        $SyslogInfo,

        [Parameter(ParameterSetName = 'Raw')]
        [switch]
        $Raw
    )

    begin {
        # error if it's already enabled
        $name = [PodeLogger]::REQUEST_LOG_TYPE_NAME
        if ($PodeContext.Server.Logging.Types.Contains($name)) {
            # Request Logging has already been enabled
            throw ($PodeLocale.requestLoggingAlreadyEnabledExceptionMessage)
        }

        # setup array for log methods being piped in
        $pipelineMethods = @()
    }

    process {
        # ensure the Method exists
        if (!(Test-PodeLogMethod -Id $_)) {
            # The supplied logging Method for Request Logging doesn't exist
            throw ($PodeLocale.loggingMethodDoesNotExistExceptionMessage -f $_)
        }

        # add to pipeline methods array
        $pipelineMethods += $_
    }

    end {
        # multiple methods from pipeline?
        if ($pipelineMethods.Length -gt 1) {
            $Method = $pipelineMethods
        }

        # username property
        if ([string]::IsNullOrWhiteSpace($UsernameProperty)) {
            $UsernameProperty = 'Username'
        }

        # default formatters
        if (!$PSBoundParameters.ContainsKey('LogFormat')) {
            $LogFormat = Protect-PodeValue -Value (Get-PodeLogDefaultFormat) -Default $LogFormat -EnumType ([PodeLogFormat])
        }

        if (!$PSBoundParameters.ContainsKey('SerialiseFormat')) {
            $defSerialiseFormat = Get-PodeLogDefaultSerialiseFormat
            if (($null -eq $defSerialiseFormat) -and $Raw) {
                $defSerialiseFormat = 'None'
            }

            $SerialiseFormat = Protect-PodeValue -Value $defSerialiseFormat -Default $SerialiseFormat -EnumType ([PodeSerialiseFormat])
        }

        # are we using a custom scriptblock for the request log type, or the inbuilt one?
        if ($null -eq $ScriptBlock) {
            $ScriptBlock = Get-PodeLoggingInbuiltType -Type Requests
        }
        else {
            $ScriptBlock, $usingVars = Convert-PodeScopedVariables -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState
        }

        # do we need default syslog info?
        if (($LogFormat -eq [PodeLogFormat]::Syslog) -and ($null -eq $SyslogInfo)) {
            $SyslogInfo = New-PodeLogSyslogInfo
        }

        # are we using a custom scriptblock for serialising the request log type, or the inbuilt one?
        if ($SerialiseFormat -eq [PodeSerialiseFormat]::Custom) {
            # use inbuilt serialise logic if no custom serialise scriptblock supplied
            if ($null -eq $SerialiseScriptBlock) {
                $SerialiseScriptBlock = {
                    param($data)
                    return "$($data.Host) $($data.Identifier) $($data.User) [$($data.Date)] `"$($data.RequestLine)`" $($data.StatusCode) $($data.Size) `"$($data.Referrer)`" `"$($data.UserAgent)`""
                }
            }

            if ($null -ne $SerialiseScriptBlock) {
                $SerialiseScriptBlock, $serialiseUsingVars = Convert-PodeScopedVariables -ScriptBlock $SerialiseScriptBlock -PSSession $PSCmdlet.SessionState
            }
        }

        # add the request log type, associated with the supplied log method(s)
        $PodeContext.Server.Logging.Types[$name] = @{
            Method         = $Method
            ScriptBlock    = $ScriptBlock
            UsingVariables = $usingVars
            Raw            = $Raw.IsPresent
            Version        = 2
            Properties     = @{
                Username = $UsernameProperty
            }
            Options        = @{
                Formatting = @{
                    Log        = $LogFormat
                    SyslogInfo = $SyslogInfo
                    Serialise  = @{
                        Type           = $SerialiseFormat
                        ScriptBlock    = $SerialiseScriptBlock
                        UsingVariables = $serialiseUsingVars
                        XmlRootName    = 'Request'
                    }
                }
            }
            Arguments      = $ArgumentList
        }
        $PodeContext.Server.Logging.Logger.RegisterType([PodeLogType]::new($name, @([PodeLogLevel]::Informational)))

        # then associate the supplied log method(s) with the request log type
        foreach ($methodId in $Method) {
            Register-PodeLogTypeToMethod -TypeName $name -MethodId $methodId
        }
    }
}

if (!(Test-Path Alias:Enable-PodeRequestLogging)) {
    New-Alias Enable-PodeRequestLogging -Value Enable-PodeRequestLogType
}

<#
.SYNOPSIS
Disables Request log Type.

.DESCRIPTION
Disables Request log Type.

.EXAMPLE
Disable-PodeRequestLogType
#>
function Disable-PodeRequestLogType {
    [CmdletBinding()]
    param()

    Remove-PodeLogType -Name ([PodeLogger]::REQUEST_LOG_TYPE_NAME)
}

if (!(Test-Path Alias:Disable-PodeRequestLogging)) {
    New-Alias Disable-PodeRequestLogging -Value Disable-PodeRequestLogType
}

<#
.SYNOPSIS
Enables Error log Type using a supplied log Method.

.DESCRIPTION
Enables Error log Type using a supplied log Method.

.PARAMETER Method
One or more log Method IDs to use for outputting the log entry.

.PARAMETER Levels
The Levels of errors that should be logged (Default: Emergency, Alert, Critical, Error)

.PARAMETER LogFormat
The format to use for the log output. (Default: Server default, or 'None' if no default set).

.PARAMETER SerialiseFormat
Specifies the format to use for serialising the log entry. (Default: Server default, or 'Custom' if no default set, or 'None' if Raw is supplied).

.PARAMETER SerialiseScriptBlock
A ScriptBlock to use for custom serialisation of the log entry.

.PARAMETER ScriptBlock
A ScriptBlock to use for custom data selection and transforming of the log entry. (Default: inbuilt logic).

.PARAMETER ArgumentList
An array of arguments to supply to the Custom Log type's ScriptBlock and SerialiseScriptBlock.

.PARAMETER SyslogInfo
A hashtable containing Syslog configuration information, built using New-PodeSyslogInfo.

.PARAMETER Raw
If supplied, the log item returned will be the raw Error item as a hashtable and not a string (for Custom methods).

.EXAMPLE
New-PodeLogTerminalMethod | Enable-PodeErrorLogType

.EXAMPLE
New-PodeLogTerminalMethod | Enable-PodeErrorLogType -SerialiseFormat 'Json'

.EXAMPLE
New-PodeLogTerminalMethod | Enable-PodeErrorLogType -SerialiseFormat 'Custom' -SerialiseScriptBlock {
    param($data)
    return $data | ConvertTo-PodeString
}

.EXAMPLE
New-PodeLogTerminalMethod | Enable-PodeErrorLogType -ScriptBlock {
    param($logEvent)
    return @{
        StackTrace = $logEvent.Data.StackTrace
    }
}

.EXAMPLE
$syslogInfo = New-PodeLogSyslogInfo -Format RFC3164
New-PodeLogTerminalMethod | Enable-PodeErrorLogType -LogFormat Syslog -SyslogInfo $syslogInfo
#>
function Enable-PodeErrorLogType {
    [CmdletBinding(DefaultParameterSetName = 'ScriptBlock')]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string[]]
        $Method,

        [Parameter()]
        [ValidateSet('Emergency', 'Alert', 'Critical', 'Error', 'Warning', 'Notice', 'Informational', 'Verbose', 'Debug', '*')]
        [string[]]
        $Levels = @('Emergency', 'Alert', 'Critical', 'Error'),

        [Parameter()]
        [Pode.Utilities.Logging.PodeLogFormat]
        $LogFormat = 'None',

        [Parameter()]
        [Pode.Utilities.Logging.PodeSerialiseFormat]
        $SerialiseFormat = 'Custom',

        [Parameter()]
        [scriptblock]
        $SerialiseScriptBlock,

        [Parameter(ParameterSetName = 'ScriptBlock')]
        [scriptblock]
        $ScriptBlock,

        [Parameter(ParameterSetName = 'ScriptBlock')]
        [object[]]
        $ArgumentList,

        [Parameter()]
        [hashtable]
        $SyslogInfo,

        [Parameter(ParameterSetName = 'Raw')]
        [switch]
        $Raw
    )

    begin {
        # error if it's already enabled
        $name = [PodeLogger]::ERROR_LOG_TYPE_NAME
        if ($PodeContext.Server.Logging.Types.Contains($name)) {
            # Error Logging has already been enabled
            throw ($PodeLocale.errorLoggingAlreadyEnabledExceptionMessage)
        }

        # setup array for log methods being piped in
        $pipelineMethods = @()
    }

    process {
        # ensure the Method exists
        if (!(Test-PodeLogMethod -Id $_)) {
            # The supplied logging Method for Error Logging doesn't exist
            throw ($PodeLocale.loggingMethodDoesNotExistExceptionMessage -f $_)
        }

        # add to pipeline methods array
        $pipelineMethods += $_
    }

    end {
        # multiple methods from pipeline?
        if ($pipelineMethods.Length -gt 1) {
            $Method = $pipelineMethods
        }

        # all errors?
        if ($Levels -contains '*') {
            $Levels = @('Emergency', 'Alert', 'Critical', 'Error', 'Warning', 'Notice', 'Informational', 'Verbose', 'Debug')
        }

        # default formatters
        if (!$PSBoundParameters.ContainsKey('LogFormat')) {
            $LogFormat = Protect-PodeValue -Value (Get-PodeLogDefaultFormat) -Default $LogFormat -EnumType ([PodeLogFormat])
        }

        if (!$PSBoundParameters.ContainsKey('SerialiseFormat')) {
            $defSerialiseFormat = Get-PodeLogDefaultSerialiseFormat
            if (($null -eq $defSerialiseFormat) -and $Raw) {
                $defSerialiseFormat = 'None'
            }

            $SerialiseFormat = Protect-PodeValue -Value $defSerialiseFormat -Default $SerialiseFormat -EnumType ([PodeSerialiseFormat])
        }

        # are we using a custom scriptblock for the error log type, or the inbuilt one?
        if ($null -eq $ScriptBlock) {
            $ScriptBlock = Get-PodeLoggingInbuiltType -Type Errors
        }
        else {
            $ScriptBlock, $usingVars = Convert-PodeScopedVariables -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState
        }

        # do we need default syslog info?
        if (($LogFormat -eq [PodeLogFormat]::Syslog) -and ($null -eq $SyslogInfo)) {
            $SyslogInfo = New-PodeLogSyslogInfo
        }

        # are we using a custom scriptblock for serialising the error log type, or the inbuilt one?
        if ($SerialiseFormat -eq [PodeSerialiseFormat]::Custom) {
            # use inbuilt serialise logic if no custom serialise scriptblock supplied
            if ($null -eq $SerialiseScriptBlock) {
                $SerialiseScriptBlock = {
                    param($data)
                    $msg = @(foreach ($key in $data.Keys) {
                            "$($key): $($data[$key])"
                        }) -join "`n"

                    return "$($msg)`n"
                }
            }

            if ($null -ne $SerialiseScriptBlock) {
                $SerialiseScriptBlock, $serialiseUsingVars = Convert-PodeScopedVariables -ScriptBlock $SerialiseScriptBlock -PSSession $PSCmdlet.SessionState
            }
        }

        # add the error log type, associated with the supplied log method(s)
        $PodeContext.Server.Logging.Types[$name] = @{
            Method         = $Method
            ScriptBlock    = $ScriptBlock
            UsingVariables = $usingVars
            Levels         = $Levels
            Raw            = $Raw.IsPresent
            Version        = 2
            Options        = @{
                Formatting = @{
                    Log        = $LogFormat
                    SyslogInfo = $SyslogInfo
                    Serialise  = @{
                        Type           = $SerialiseFormat
                        ScriptBlock    = $SerialiseScriptBlock
                        UsingVariables = $serialiseUsingVars
                        XmlRootName    = 'Error'
                    }
                }
            }
            Arguments      = $ArgumentList
        }
        $PodeContext.Server.Logging.Logger.RegisterType([PodeLogType]::new($name, $Levels))

        # then associate the supplied log method(s) with the error log type
        foreach ($methodId in $Method) {
            Register-PodeLogTypeToMethod -TypeName $name -MethodId $methodId
        }
    }
}

if (!(Test-Path Alias:Enable-PodeErrorLogging)) {
    New-Alias Enable-PodeErrorLogging -Value Enable-PodeErrorLogType
}

<#
.SYNOPSIS
Disables Error log Type.

.DESCRIPTION
Disables Error log Type.

.EXAMPLE
Disable-PodeErrorLogType
#>
function Disable-PodeErrorLogType {
    [CmdletBinding()]
    param()

    Remove-PodeLogType -Name ([PodeLogger]::ERROR_LOG_TYPE_NAME)
}

if (!(Test-Path Alias:Disable-PodeErrorLogging)) {
    New-Alias Disable-PodeErrorLogging -Value Disable-PodeErrorLogType
}

<#
.SYNOPSIS
Adds a custom Logging type for parsing custom log items.

.DESCRIPTION
Adds a custom Logging type for parsing custom log items.

.PARAMETER Name
A unique Name for the Log type.

.PARAMETER Method
The logging Method ID to use for outputting the log entry.

.PARAMETER ScriptBlock
The ScriptBlock defining logic that transforms an item, and returns it for outputting.

.PARAMETER Levels
The Levels of log items that should be logged. (Default: Informational)

.PARAMETER ArgumentList
An array of arguments to supply to the Custom Log type's ScriptBlock and SerialiseScriptBlock.

.PARAMETER Version
The version of the log type, this determines the arguments which are supplied to the ScriptBlock. (Default: 1)
Arguments supplied depending on the version:

- Version 1: Log Event Data, ArgumentList
- Version 2: Log Event, ArgumentList

Under Version 2, the "Log Event" contains references to the log event's data, level, timestamp, and metadata.

.PARAMETER LogFormat
The format to use for the log output. (Default: Server default, or 'None' if no default set).

.PARAMETER SerialiseFormat
Specifies the format to use for serialising the log entry. (Default: Server default, or 'None' if no default set).

.PARAMETER SerialiseScriptBlock
A ScriptBlock defining custom logic for serialising the log data.

.PARAMETER SyslogInfo
A hashtable containing Syslog configuration information, built using New-PodeSyslogInfo.

.PARAMETER XmlRootName
An optional name to use for the root element of the log item when serialising to XML.

.PARAMETER Raw
If supplied, the log item returned will be the raw Request item as a hashtable and not a string.

.EXAMPLE
New-PodeLogTerminalMethod | Add-PodeLogType -Name 'LogTypeName' -ScriptBlock { /* logic */ }

.EXAMPLE
New-PodeLogTerminalMethod | Add-PodeLogType -Name 'LogTypeName' -Raw

.EXAMPLE
New-PodeLogTerminalMethod | Add-PodeLogType -Name 'LogTypeName' -SerialiseFormat 'Json'

.EXAMPLE
New-PodeLogTerminalMethod | Add-PodeLogType -Name 'LogTypeName' -SerialiseFormat 'Custom' -SerialiseScriptBlock {
    param($data)
    return $data | ConvertTo-PodeString
}
#>
function Add-PodeLogType {
    [CmdletBinding(DefaultParameterSetName = 'ScriptBlock')]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string[]]
        $Method,

        [Parameter(Mandatory = $true, ParameterSetName = 'ScriptBlock')]
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
        [ValidateSet('Emergency', 'Alert', 'Critical', 'Error', 'Warning', 'Notice', 'Informational', 'Verbose', 'Debug', '*')]
        [string[]]
        $Levels = @('Informational'),

        [Parameter(ParameterSetName = 'ScriptBlock')]
        [object[]]
        $ArgumentList,

        [Parameter(ParameterSetName = 'ScriptBlock')]
        [ValidateSet(1, 2)]
        [int]
        $Version = 1,

        [Parameter()]
        [Pode.Utilities.Logging.PodeLogFormat]
        $LogFormat = 'None',

        [Parameter()]
        [Pode.Utilities.Logging.PodeSerialiseFormat]
        $SerialiseFormat = 'None',

        [Parameter()]
        [scriptblock]
        $SerialiseScriptBlock,

        [Parameter()]
        [hashtable]
        $SyslogInfo,

        [Parameter()]
        [string]
        $XmlRootName,

        [Parameter(ParameterSetName = 'Raw')]
        [switch]
        $Raw
    )

    begin {
        # ensure the name doesn't already exist
        if ($PodeContext.Server.Logging.Types.ContainsKey($Name)) {
            # Logging method already defined
            throw ($PodeLocale.loggingMethodAlreadyDefinedExceptionMessage -f $Name)
        }

        # setup array for log methods being piped in
        $pipelineMethods = @()
    }

    process {
        # ensure the Method exists
        if (!(Test-PodeLogMethod -Id $_)) {
            # The supplied logging Method for Custom Logging doesn't exist
            throw ($PodeLocale.loggingMethodDoesNotExistExceptionMessage -f $_)
        }

        # add to pipeline methods array
        $pipelineMethods += $_
    }

    end {
        # multiple methods from pipeline?
        if ($pipelineMethods.Length -gt 1) {
            $Method = $pipelineMethods
        }

        # all errors?
        if ($Levels -contains '*') {
            $Levels = @('Emergency', 'Alert', 'Critical', 'Error', 'Warning', 'Notice', 'Informational', 'Verbose', 'Debug')
        }

        # default formatters
        if (!$PSBoundParameters.ContainsKey('LogFormat')) {
            $LogFormat = Protect-PodeValue -Value (Get-PodeLogDefaultFormat) -Default $LogFormat -EnumType ([PodeLogFormat])
        }

        if (!$PSBoundParameters.ContainsKey('SerialiseFormat')) {
            $SerialiseFormat = Protect-PodeValue -Value (Get-PodeLogDefaultSerialiseFormat) -Default $SerialiseFormat -EnumType ([PodeSerialiseFormat])
        }

        # check for scoped vars in scriptblock
        if ($PSCmdlet.ParameterSetName -eq 'ScriptBlock') {
            $ScriptBlock, $usingVars = Convert-PodeScopedVariables -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState
        }

        # do we need default syslog info?
        if (($LogFormat -eq [PodeLogFormat]::Syslog) -and ($null -eq $SyslogInfo)) {
            $SyslogInfo = New-PodeLogSyslogInfo
        }

        # if custom serialisation, ensure we have a scriptblock, and check for scoped vars in scriptblock
        if ($SerialiseFormat -eq [PodeSerialiseFormat]::Custom) {
            if ($null -eq $SerialiseScriptBlock) {
                # A non-empty ScriptBlock is required for the Custom logging serialisation format
                throw ($PodeLocale.nonEmptyScriptBlockRequiredForCustomSerialisationExceptionMessage)
            }

            $SerialiseScriptBlock, $serialiseUsingVars = Convert-PodeScopedVariables -ScriptBlock $SerialiseScriptBlock -PSSession $PSCmdlet.SessionState
        }

        # add custom log method to server, associated with the supplied log method(s)
        $PodeContext.Server.Logging.Types[$Name] = @{
            Custom         = $true
            Method         = $Method
            ScriptBlock    = $ScriptBlock
            UsingVariables = $usingVars
            Levels         = $Levels
            Raw            = $Raw.IsPresent
            Version        = $Version
            Options        = @{
                Formatting = @{
                    Log        = $LogFormat
                    SyslogInfo = $SyslogInfo
                    Serialise  = @{
                        Type           = $SerialiseFormat
                        ScriptBlock    = $SerialiseScriptBlock
                        UsingVariables = $serialiseUsingVars
                        XmlRootName    = Protect-PodeValue -Value $XmlRootName -Default 'Log'
                    }
                }
            }
            Arguments      = $ArgumentList
        }
        $PodeContext.Server.Logging.Logger.RegisterType([PodeLogType]::new($Name, $Levels))

        # then associate the supplied log method(s) with the custom log type
        foreach ($methodId in $Method) {
            Register-PodeLogTypeToMethod -TypeName $Name -MethodId $methodId
        }
    }
}

if (!(Test-Path Alias:Add-PodeLogger)) {
    New-Alias Add-PodeLogger -Value Add-PodeLogType
}

<#
.SYNOPSIS
Removes a configured Log Type.

.DESCRIPTION
Removes a configured Log Type.

.PARAMETER Name
The Name of the Log Type to remove.

.EXAMPLE
Remove-PodeLogType -Name 'LogTypeName'
#>
function Remove-PodeLogType {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]
        $Name
    )

    process {
        # get the log type
        $type = Get-PodeLogType -Name $Name
        if ($null -eq $type) {
            return
        }

        # unregister log type from method
        foreach ($methodId in $type.Method) {
            Unregister-PodeLogTypeFromMethod -TypeName $Name -MethodId $methodId
        }

        # remove the log type
        $null = $PodeContext.Server.Logging.Types.Remove($Name)
        $PodeContext.Server.Logging.Logger.UnregisterType($Name)
    }
}

if (!(Test-Path Alias:Remove-PodeLogger)) {
    New-Alias Remove-PodeLogger -Value Remove-PodeLogType
}

<#
.SYNOPSIS
Removes a configured Log Method.

.DESCRIPTION
Removes a configured Log Method.

.PARAMETER Id
The ID of the Log Method to remove.

.EXAMPLE
Remove-PodeLogMethod -Id '<log-method-id>'
#>
function Remove-PodeLogMethod {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]
        $Id
    )

    process {
        # get the log method
        $method = Get-PodeLogMethod -Id $Id
        if ($null -eq $method) {
            return
        }

        # close the runspace and reduce max count (not below 1)
        $method.Runspace.Pipeline.Stop()
        $method.Runspace.Pipeline.Dispose()

        $maxRunspaces = $PodeContext.RunspacePools.Logs.Pool.GetMaxRunspaces()
        if ($maxRunspaces -gt 1) {
            $PodeContext.RunspacePools.Logs.Pool.SetMaxRunspaces($maxRunspaces - 1)
        }

        # dispose the log method queue
        if ($null -ne $method.Queue) {
            $method.Queue.Dispose()
        }

        # unregister log method from types that reference it
        foreach ($typeName in $method.Types) {
            Unregister-PodeLogMethodFromType -TypeName $typeName -MethodId $Id
        }

        # remove the log method
        $null = $PodeContext.Server.Logging.Methods.Remove($Id)
    }
}

<#
.SYNOPSIS
Clears all Log Types that have been configured.

.DESCRIPTION
Clears all Log Types that have been configured.

.EXAMPLE
Clear-PodeLogTypes
#>
function Clear-PodeLogTypes {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    [CmdletBinding()]
    param()

    $typeNames = $PodeContext.Server.Logging.Types.Keys
    foreach ($typeName in $typeNames) {
        Remove-PodeLogType -Name $typeName
    }
}

if (!(Test-Path Alias:Clear-PodeLoggers)) {
    New-Alias Clear-PodeLoggers -Value Clear-PodeLogTypes
}

<#
.SYNOPSIS
Clears all Log Methods that have been configured.

.DESCRIPTION
Clears all Log Methods that have been configured.

.EXAMPLE
Clear-PodeLogMethods
#>
function Clear-PodeLogMethods {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    [CmdletBinding()]
    param()

    $methodIds = $PodeContext.Server.Logging.Methods.Keys
    foreach ($methodId in $methodIds) {
        Remove-PodeLogMethod -Id $methodId
    }

    # dispose of any log method queues
    foreach ($method in $PodeContext.Server.Logging.Methods.Values) {
        if ($null -ne $method.Queue) {
            $method.Queue.Dispose()
        }
    }
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

.PARAMETER Message
A Message to write.

.PARAMETER Level
The Level of the error being logged. (Default: Error)

.PARAMETER Metadata
An optional hashtable of Metadata to include with the log item.

.PARAMETER CheckInnerException
If supplied, any exceptions are check for inner exceptions. If one is present, this is also logged.

.EXAMPLE
try { /* logic */ } catch { $_ | Write-PodeErrorLog }

.EXAMPLE
[System.Exception]::new('error message') | Write-PodeErrorLog

.EXAMPLE
Write-PodeErrorLog -Message 'error message' -Level 'Warning'
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

        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = 'Message')]
        [string]
        $Message,

        [Parameter()]
        [ValidateSet('Emergency', 'Alert', 'Critical', 'Error', 'Warning', 'Notice', 'Informational', 'Verbose', 'Debug')]
        [string]
        $Level = 'Error',

        [Parameter()]
        [hashtable]
        $Metadata,

        [Parameter(ParameterSetName = 'Exception')]
        [switch]
        $CheckInnerException
    )

    process {
        # do nothing if error logging isn't setup
        if (!$PodeContext.Server.Logging.Logger.IsErrorLoggingEnabled) {
            return
        }

        # attempt to get current contextId
        $contextId = Get-PodeLoggingContextId

        # log error object appropriately based on parameter set
        switch ($PSCmdlet.ParameterSetName) {
            'Exception' {
                $PodeContext.Server.Logging.Logger.AddException($Exception, $contextId, $Level, $Metadata, [int]$ThreadId)
            }

            'Error' {
                $PodeContext.Server.Logging.Logger.AddException($ErrorRecord.CategoryInfo.ToString(), $ErrorRecord.Exception.Message, $ErrorRecord.ScriptStackTrace, $contextId, $Level, $Metadata, [int]$ThreadId)
            }

            'Message' {
                $category = (Get-PSCallStack)[1].Location
                $PodeContext.Server.Logging.Logger.AddException($category, $Message, [string]::Empty, $contextId, $Level, $Metadata, [int]$ThreadId)
            }
        }

        # for exceptions, check the inner exception
        if ($CheckInnerException -and ($null -ne $Exception.InnerException) -and ![string]::IsNullOrWhiteSpace($Exception.InnerException.Message)) {
            $Exception.InnerException | Write-PodeErrorLog
        }
    }
}

<#
.SYNOPSIS
Write an object to a configured custom Logging method.

.DESCRIPTION
Write an object to a configured custom Logging method.

.PARAMETER Name
The Name of the Logging type to use.

.PARAMETER Level
The Level of the log item being logged. (Default: Informational)

.PARAMETER InputObject
The Object to write.

.PARAMETER Metadata
An optional hashtable of Metadata to include with the log item.

.EXAMPLE
$object | Write-PodeLog -Name 'LogTypeName'

.EXAMPLE
$object | Write-PodeLog -Name 'LogTypeName' -Level 'Debug' -Metadata @{ Key = 'Value' }
#>
function Write-PodeLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter()]
        [ValidateSet('Emergency', 'Alert', 'Critical', 'Error', 'Warning', 'Notice', 'Informational', 'Verbose', 'Debug')]
        [string]
        $Level = 'Informational',

        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [object]
        $InputObject,

        [Parameter()]
        [hashtable]
        $Metadata
    )

    process {
        $logEvent = [PodeLogEvent]::new($Name, $Level, $InputObject, $Metadata)
        $PodeContext.Server.Logging.Logger.Add($logEvent)
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

    process {
        # do nothing if there are no masks
        if (($null -eq $PodeContext.Server.Logging.Masking.Patterns) -or ($PodeContext.Server.Logging.Masking.Patterns.Count -eq 0)) {
            return $Item
        }

        # do nothing if the item is null or empty
        if ([string]::IsNullOrWhiteSpace($Item)) {
            return $Item
        }

        # attempt to apply each mask
        foreach ($mask in $PodeContext.Server.Logging.Masking.Patterns) {
            if ($Item -inotmatch $mask) {
                continue
            }

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

        return $Item
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
Can be used with Enable-PodeRequestLogType, Enable-PodeErrorLogType, or Add-PodeLogType.

.PARAMETER Id
An optional ID to assign to the logging method. If not supplied, a random ID will be generated.

.PARAMETER BatchInfo
An optional hashtable containing batch configuration for writing log items in bulk.
Should be created using New-PodeLogBatchInfo.

.EXAMPLE
$methodId = New-PodeLogTerminalMethod

.EXAMPLE
$batchInfo = New-PodeLogBatchInfo -Size 10 -Timeout 10
$methodId = New-PodeLogTerminalMethod -BatchInfo $batchInfo
#>
function New-PodeLogTerminalMethod {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [string]
        $Id,

        [Parameter()]
        [hashtable]
        $BatchInfo = $null
    )

    # add method to server
    return Add-PodeLogMethod -Id $Id -Batch $BatchInfo -Metadata @{
        Type        = 'Terminal'
        ScriptBlock = Get-PodeLoggingTerminalMethod
        Arguments   = @{}
    }
}

<#
.SYNOPSIS
Create a new File logging Method.

.DESCRIPTION
Creates a new File logging Method for outputting log items to files.
Can be used with Enable-PodeRequestLogType, Enable-PodeErrorLogType, or Add-PodeLogType.

.PARAMETER Id
An optional ID to assign to the logging method. If not supplied, a random ID will be generated.

.PARAMETER Name
The File Name to prepend new log files using.

.PARAMETER Path
The File Path of where to store the logs.

.PARAMETER MaxDays
The maximum number of days to keep logs, before Pode automatically removes them.

.PARAMETER MaxSize
The maximum size of a log file, before Pode starts writing to a new log file.

.PARAMETER BatchInfo
An optional hashtable containing batch configuration for writing log items in bulk.
Should be created using New-PodeLogBatchInfo.

.EXAMPLE
$methodId = New-PodeLogFileMethod -Name 'requests'

.EXAMPLE
$batchInfo = New-PodeLogBatchInfo -Size 10 -Timeout 10
$methodId = New-PodeLogFileMethod -Name 'requests' -BatchInfo $batchInfo -MaxDays 7 -MaxSize 10MB
#>
function New-PodeLogFileMethod {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [string]
        $Id,

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

    # add method to server
    return Add-PodeLogMethod -Id $Id -Batch $BatchInfo -Metadata @{
        Type        = 'File'
        ScriptBlock = Get-PodeLoggingFileMethod
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
Can be used with Enable-PodeRequestLogType, Enable-PodeErrorLogType, or Add-PodeLogType.

.PARAMETER Id
An optional ID to assign to the logging method. If not supplied, a random ID will be generated.

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
$methodId = New-PodeLogEventViewerMethod

.EXAMPLE
$batchInfo = New-PodeLogBatchInfo -Size 10 -Timeout 10
$methodId = New-PodeLogEventViewerMethod -EventLogName 'MyLog' -Source 'MyApp' -EventID 1001 -BatchInfo $batchInfo
#>
function New-PodeLogEventViewerMethod {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [string]
        $Id,

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

    # add method to server
    return Add-PodeLogMethod -Id $Id -Batch $BatchInfo -Metadata @{
        Type        = 'EventViewer'
        ScriptBlock = Get-PodeLoggingEventViewerMethod
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
Can be used with Enable-PodeRequestLogType, Enable-PodeErrorLogType, or Add-PodeLogType.

.PARAMETER Id
An optional ID to assign to the logging method. If not supplied, a random ID will be generated.

.PARAMETER ScriptBlock
The ScriptBlock that defines how to output a log item.

.PARAMETER ArgumentList
An array of arguments to supply to the Custom Logging output method's ScriptBlock.

.PARAMETER Version
The version of the log method, this determines the arguments which are supplied to the ScriptBlock. (Default: 1)
Arguments supplied depending on the version:

- Version 1: Transformed Log Items, ArgumentList, Raw Log Items (legacy)
- Version 2: Log Items, ArgumentList

Under Version 2, the "Log Items" contains references to the transformed and raw log items.

.PARAMETER BatchInfo
An optional hashtable containing batch configuration for writing log items in bulk.
Should be created using New-PodeLogBatchInfo.

.EXAMPLE
$method = New-PodeLogCustomMethod -ScriptBlock { /* logic */ }

.EXAMPLE
$arguments = @('arg1', 'arg2')
$methodId = New-PodeLogCustomMethod -ScriptBlock { param($args) /* logic using $args */ } -ArgumentList $arguments

.EXAMPLE
$batchInfo = New-PodeLogBatchInfo -Size 10 -Timeout 10
$methodId = New-PodeLogCustomMethod -ScriptBlock { /* logic */ } -BatchInfo $batchInfo
#>
function New-PodeLogCustomMethod {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [string]
        $Id,

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

        [Parameter(ParameterSetName = 'ScriptBlock')]
        [ValidateSet(1, 2)]
        [int]
        $Version = 1,

        [Parameter()]
        [hashtable]
        $BatchInfo = $null
    )

    # check for scoped vars
    $ScriptBlock, $usingVars = Convert-PodeScopedVariables -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState

    # add method to server
    return Add-PodeLogMethod -Id $Id -Batch $BatchInfo -Metadata @{
        Type        = 'Custom'
        ScriptBlock = Get-PodeLoggingCustomMethod
        Custom      = @{
            ScriptBlock    = $ScriptBlock
            UsingVariables = $usingVars
        }
        Arguments   = $ArgumentList
        Version     = $Version
    }
}

<#
.SYNOPSIS
Creates a new API logging Method.

.DESCRIPTION
Creates a new API logging Method for outputting log items to custom API endpoints.

.PARAMETER Id
An optional ID to assign to the logging method. If not supplied, a random ID will be generated.

.PARAMETER Type
An optional Type to assign to the logging method. (Default: API)

.PARAMETER Url
The URL of the API endpoint to send log items to.

.PARAMETER ContentType
An optional Content-Type header to include in the API request. (Default: application/json)

.PARAMETER Method
An optional HTTP Method to use for the API request. (Default: POST)

.PARAMETER Headers
An optional hashtable of headers to include in the API request, typically used for the Authorization header.

.PARAMETER HeadersScriptBlock
An optional ScriptBlock that returns a hashtable of headers to include in the API request.
Useful for dynamically generating headers based on the request body or other elements.

.PARAMETER HeadersArgumentList
An optional array of arguments to pass to the HeadersScriptBlock.

.PARAMETER BodyScriptBlock
A ScriptBlock that returns the body of the API request as a valid string, based on a collection of log items.
Protect-PodeLogItem will be automatically applied to the returned string.

.PARAMETER BodyArgumentList
An optional array of arguments to pass to the BodyScriptBlock.

.PARAMETER BatchInfo
An optional hashtable containing batch configuration for writing log items in bulk.
Should be created using New-PodeLogBatchInfo.

.PARAMETER SkipCertificateCheck
If supplied, the API request will skip certificate validation checks.

.PARAMETER Compress
If supplied, the API request will include a Content-Encoding: gzip header and compress the request body.

.EXAMPLE
$headers = @{ 'Authorization' = 'Bearer <token>' }
$methodId = New-PodeLogApiMethod -Url 'https://api.example.com/logs' -Headers $headers -Compress -BodyScriptBlock {
    param($logCol)
    return $logCol.Items.Data | ConvertTo-Json -Compress
}
#>
function New-PodeLogApiMethod {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [string]
        $Id,

        [Parameter()]
        [string]
        $Type,

        [Parameter(Mandatory = $true)]
        [string]
        $Url,

        [Parameter()]
        [ValidatePattern('^\w+\/[\w\.\+-]+$')]
        [string]
        $ContentType = 'application/json',

        [Parameter()]
        [ValidateSet('GET', 'POST', 'PUT', 'PATCH')]
        [string]
        $Method = 'POST',

        [Parameter()]
        [hashtable]
        $Headers = @{},

        [Parameter()]
        [scriptblock]
        $HeadersScriptBlock,

        [Parameter()]
        [object[]]
        $HeadersArgumentList,

        [Parameter(Mandatory = $true)]
        [scriptblock]
        $BodyScriptBlock,

        [Parameter()]
        [object[]]
        $BodyArgumentList,

        [Parameter()]
        [hashtable]
        $BatchInfo = $null,

        [switch]
        $SkipCertificateCheck,

        [switch]
        $Compress
    )

    # default type
    if ([string]::IsNullOrWhiteSpace($Type)) {
        $Type = 'API'
    }

    # default headers
    if ($null -eq $Headers) {
        $Headers = @{}
    }

    if ($Compress -and !$Headers.ContainsKey('Content-Encoding')) {
        $Headers['Content-Encoding'] = 'gzip'
    }

    # headers scriptblock + using vars
    if ($null -ne $HeadersScriptBlock) {
        $HeadersScriptBlock, $headerUsingVars = Convert-PodeScopedVariables -ScriptBlock $HeadersScriptBlock -PSSession $PSCmdlet.SessionState
    }

    # body scriptblock + using vars
    if ($null -ne $BodyScriptBlock) {
        $BodyScriptBlock, $bodyUsingVars = Convert-PodeScopedVariables -ScriptBlock $BodyScriptBlock -PSSession $PSCmdlet.SessionState
    }

    # add method to server
    return Add-PodeLogMethod -Id $Id -Batch $BatchInfo -Metadata @{
        Type        = $Type
        ScriptBlock = Get-PodeLoggingApiMethod
        Arguments   = @{
            Url                  = $Url
            ContentType          = $ContentType
            Method               = $Method
            Compress             = $Compress.IsPresent
            Headers              = @{
                Value          = $Headers
                ScriptBlock    = $HeadersScriptBlock
                UsingVariables = $headerUsingVars
                ArgumentList   = $HeadersArgumentList
            }
            Body                 = @{
                ScriptBlock    = $BodyScriptBlock
                UsingVariables = $bodyUsingVars
                ArgumentList   = $BodyArgumentList
            }
            SkipCertificateCheck = $SkipCertificateCheck.IsPresent
        }
    }
}

<#
.SYNOPSIS
Creates a new Splunk log method.

.DESCRIPTION
Creates a new Splunk log method for outputting log items to a Splunk HTTP Event Collector (HEC) endpoint.

.PARAMETER Id
An optional ID to assign to the logging method. If not supplied, a random ID will be generated.

.PARAMETER BaseUrl
The base URL of the Splunk HEC endpoint, e.g., 'https://splunk.example.com:8088'.

.PARAMETER Token
The authentication token for the Splunk HEC endpoint.

.PARAMETER SourceType
An optional source type to include with the log items.

.PARAMETER Source
An optional source to include with the log items. (Default: the server's AppName)

.PARAMETER Index
An optional index to include with the log items.

.PARAMETER BatchInfo
An optional hashtable containing batch configuration for writing log items in bulk.
Should be created using New-PodeLogBatchInfo.

.PARAMETER SkipCertificateCheck
If supplied, the API request will skip certificate validation checks.

.EXAMPLE
$methodId = New-PodeLogSplunkMethod -BaseUrl 'https://splunk.example.com:8088' -Token '<token>' -Source 'my_source'

.EXAMPLE
$batchInfo = New-PodeLogBatchInfo -Size 10 -Timeout 10
$methodId = New-PodeLogSplunkMethod -BaseUrl 'https://splunk.example.com:8088' -Token '<token>' -SourceType 'syslog' -BatchInfo $batchInfo

.EXAMPLE
$methodId = New-PodeLogSplunkMethod -BaseUrl 'https://localhost:8088' -Token '<token>' -SkipCertificateCheck
#>
function New-PodeLogSplunkMethod {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [string]
        $Id,

        [Parameter(Mandatory = $true)]
        [string]
        $BaseUrl,

        [Parameter(Mandatory = $true)]
        [string]
        $Token,

        [Parameter()]
        [string]
        $SourceType,

        [Parameter()]
        [string]
        $Source,

        [Parameter()]
        [string]
        $Index,

        [Parameter()]
        [hashtable]
        $BatchInfo = $null,

        [switch]
        $SkipCertificateCheck
    )

    # default source
    $Source = Protect-PodeValue -Value $Source -Default $PodeContext.Server.AppName

    # build body scriptblock
    $bodyScriptBlock = {
        param($logCol, $sourceType, $source, $index)

        # build array of events
        $events = @(foreach ($item in $logCol.Items) {
                # build base event object
                $evt = @{
                    event  = $item.Data
                    host   = $PodeContext.Server.ComputerName
                    time   = ConvertTo-PodeUnixEpoch -DateTime $item.Event.Timestamp
                    fields = @{
                        severity = ConvertTo-PodeSplunkLevel -Level $item.Event.Level
                    }
                }

                # add source type
                $sourceType = Protect-PodeValue -Value $item.Event.Metadata['SourceType'] -Default $sourceType
                if (![string]::IsNullOrEmpty($sourceType)) {
                    $evt.sourcetype = $sourceType
                }

                # add source
                $source = Protect-PodeValue -Value $item.Event.Metadata['Source'] -Default $source
                if (![string]::IsNullOrEmpty($source)) {
                    $evt.source = $source
                }

                # add index
                $index = Protect-PodeValue -Value $item.Event.Metadata['Index'] -Default $index
                if (![string]::IsNullOrEmpty($index)) {
                    $evt.index = $index
                }

                $evt
            })

        # convert to json and return
        return $events | ConvertTo-Json -Compress -Depth 10
    }

    # default headers
    $headers = @{
        'Authorization' = "Splunk $($Token)"
    }

    # add method to server
    return New-PodeLogApiMethod `
        -Id $Id `
        -Type 'Splunk' `
        -BatchInfo $BatchInfo `
        -Url "$($BaseUrl.TrimEnd('/'))/services/collector" `
        -Headers $headers `
        -BodyScriptBlock $bodyScriptBlock `
        -BodyArgumentList @($SourceType, $Source, $Index) `
        -SkipCertificateCheck:$SkipCertificateCheck.IsPresent `
        -Compress
}

<#
.SYNOPSIS
Creates a new Datadog log method.

.DESCRIPTION
Creates a new Datadog log method for outputting log items to a Datadog's HTTP v2 logging API endpoint.

.PARAMETER Id
An optional ID to assign to the logging method. If not supplied, a random ID will be generated.

.PARAMETER BaseUrl
The base URL of the Datadog API endpoint, e.g., 'https://http-intake.logs.datadoghq.com'.

.PARAMETER ApiKey
The API key used for authenticating with the Datadog API.

.PARAMETER Tags
An optional hashtable of tags to include with the log items.

.PARAMETER Service
An optional service name to include with the log items. (Default: the server's AppName)

.PARAMETER Source
An optional source name to include with the log items.

.PARAMETER BatchInfo
An optional hashtable containing batch configuration for writing log items in bulk.
Should be created using New-PodeLogBatchInfo.

.PARAMETER SkipCertificateCheck
If supplied, the API request will skip certificate validation checks.

.EXAMPLE
$methodId = New-PodeLogDatadogMethod -BaseUrl 'https://http-intake.logs.datadoghq.com' -ApiKey '<api_key>' -Source 'my_source'

.EXAMPLE
$batchInfo = New-PodeLogBatchInfo -Size 10 -Timeout 10
$methodId = New-PodeLogDatadogMethod -BaseUrl 'https://http-intake.logs.datadoghq.eu' -ApiKey '<api_key>' -Tags @{ env = 'prod' } -BatchInfo $batchInfo

.EXAMPLE
$methodId = New-PodeLogDatadogMethod -BaseUrl 'https://http-intake.logs.datadoghq.com' -ApiKey '<api_key>' -Service 'my_service' -Source 'my_source' -SkipCertificateCheck
#>
function New-PodeLogDatadogMethod {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [string]
        $Id,

        [Parameter(Mandatory = $true)]
        [string]
        $BaseUrl,

        [Parameter(Mandatory = $true)]
        [string]
        $ApiKey,

        [Parameter()]
        [hashtable]
        $Tags,

        [Parameter()]
        [string]
        $Service,

        [Parameter()]
        [string]
        $Source,

        [Parameter()]
        [hashtable]
        $BatchInfo = $null,

        [switch]
        $SkipCertificateCheck
    )

    # default service
    $Service = Protect-PodeValue -Value $Service -Default $PodeContext.Server.AppName

    # build body scriptblock
    $bodyScriptBlock = {
        param($logCol, $service, $source, $tags)

        # build array of events
        $events = @(foreach ($item in $logCol.Items) {
                # build base event object
                $evt = @{
                    message   = $item.Data
                    hostname  = $PodeContext.Server.ComputerName
                    status    = ConvertTo-PodeDatadogLevel -Level $item.Event.Level
                    timestamp = $item.Event.Timestamp.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
                }

                # add service
                $service = Protect-PodeValue -Value $item.Event.Metadata['Service'] -Default $service
                if (![string]::IsNullOrEmpty($service)) {
                    $evt.service = $service
                }

                # add source
                $source = Protect-PodeValue -Value $item.Event.Metadata['Source'] -Default $source
                if (![string]::IsNullOrEmpty($source)) {
                    $evt.ddsource = $source
                }

                # add tags
                if ($tags.Count -gt 0) {
                    $evt.ddtags = @(foreach ($key in $tags.Keys) { "$($key):$($tags[$key])" }) -join ','
                }

                $evt
            })

        # convert to json and return
        return $events | ConvertTo-Json -Compress -Depth 10
    }

    # default headers
    $headers = @{
        'DD-API-KEY' = $ApiKey
    }

    # default tags
    if ($null -eq $Tags) {
        $Tags = @{}
    }

    # add method to server
    return New-PodeLogApiMethod `
        -Id $Id `
        -Type 'Datadog' `
        -BatchInfo $BatchInfo `
        -Url "$($BaseUrl.TrimEnd('/'))/api/v2/logs" `
        -Headers $headers `
        -BodyScriptBlock $bodyScriptBlock `
        -BodyArgumentList @($Service, $Source, $Tags) `
        -SkipCertificateCheck:$SkipCertificateCheck.IsPresent `
        -Compress
}

<#
.SYNOPSIS
Creates a new Azure Log Analytics log method.

.DESCRIPTION
Creates a new Azure Log Analytics log method for outputting log items to an Azure Log Analytics workspace.

.PARAMETER Id
An optional ID to assign to the logging method. If not supplied, a random ID will be generated.

.PARAMETER WorkspaceId
The Workspace ID of the Azure Log Analytics workspace.

.PARAMETER SharedKey
The Shared Key of the Azure Log Analytics workspace.

.PARAMETER LogType
The Log Type to use for the log items in Azure Log Analytics, used for the Log-Type header.

.PARAMETER Source
An optional source to include with the log items. (Default: the server's AppName)

.PARAMETER BatchInfo
An optional hashtable containing batch configuration for writing log items in bulk.
Should be created using New-PodeLogBatchInfo.

.PARAMETER SkipCertificateCheck
If supplied, the API request will skip certificate validation checks.

.EXAMPLE
$methodId = New-PodeLogAzureLogAnalyticsMethod -WorkspaceId '<workspace_id>' -SharedKey '<shared_key>' -LogType 'MyCustomLog'

.EXAMPLE
$batchInfo = New-PodeLogBatchInfo -Size 10 -Timeout 10
$methodId = New-PodeLogAzureLogAnalyticsMethod -WorkspaceId '<workspace_id>' -SharedKey '<shared_key>' -LogType 'MyCustomLog' -BatchInfo $batchInfo -Source 'my_source'
#>
function New-PodeLogAzureLogAnalyticsMethod {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [string]
        $Id,

        [Parameter(Mandatory = $true)]
        [string]
        $WorkspaceId,

        [Parameter(Mandatory = $true)]
        [string]
        $SharedKey,

        [Parameter(Mandatory = $true)]
        [string]
        $LogType,

        [Parameter()]
        [string]
        $Source,

        [Parameter()]
        [hashtable]
        $BatchInfo = $null,

        [switch]
        $SkipCertificateCheck
    )

    # default source
    $Source = Protect-PodeValue -Value $Source -Default $PodeContext.Server.AppName

    # build body scriptblock
    $bodyScriptBlock = {
        param($logCol, $source)

        # build array of events
        $events = @(foreach ($item in $logCol.Items) {
                # build base event object
                $evt = @{
                    Message   = $item.Data
                    Level     = $item.Event.Level
                    Timestamp = $item.Event.Timestamp.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
                }

                # add source
                $source = Protect-PodeValue -Value $item.Event.Metadata['Source'] -Default $source
                if (![string]::IsNullOrEmpty($source)) {
                    $evt.Source = $source
                }

                $evt
            })

        # convert to json and return
        return $events | ConvertTo-Json -Compress -Depth 10
    }

    # build headers scriptblock
    $headersScriptBlock = {
        param($body, $sharedKey)

        # the x-ms-date header
        $date = [datetime]::Now.ToString('R')

        # build signature string
        $contentLength = $body.Length
        $method = 'POST'
        $contentType = 'application/json'
        $dateHeader = "x-ms-date:$($date)"
        $urlPath = '/api/logs'
        $stringToSign = "$($method)`n$($contentLength)`n$($contentType)`n$($dateHeader)`n$($urlPath)"

        # build authorization header
        $bytesToSign = [System.Text.Encoding]::UTF8.GetBytes($stringToSign)
        $keyBytes = [System.Convert]::FromBase64String($sharedKey)
        $hmacsha256 = [System.Security.Cryptography.HMACSHA256]::new()
        $hmacsha256.Key = $keyBytes
        $signatureBytes = $hmacsha256.ComputeHash($bytesToSign)
        $signature = [System.Convert]::ToBase64String($signatureBytes)
        $authorizationHeader = "SharedKey $($workspaceId):$($signature)"

        return @{
            'Authorization' = $authorizationHeader
            'x-ms-date'     = $date
        }
    }

    # default headers
    $headers = @{
        'Log-Type'             = $LogType
        'time-generated-field' = 'Timestamp'
    }

    # add method to server
    return New-PodeLogApiMethod `
        -Id $Id `
        -Type 'Azure' `
        -BatchInfo $BatchInfo `
        -Url "https://$($WorkspaceId).ods.opinsights.azure.com/api/logs?api-version=2016-04-01" `
        -Headers $headers `
        -HeadersScriptBlock $headersScriptBlock `
        -HeadersArgumentList @($SharedKey) `
        -BodyScriptBlock $bodyScriptBlock `
        -BodyArgumentList @($Source) `
        -SkipCertificateCheck:$SkipCertificateCheck.IsPresent `
        -Compress
}

<#
.SYNOPSIS
Creates a new AWS CloudWatch log method.

.DESCRIPTION
Creates a new AWS CloudWatch log method for outputting log items to an AWS CloudWatch Logs group and stream.

.PARAMETER Id
An optional ID to assign to the logging method. If not supplied, a random ID will be generated.

.PARAMETER LogGroupName
The name of the AWS CloudWatch Logs group to which log events will be sent.

.PARAMETER LogStreamName
The name of the AWS CloudWatch Logs stream within the specified log group.

.PARAMETER Token
The authentication bearer token for the AWS CloudWatch Logs API.

.PARAMETER Region
The AWS region where the CloudWatch Logs group and stream are located.

.PARAMETER SourceType
The source type for the log events.

.PARAMETER Source
The source for the log events. (Default: the server's AppName)

.PARAMETER Index
The index for the log events.

.PARAMETER BatchInfo
An optional hashtable containing batch configuration for writing log items in bulk.
Should be created using New-PodeLogBatchInfo.

.PARAMETER SkipCertificateCheck
If supplied, the API request will skip certificate validation checks.

.EXAMPLE
$methodId = New-PodeLogAwsCloudWatchMethod -LogGroupName 'my-log-group' -LogStreamName 'my-log-stream' -Token '<token>' -Region 'us-east-1'

.EXAMPLE
$batchInfo = New-PodeLogBatchInfo -Size 10 -Timeout 10
$methodId = New-PodeLogAwsCloudWatchMethod -LogGroupName 'my-log-group' -LogStreamName 'my-log-stream' -Token '<token>' -Region 'us-east-1' -BatchInfo $batchInfo
#>
function New-PodeLogAwsCloudWatchMethod {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [string]
        $Id,

        [Parameter(Mandatory = $true)]
        [string]
        $LogGroupName,

        [Parameter(Mandatory = $true)]
        [string]
        $LogStreamName,

        [Parameter(Mandatory = $true)]
        [string]
        $Token,

        [Parameter(Mandatory = $true)]
        [string]
        $Region,

        [Parameter()]
        [string]
        $SourceType,

        [Parameter()]
        [string]
        $Source,

        [Parameter()]
        [string]
        $Index,

        [Parameter()]
        [hashtable]
        $BatchInfo = $null,

        [switch]
        $SkipCertificateCheck
    )

    # default source
    $Source = Protect-PodeValue -Value $Source -Default $PodeContext.Server.AppName

    # build body scriptblock
    $bodyScriptBlock = {
        param($logCol, $sourceType, $source, $index)

        # build array of events
        $events = @(foreach ($item in $logCol.Items) {
                # build base event object
                $evt = @{
                    event    = $item.Data
                    host     = $PodeContext.Server.ComputerName
                    time     = ConvertTo-PodeUnixEpoch -DateTime $item.Event.Timestamp
                    severity = ConvertTo-PodeSplunkLevel -Level $item.Event.Level
                }

                # add source type
                $sourceType = Protect-PodeValue -Value $item.Event.Metadata['SourceType'] -Default $sourceType
                if (![string]::IsNullOrEmpty($sourceType)) {
                    $evt.sourcetype = $sourceType
                }

                # add source
                $source = Protect-PodeValue -Value $item.Event.Metadata['Source'] -Default $source
                if (![string]::IsNullOrEmpty($source)) {
                    $evt.source = $source
                }

                # add index
                $index = Protect-PodeValue -Value $item.Event.Metadata['Index'] -Default $index
                if (![string]::IsNullOrEmpty($index)) {
                    $evt.index = $index
                }

                $evt
            })

        # convert to json and return
        return $events | ConvertTo-Json -Compress -Depth 10
    }

    # default headers
    $headers = @{
        'Authorization' = "Bearer $($Token)"
    }

    # add method to server
    return New-PodeLogApiMethod `
        -Id $Id `
        -Type 'AWS' `
        -BatchInfo $BatchInfo `
        -Url "https://logs.$($Region).amazonaws.com/services/collector/event?logGroup=$($LogGroupName)&logStream=$($LogStreamName)" `
        -Headers $headers `
        -BodyScriptBlock $bodyScriptBlock `
        -BodyArgumentList @($Source, $SourceType, $Index) `
        -SkipCertificateCheck:$SkipCertificateCheck.IsPresent `
        -Compress
}

<#
.SYNOPSIS
Creates a new network logging Method.

.DESCRIPTION
Creates a new network logging Method for outputting log items to a remote server over UDP, TCP, or TLS.

.PARAMETER Id
An optional ID to assign to the logging method. If not supplied, a random ID will be generated.

.PARAMETER Server
The address (IP or Hostname) of the remote server to send log items to.

.PARAMETER Transport
The transport protocol to use for sending log items. (Default: 'Udp')

.PARAMETER Port
The port number to use. (Default: 514)

.PARAMETER BatchInfo
An optional hashtable containing batch configuration for writing log items in bulk.
Should be created using New-PodeLogBatchInfo.

.PARAMETER SkipCertificateCheck
A switch parameter to skip certificate validation when using TLS transport.

.EXAMPLE
$methodId = New-PodeLogNetworkMethod -Server '192.168.1.100' -Transport 'Tcp' -Port 514

.EXAMPLE
$methodId = New-PodeLogNetworkMethod -Server 'logs.example.com' -Transport 'Tls' -Port 6514 -SkipCertificateCheck

.EXAMPLE
$batchInfo = New-PodeLogBatchInfo -Size 10 -Timeout 10
$methodId = New-PodeLogNetworkMethod -Server 'logs.example.com' -Transport 'Udp' -BatchInfo $batchInfo
#>
function New-PodeLogNetworkMethod {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [string]
        $Id,

        [Parameter(Mandatory = $true)]
        [string]
        $Server,

        [Parameter()]
        [ValidateSet('Udp', 'Tcp', 'Tls')]
        [string]
        $Transport = 'Udp',

        [Parameter()]
        [ValidateRange(1, 65535)]
        [int]
        $Port = 514,

        [Parameter()]
        [hashtable]
        $BatchInfo = $null,

        [switch]
        $SkipCertificateCheck
    )

    # add method to server
    return Add-PodeLogMethod -Id $Id -Batch $BatchInfo -Metadata @{
        Type        = 'Network'
        ScriptBlock = Get-PodeLoggingNetworkMethod
        Arguments   = @{
            Server               = $Server
            Transport            = $Transport
            Port                 = $Port
            SkipCertificateCheck = $SkipCertificateCheck.IsPresent
        }
    }
}

<#
.SYNOPSIS
Creates a new syslog information object.

.DESCRIPTION
This function creates a new syslog information object with the specified parameters.

.PARAMETER Facility
The syslog facility code. (Default: 16, which corresponds to local0 for web/app logs)

.PARAMETER AppName
The name of the application generating the log message. (Default: the server's AppName)

.PARAMETER Tags
An optional hashtable of tags to include in the syslog message.

.PARAMETER Format
The syslog format to use. (Default: Server default, or 'RFC5424' if no default set)

.EXAMPLE
$info = New-PodeLogSyslogInfo -Format 'RFC3164'

.EXAMPLE
$info = New-PodeLogSyslogInfo -Facility 18 -AppName 'MyApp' -Tags @{ Environment = 'Production'; Version = '1.0' } -Format 'RFC5424'

.EXAMPLE
$info = New-PodeLogSyslogInfo -AppName 'MyApp'
#>
function New-PodeLogSyslogInfo {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter()]
        [ValidateRange(0, 23)]
        [int]
        $Facility = 16, # local0 for web/app logs

        [Parameter()]
        [string]
        $AppName,

        [Parameter()]
        [hashtable]
        $Tags,

        [Parameter()]
        [Pode.Utilities.Logging.PodeSyslogFormat]
        $Format = 'RFC5424'
    )

    # check default format if not supplied
    if (!$PSBoundParameters.ContainsKey('Format')) {
        $Format = Protect-PodeValue -Value (Get-PodeLogDefaultSyslogFormat) -Default $Format -EnumType ([PodeSyslogFormat])
    }

    # return syslog info
    return @{
        Facility = $Facility
        AppName  = $AppName
        Tags     = $Tags
        Format   = $Format
    }
}

<#
.SYNOPSIS
Converts a log message to a syslog formatted string.

.DESCRIPTION
Converts a log message to a syslog formatted string based on the specified parameters.

.PARAMETER Message
The log message to be converted.

.PARAMETER Level
The log level of the message.

.PARAMETER Timestamp
The timestamp of the log message.

.PARAMETER Facility
The syslog facility code. (Default: 16, which corresponds to local0 for web/app logs)

.PARAMETER AppName
The name of the application generating the log message. (Default: the server's AppName)

.PARAMETER Tags
A hashtable of tags to include in the syslog message.

.PARAMETER Format
The syslog format to use. (Default: Server default, or 'RFC5424' if no default set)

.EXAMPLE
$msg = ConvertTo-PodeSyslog -Message "This is a test log message" -Level 'Info' -Timestamp (Get-Date) -Tags @{ Environment = "Production"; Version = "1.0" }

.EXAMPLE
$msg = ConvertTo-PodeSyslog -Message "This is a test log message" -Level 'Error' -Timestamp (Get-Date) -Facility 16 -AppName "MyApp" -Tags @{ Environment = "Staging"; Version = "2.0" } -Format 'RFC3164'
#>
function ConvertTo-PodeSyslog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]
        $Message,

        [Parameter(Mandatory = $true)]
        [Pode.Utilities.Logging.PodeLogLevel]
        $Level,

        [Parameter(Mandatory = $true)]
        [datetime]
        $Timestamp,

        [Parameter()]
        [ValidateRange(0, 23)]
        [int]
        $Facility = 16, # local0 for web/app logs

        [Parameter()]
        [string]
        $AppName,

        [Parameter()]
        [hashtable]
        $Tags,

        [Parameter()]
        [Pode.Utilities.Logging.PodeSyslogFormat]
        $Format = 'RFC5424'
    )

    process {
        # set default format
        if (!$PSBoundParameters.ContainsKey('Format')) {
            $Format = Protect-PodeValue -Value (Get-PodeLogDefaultSyslogFormat) -Default $Format -EnumType ([PodeSyslogFormat])
        }

        # set default app-name
        $AppName = Protect-PodeValue -Value $AppName -Default $PodeContext.Server.AppName
        if ([string]::IsNullOrWhiteSpace($AppName)) {
            $AppName = '-'
        }

        # generate priority value
        $priority = ($Facility * 8) + (ConvertTo-PodeSyslogLevel -Level $Level)

        # get process ID
        $processId = [System.Diagnostics.Process]::GetCurrentProcess().Id

        # ensure message is a string, and escape newlines and carriage returns in message
        if ($Message -isnot [string]) {
            $Message = $Message | ConvertTo-PodeString
        }

        $Message = $Message.Trim().Replace("`n", '\n').Replace("`r", '\r')

        # build message based on format
        switch ($Format) {
            'RFC3164' {
                $strTimestamp = $Timestamp.ToString('MMM dd HH:mm:ss')
                $result = "<$($priority)>$($strTimestamp) $($PodeContext.Server.ComputerName) $($AppName)[$($processId)]: $($Message)"
            }

            'RFC5424' {
                $strTimestamp = $Timestamp.ToString('yyyy-MM-ddTHH:mm:ss.fffK')

                $strTags = '-'
                if ($Tags.Count -gt 0) {
                    $strTags = @(
                        foreach ($key in $Tags.Keys) {
                            $value = $Tags[$key].Replace('\', '\\').Replace('"', '\"').Replace("`n", '\n').Replace("`r", '\r').Replace(']', '\]')
                            "$($key)=`"$($value)`""
                        }
                    ) -join ' '

                    $strTags = "[$($strTags)]"
                }

                $result = "<$($priority)>1 $($strTimestamp) $($PodeContext.Server.ComputerName) $($AppName) $($processId) - $strTags $($Message)"
            }
        }

        return $result
    }
}

<#
.SYNOPSIS
Retrieve the default log format for logging.

.DESCRIPTION
Retrieves the default log format used by the logging system.

.EXAMPLE
$format = Get-PodeLogDefaultFormat
#>
function Get-PodeLogDefaultFormat {
    [CmdletBinding()]
    [OutputType([Pode.Utilities.Logging.PodeLogFormat])]
    param()

    return $PodeContext.Server.Logging.Formatting.Log
}

<#
.SYNOPSIS
Sets the default log format for logging.

.DESCRIPTION
Sets the default log format used by the logging system.

.PARAMETER Format
The log format to set as the default.

.EXAMPLE
Set-PodeLogDefaultFormat -Format 'Syslog'
#>
function Set-PodeLogDefaultFormat {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [Pode.Utilities.Logging.PodeLogFormat]
        $Format
    )

    $PodeContext.Server.Logging.Formatting.Log = $Format
}

<#
.SYNOPSIS
Retrieve the default syslog format for logging.

.DESCRIPTION
Retrieves the default syslog format used by the logging system.

.EXAMPLE
$format = Get-PodeLogDefaultSyslogFormat
#>
function Get-PodeLogDefaultSyslogFormat {
    [CmdletBinding()]
    [OutputType([Pode.Utilities.Logging.PodeSyslogFormat])]
    param()

    return $PodeContext.Server.Logging.Formatting.Syslog
}

<#
.SYNOPSIS
Set the default syslog format for logging.

.DESCRIPTION
Sets the default syslog format used by the logging system.

.PARAMETER Format
The syslog format to set as the default.

.EXAMPLE
Set-PodeLogDefaultSyslogFormat -Format 'RFC5424'
#>
function Set-PodeLogDefaultSyslogFormat {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [Pode.Utilities.Logging.PodeSyslogFormat]
        $Format
    )

    $PodeContext.Server.Logging.Formatting.Syslog = $Format
}

<#
.SYNOPSIS
Retrieve the default serialise format for logging.

.DESCRIPTION
Retrieves the default serialise format used by the logging system.

.EXAMPLE
$format = Get-PodeLogDefaultSerialiseFormat
#>
function Get-PodeLogDefaultSerialiseFormat {
    [CmdletBinding()]
    [OutputType([Pode.Utilities.Logging.PodeSerialiseFormat])]
    param()

    return $PodeContext.Server.Logging.Formatting.Serialise
}

<#
.SYNOPSIS
Set the default serialise format for logging.

.DESCRIPTION
Sets the default serialise format used by the logging system.

.PARAMETER Format
The serialise format to set as the default.

.EXAMPLE
Set-PodeLogDefaultSerialiseFormat -Format 'Json'
#>
function Set-PodeLogDefaultSerialiseFormat {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [Pode.Utilities.Logging.PodeSerialiseFormat]
        $Format
    )

    $PodeContext.Server.Logging.Formatting.Serialise = $Format
}

<#
.SYNOPSIS
Convert a Pode Log Item or Collection to a string.

.DESCRIPTION
Converts a Pode Log Item or a collection of Pode Log Items into a string representation.

.PARAMETER Collection
An optional PodeLogItemCollection to convert to a string, converting all items in the collection.

.PARAMETER Item
An optional single PodeLogItem to convert to a string.

.EXAMPLE
Convert-PodeLogItemToString -Collection $logCollection

.EXAMPLE
Convert-PodeLogItemToString -Item $logItem
#>
function Convert-PodeLogItemToString {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = 'Collection')]
        [Pode.Utilities.Logging.IPodeLogItemCollection]
        $Collection,

        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = 'Item')]
        [Pode.Utilities.Logging.IPodeLogItem]
        $Item
    )

    process {
        switch ($PSCmdlet.ParameterSetName) {
            'Collection' {
                return ($Collection.Items.Data | ConvertTo-PodeString) -join ([Environment]::NewLine)
            }
            'Item' {
                return $Item.Data | ConvertTo-PodeString
            }
        }
    }
}