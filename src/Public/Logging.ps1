using namespace Pode.Utilities.Logging

<#
.SYNOPSIS
Create a new method of outputting logs.

.DESCRIPTION
It creates various Log Methods for outputting logs.

This function has been deprecated and will be removed in future versions.
Please use the appropriate new functions for each Log Method:
- New-PodeLogTerminalMethod
- New-PodeLogFileMethod
- New-PodeLogEventViewerMethod
- New-PodeLogCustomMethod

.PARAMETER Id
An optional ID to assign to the Log Method. If not supplied, a random ID will be generated.

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

    # return info on appropriate Log Type
    switch ($PSCmdlet.ParameterSetName.ToLowerInvariant()) {
        'terminal' {
            # WARNING: Function `New-PodeLoggingMethod` is deprecated.
            Write-PodeHost ($PodeLocale.deprecatedFunctionWarningMessage -f 'New-PodeLoggingMethod', 'New-PodeLogTerminalMethod') -ForegroundColor Yellow

            return New-PodeLogTerminalMethod -Id $Id -BatchInfo $batchInfo
        }

        'file' {
            # WARNING: Function `New-PodeLoggingMethod` is deprecated.
            Write-PodeHost ($PodeLocale.deprecatedFunctionWarningMessage -f 'New-PodeLoggingMethod', 'New-PodeLogFileMethod') -ForegroundColor Yellow

            return New-PodeLogFileMethod -Id $Id -Name $Name -Path $Path -MaxDays $MaxDays -MaxSize $MaxSize -BatchInfo $batchInfo
        }

        'eventviewer' {
            # WARNING: Function `New-PodeLoggingMethod` is deprecated.
            Write-PodeHost ($PodeLocale.deprecatedFunctionWarningMessage -f 'New-PodeLoggingMethod', 'New-PodeLogEventViewerMethod') -ForegroundColor Yellow

            return New-PodeLogEventViewerMethod -Id $Id -EventLogName $EventLogName -Source $Source -EventID $EventID -BatchInfo $batchInfo
        }

        'custom' {
            # WARNING: Function `New-PodeLoggingMethod` is deprecated.
            Write-PodeHost ($PodeLocale.deprecatedFunctionWarningMessage -f 'New-PodeLoggingMethod', 'New-PodeLogCustomMethod') -ForegroundColor Yellow

            return New-PodeLogCustomMethod -Id $Id -ScriptBlock $ScriptBlock -ArgumentList $ArgumentList -BatchInfo $batchInfo
        }
    }
}

<#
.SYNOPSIS
Enables Request Logging using a supplied output method.

.DESCRIPTION
Enables Request Logging using a supplied output method.

.PARAMETER Name
An optional Name to assign to the Request Log Type. If not supplied, a default name will be used.

.PARAMETER Method
One or more Log Method IDs to use for outputting the log entry.

.PARAMETER UsernameProperty
An optional property path within the $WebEvent.Auth.User object for the user's Username. (Default: Username).

.PARAMETER Format
The format to use for the log output. (Default: Combined)

.PARAMETER W3CInfo
An optional hashtable of W3C log configuration information, built using New-PodeLogW3CInfo.
If not supplied, but -Format=W3C, then default W3C fields will be used.

.PARAMETER LogFormat
The format to use for the log output. (Default: Server default, or 'None' if no default set).

.PARAMETER LogScriptBlock
A ScriptBlock to use for custom log formatting of the log entry.

.PARAMETER SerialiseFormat
Specifies the format to use for serialising the log entry. (Default: Server default, or 'Custom' if no default set, or 'None' if Raw is supplied).

.PARAMETER SerialiseScriptBlock
A ScriptBlock to use for custom serialisation of the log entry.

.PARAMETER ScriptBlock
A ScriptBlock to use for custom data selection and transforming of the log entry. (Default: inbuilt logic).

.PARAMETER ArgumentList
An array of arguments to supply to the Custom Log Type's ScriptBlock and SerialiseScriptBlock.

.PARAMETER SyslogInfo
A hashtable containing Syslog configuration information, built using New-PodeSyslogInfo.

.PARAMETER RemoteIPHeader
One or more optional headers to check for the client's remote IP address, if behind a reverse proxy.

.PARAMETER AsUtc
If supplied, the log entry's timestamp will be in UTC, otherwise it will be in local time.

.PARAMETER Raw
If supplied, the log item returned will be the raw Request item as a hashtable and not a string (for Custom methods).

.EXAMPLE
New-PodeLogTerminalMethod | Enable-PodeLogRequestType

.EXAMPLE
New-PodeLogTerminalMethod | Enable-PodeLogRequestType -AsUtc

.EXAMPLE
New-PodeLogTerminalMethod | Enable-PodeLogRequestType -RemoteIPHeader 'X-Forwarded-For'

.EXAMPLE
New-PodeLogTerminalMethod | Enable-PodeLogRequestType -Name 'custom-req' -SerialiseFormat 'Json'

.EXAMPLE
New-PodeLogTerminalMethod | Enable-PodeLogRequestType -SerialiseFormat 'Custom' -SerialiseScriptBlock {
    param($data)
    return "$($data.Host) $($data.Identifier) $($data.User) [$($data.Date)] `"$($data.RequestLine)`" $($data.StatusCode) $($data.Size) `"$($data.Referrer)`" `"$($data.UserAgent)`""
}

.EXAMPLE
New-PodeLogTerminalMethod | Enable-PodeLogRequestType -ScriptBlock {
    param($logEvent)
    return @{
        HttpMethod = $logEvent.Data.HttpMethod
    }
}

.EXAMPLE
$syslogInfo = New-PodeLogSyslogInfo -Format RFC3164
New-PodeLogTerminalMethod | Enable-PodeLogRequestType -LogFormat Syslog -SyslogInfo $syslogInfo
#>
function Enable-PodeLogRequestType {
    [CmdletBinding(DefaultParameterSetName = 'ScriptBlock')]
    param(
        [Parameter()]
        [string]
        $Name,

        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string[]]
        $Method,

        [Parameter()]
        [string]
        $UsernameProperty,

        [Parameter()]
        [ValidateSet('Common', 'Combined', 'W3C')]
        [string]
        $Format = 'Combined',

        [Parameter()]
        [hashtable]
        $W3CInfo,

        [Parameter()]
        [Pode.Utilities.Logging.PodeLogFormat]
        $LogFormat = 'None',

        [Parameter()]
        [scriptblock]
        $LogScriptBlock,

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

        [Parameter()]
        [string[]]
        $RemoteIPHeader,

        [switch]
        $AsUtc,

        [Parameter(ParameterSetName = 'Raw')]
        [switch]
        $Raw
    )

    begin {
        # error if it's already enabled
        $name = Protect-PodeValue -Value $Name -Default ([PodeLogger]::REQUEST_LOG_TYPE_NAME)

        # setup array for Log Methods being piped in
        $pipelineMethods = @()
    }

    process {
        $pipelineMethods += $_
    }

    end {
        # multiple methods from pipeline?
        if ($pipelineMethods.Length -gt 1) {
            $Method = $pipelineMethods
        }

        # base params for adding the Request Log Type
        $params = @{
            Name           = $name
            Method         = $Method
            Levels         = @('Informational')
            LogScriptBlock = $LogScriptBlock
            SyslogInfo     = $SyslogInfo
            XmlRootName    = 'Request'
            AsUtc          = $AsUtc.IsPresent
        }

        # username property
        if ([string]::IsNullOrWhiteSpace($UsernameProperty)) {
            $UsernameProperty = 'Username'
        }

        # add base metadata
        $params['Metadata'] = @{
            Username       = $UsernameProperty
            RemoteIPHeader = $RemoteIPHeader
            Format         = $Format.ToLowerInvariant()
        }

        # handle w3c fields
        if ($Format -ieq 'W3C') {
            # use default fields, if none supplied
            if (Test-PodeIsEmpty $W3CInfo) {
                $W3CInfo = Get-PodeRequestLogW3CDefaultInfo
            }

            # build log header directives
            if (!$W3CInfo.NoLogHeader) {
                $params['LogHeader'] = @(
                    "#Software: Pode $($PodeContext.Server.Version)"
                    "#Version: $($W3CInfo.Version)"
                    "#Date: $([datetime]::Now.ToString('yyyy-MM-dd HH:mm:ss'))"
                    "#Fields: $($W3CInfo.Fields.FieldName -join ' ')"
                )
            }

            # add the fields to the metadata
            $params['Metadata']['W3CFields'] = $W3CInfo.Fields
        }

        # add LogFormat if supplied
        if ($PSBoundParameters.ContainsKey('LogFormat')) {
            $params['LogFormat'] = $LogFormat
        }

        # add SerialiseFormat if supplied, otherwise use local default
        if ($PSBoundParameters.ContainsKey('SerialiseFormat')) {
            $params['SerialiseFormat'] = $SerialiseFormat
        }
        else {
            $defSerialiseFormat = Get-PodeLogDefaultSerialiseFormat
            if ($null -eq $defSerialiseFormat) {
                if ($Raw) {
                    $params['SerialiseFormat'] = 'None'
                }
                else {
                    $params['SerialiseFormat'] = $SerialiseFormat
                }
            }
        }

        # add SerialiseScriptBlock if supplied, otherwise use local default
        if ($null -eq $SerialiseScriptBlock) {
            $SerialiseScriptBlock = Get-PodeLoggingInbuiltSerialiseType -Type Requests
        }
        $params['SerialiseScriptBlock'] = $SerialiseScriptBlock

        # do we only want the raw data?
        if ($Raw) {
            $params['Raw'] = $true
        }

        # if not, add the scriptblock for transforming request data
        else {
            if ($null -eq $ScriptBlock) {
                $ScriptBlock = Get-PodeLoggingInbuiltType -Type Requests
            }
            $params['ScriptBlock'] = $ScriptBlock
            $params['ArgumentList'] = $ArgumentList
            $params['Version'] = 2
        }

        # add the type internally
        $typeInfo = Add-PodeLogTypeInternal @params

        # register the type with the logger
        $logType = [PodeLogRequestType]::new($typeInfo.Name, $typeInfo.Options.Formatting.AsUtc)
        $PodeContext.Server.Logging.Logger.RegisterType($logType)
    }
}

if (!(Test-Path Alias:Enable-PodeRequestLogging)) {
    New-Alias Enable-PodeRequestLogging -Value Enable-PodeLogRequestType
}

<#
.SYNOPSIS
Disables Request Log Type.

.DESCRIPTION
Disables Request Log Type.

.PARAMETER Name
An optional Name to assign to the Request Log Type. If not supplied, a default name will be used.

.EXAMPLE
Disable-PodeLogRequestType

.EXAMPLE
Disable-PodeLogRequestType -Name 'custom-req'
#>
function Disable-PodeLogRequestType {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Name
    )

    $Name = Protect-PodeValue -Value $Name -Default ([PodeLogger]::REQUEST_LOG_TYPE_NAME)
    Remove-PodeLogType -Name $Name
}

if (!(Test-Path Alias:Disable-PodeRequestLogging)) {
    New-Alias Disable-PodeRequestLogging -Value Disable-PodeLogRequestType
}

<#
.SYNOPSIS
Enables Error Log Type using a supplied Log Method.

.DESCRIPTION
Enables Error Log Type using a supplied Log Method.

.PARAMETER Name
An optional Name to assign to the Error Log Type. If not supplied, a default name will be used.

.PARAMETER Method
One or more Log Method IDs to use for outputting the log entry.

.PARAMETER Levels
The Levels of errors that should be logged (Default: Emergency, Alert, Critical, Error)

.PARAMETER Kind
The Kinds of errors that should be logged (Default: Server)

.PARAMETER LogFormat
The format to use for the log output. (Default: Server default, or 'None' if no default set).

.PARAMETER LogScriptBlock
A ScriptBlock to use for custom log formatting of the log entry.

.PARAMETER SerialiseFormat
Specifies the format to use for serialising the log entry. (Default: Server default, or 'Custom' if no default set, or 'None' if Raw is supplied).

.PARAMETER SerialiseScriptBlock
A ScriptBlock to use for custom serialisation of the log entry.

.PARAMETER ScriptBlock
A ScriptBlock to use for custom data selection and transforming of the log entry. (Default: inbuilt logic).

.PARAMETER ArgumentList
An array of arguments to supply to the Custom Log Type's ScriptBlock and SerialiseScriptBlock.

.PARAMETER SyslogInfo
A hashtable containing Syslog configuration information, built using New-PodeSyslogInfo.

.PARAMETER AsUtc
If supplied, the log entry's timestamp will be in UTC, otherwise it will be in local time.

.PARAMETER Raw
If supplied, the log item returned will be the raw Error item as a hashtable and not a string (for Custom methods).

.EXAMPLE
New-PodeLogTerminalMethod | Enable-PodeLogErrorType

.EXAMPLE
New-PodeLogTerminalMethod | Enable-PodeLogErrorType -Kind Server, Client

.EXAMPLE
New-PodeLogTerminalMethod | Enable-PodeLogErrorType -AsUtc

.EXAMPLE
New-PodeLogTerminalMethod | Enable-PodeLogErrorType -Name 'custom-error' -SerialiseFormat 'Json'

.EXAMPLE
New-PodeLogTerminalMethod | Enable-PodeLogErrorType -SerialiseFormat 'Custom' -SerialiseScriptBlock {
    param($data)
    return $data | ConvertTo-PodeString
}

.EXAMPLE
New-PodeLogTerminalMethod | Enable-PodeLogErrorType -ScriptBlock {
    param($logEvent)
    return @{
        StackTrace = $logEvent.Data.StackTrace
    }
}

.EXAMPLE
$syslogInfo = New-PodeLogSyslogInfo -Format RFC3164
New-PodeLogTerminalMethod | Enable-PodeLogErrorType -LogFormat Syslog -SyslogInfo $syslogInfo
#>
function Enable-PodeLogErrorType {
    [CmdletBinding(DefaultParameterSetName = 'ScriptBlock')]
    param(
        [Parameter()]
        [string]
        $Name,

        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string[]]
        $Method,

        [Parameter()]
        [Alias('Level')]
        [ValidateSet('Emergency', 'Alert', 'Critical', 'Error', 'Warning', 'Notice', 'Informational', 'Verbose', 'Debug', '*')]
        [string[]]
        $Levels = @('Emergency', 'Alert', 'Critical', 'Error'),

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [Pode.Protocols.Common.Requests.PodeRequestExceptionKind[]]
        $Kind = @([Pode.Protocols.Common.Requests.PodeRequestExceptionKind]::Server),

        [Parameter()]
        [Pode.Utilities.Logging.PodeLogFormat]
        $LogFormat = 'None',

        [Parameter()]
        [scriptblock]
        $LogScriptBlock,

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

        [switch]
        $AsUtc,

        [Parameter(ParameterSetName = 'Raw')]
        [switch]
        $Raw
    )

    begin {
        # get error log type name
        $name = Protect-PodeValue -Value $Name -Default ([PodeLogger]::ERROR_LOG_TYPE_NAME)

        # setup array for Log Methods being piped in
        $pipelineMethods = @()
    }

    process {
        $pipelineMethods += $_
    }

    end {
        # multiple methods from pipeline?
        if ($pipelineMethods.Length -gt 1) {
            $Method = $pipelineMethods
        }

        # base params for adding the Error Log Type
        $params = @{
            Name           = $name
            Method         = $Method
            Levels         = $Levels
            LogScriptBlock = $LogScriptBlock
            SyslogInfo     = $SyslogInfo
            XmlRootName    = 'Error'
            AsUtc          = $AsUtc.IsPresent
        }

        # add LogFormat if supplied
        if ($PSBoundParameters.ContainsKey('LogFormat')) {
            $params['LogFormat'] = $LogFormat
        }

        # add SerialiseFormat if supplied, otherwise use local default
        if ($PSBoundParameters.ContainsKey('SerialiseFormat')) {
            $params['SerialiseFormat'] = $SerialiseFormat
        }
        else {
            $defSerialiseFormat = Get-PodeLogDefaultSerialiseFormat
            if ($null -eq $defSerialiseFormat) {
                if ($Raw) {
                    $params['SerialiseFormat'] = 'None'
                }
                else {
                    $params['SerialiseFormat'] = $SerialiseFormat
                }
            }
        }

        # add SerialiseScriptBlock if supplied, otherwise use local default
        if ($null -eq $SerialiseScriptBlock) {
            $SerialiseScriptBlock = Get-PodeLoggingInbuiltSerialiseType -Type Errors
        }
        $params['SerialiseScriptBlock'] = $SerialiseScriptBlock

        # do we only want the raw data?
        if ($Raw) {
            $params['Raw'] = $true
        }

        # if not, add the scriptblock for transforming error data
        else {
            if ($null -eq $ScriptBlock) {
                $ScriptBlock = Get-PodeLoggingInbuiltType -Type Errors
            }
            $params['ScriptBlock'] = $ScriptBlock
            $params['ArgumentList'] = $ArgumentList
            $params['Version'] = 2
        }

        # add types as additional options
        $params['Options'] = @{
            Kinds = $Kind
        }

        # add the type internally
        $typeInfo = Add-PodeLogTypeInternal @params

        # register the type with the logger
        $logType = [PodeLogErrorType]::new($typeInfo.Name, $typeInfo.Levels, $Kind, $typeInfo.Options.Formatting.AsUtc)
        $PodeContext.Server.Logging.Logger.RegisterType($logType)
    }
}

if (!(Test-Path Alias:Enable-PodeErrorLogging)) {
    New-Alias Enable-PodeErrorLogging -Value Enable-PodeLogErrorType
}

<#
.SYNOPSIS
Disables Error Log Type.

.DESCRIPTION
Disables Error Log Type.

.PARAMETER Name
An optional Name to assign to the Error Log Type. If not supplied, a default name will

.EXAMPLE
Disable-PodeLogErrorType

.EXAMPLE
Disable-PodeLogErrorType -Name 'custom-error'
#>
function Disable-PodeLogErrorType {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Name
    )

    $Name = Protect-PodeValue -Value $Name -Default ([PodeLogger]::ERROR_LOG_TYPE_NAME)
    Remove-PodeLogType -Name $Name
}

if (!(Test-Path Alias:Disable-PodeErrorLogging)) {
    New-Alias Disable-PodeErrorLogging -Value Disable-PodeLogErrorType
}

<#
.SYNOPSIS
Adds a custom Log Type for parsing custom log items.

.DESCRIPTION
Adds a custom Log Type for parsing custom log items.

.PARAMETER Name
A unique Name for the Log Type.

.PARAMETER Method
The Log Method ID to use for outputting the log entry.

.PARAMETER ScriptBlock
The ScriptBlock defining logic that transforms an item, and returns it for outputting.

.PARAMETER Levels
The Levels of log items that should be logged. (Default: Informational)

.PARAMETER ArgumentList
An array of arguments to supply to the Custom Log Type's ScriptBlock and SerialiseScriptBlock.

.PARAMETER Version
The version of the Log Type, this determines the arguments which are supplied to the ScriptBlock. (Default: 1)
Arguments supplied depending on the version:

- Version 1: Log Event Data, ArgumentList
- Version 2: Log Event, ArgumentList

Under Version 2, the "Log Event" contains references to the log event's data, level, timestamp, and metadata.

.PARAMETER LogFormat
The format to use for the log output. (Default: Server default, or 'None' if no default set).

.PARAMETER LogScriptBlock
A ScriptBlock to use for custom log formatting of the log entry.

.PARAMETER SerialiseFormat
Specifies the format to use for serialising the log entry. (Default: Server default, or 'None' if no default set).

.PARAMETER SerialiseScriptBlock
A ScriptBlock defining custom logic for serialising the log data.

.PARAMETER SyslogInfo
A hashtable containing Syslog configuration information, built using New-PodeSyslogInfo.

.PARAMETER XmlRootName
An optional name to use for the root element of the log item when serialising to XML.

.PARAMETER Metadata
A hashtable of metadata to associate with the Log Type. This data can be retrieved via Get-PodeLogType.

.PARAMETER LogHeader
An optional array of strings to use as the header(s) for the log, such as W3C log directives.

.PARAMETER AsUtc
If supplied, will be set in the Log Type's Formatting Options as to whether to use UTC timestamps or local timestamps.

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
                    # A non-empty ScriptBlock is required for the Log Method
                    throw ($PodeLocale.nonEmptyScriptBlockRequiredForLoggingMethodExceptionMessage)
                }

                return $true
            })]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [Alias('Level')]
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
        [scriptblock]
        $LogScriptBlock,

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

        [Parameter()]
        [hashtable]
        $Metadata,

        [Parameter()]
        [string[]]
        $LogHeader,

        [switch]
        $AsUtc,

        [Parameter(ParameterSetName = 'Raw')]
        [switch]
        $Raw
    )

    begin {
        # setup array for Log Methods being piped in
        $pipelineMethods = @()
    }

    process {
        $pipelineMethods += $_
    }

    end {
        # multiple methods from pipeline?
        if ($pipelineMethods.Length -gt 1) {
            $Method = $pipelineMethods
        }

        # add the type internally
        $typeInfo = Add-PodeLogTypeInternal @PSBoundParameters -Levels $Levels

        # register the type with the logger
        $logType = [PodeLogType]::new($typeInfo.Name, $typeInfo.Levels, $typeInfo.Options.Formatting.AsUtc)
        $PodeContext.Server.Logging.Logger.RegisterType($logType)
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
        # get the Log Type
        $type = Get-PodeLogType -Name $Name
        if ($null -eq $type) {
            return
        }

        # unregister Log Type from method
        foreach ($methodId in $type.Method) {
            Unregister-PodeLogTypeFromMethod -TypeName $Name -MethodId $methodId
        }

        # remove the Log Type
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
        # get the Log Method
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

        # dispose the Log Method queue
        if ($null -ne $method.Queue) {
            $method.Queue.Dispose()
        }

        # unregister Log Method from types that reference it
        foreach ($typeName in $method.Types) {
            Unregister-PodeLogMethodFromType -TypeName $typeName -MethodId $Id
        }

        # remove the Log Method
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

    # dispose of any Log Method queues
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

.PARAMETER Override
An optional array of override options, to override certain properties of log methods.
Created using the New-PodeLogEventViewerOverride, etc. functions.

.PARAMETER CheckInnerException
If supplied, any exceptions are check for inner exceptions. If one is present, this is also logged.

.EXAMPLE
try { /* logic */ } catch { $_ | Write-PodeErrorLog }

.EXAMPLE
[System.Exception]::new('error message') | Write-PodeErrorLog

.EXAMPLE
Write-PodeErrorLog -Message 'error message' -Level 'Warning'

.EXAMPLE
Write-PodeErrorLog -Message 'error message' -Override @(New-PodeLogEventViewerOverride -EventId 1337)
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

        [Parameter()]
        [hashtable[]]
        $Override,

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
                $PodeContext.Server.Logging.Logger.AddException(
                    $Exception,
                    $contextId,
                    $Level,
                    $Metadata,
                    $Override,
                    [int]$ThreadId
                )
            }

            'Error' {
                $PodeContext.Server.Logging.Logger.AddException(
                    $ErrorRecord.CategoryInfo.ToString(),
                    $ErrorRecord.Exception.Message,
                    $ErrorRecord.ScriptStackTrace,
                    $contextId,
                    $Level,
                    [Pode.Protocols.Common.Requests.PodeRequestExceptionKind]::Server,
                    $Metadata,
                    $Override,
                    [int]$ThreadId
                )
            }

            'Message' {
                $category = (Get-PSCallStack)[1].Location
                $PodeContext.Server.Logging.Logger.AddException(
                    $category,
                    $Message,
                    [string]::Empty,
                    $contextId,
                    $Level,
                    [Pode.Protocols.Common.Requests.PodeRequestExceptionKind]::Server,
                    $Metadata,
                    $Override,
                    [int]$ThreadId
                )
            }
        }

        # for exceptions, check the inner exception
        if ($CheckInnerException -and ($null -ne $Exception.InnerException) -and ![string]::IsNullOrWhiteSpace($Exception.InnerException.Message)) {
            $Exception.InnerException | Write-PodeErrorLog -Level $Level -Metadata $Metadata -Override $Override
        }
    }
}

<#
.SYNOPSIS
Write an object to a configured custom Log Method.

.DESCRIPTION
Write an object to one or more configured custom Log Methods.

.PARAMETER Name
One or more custom Log Type Names.

.PARAMETER Level
The Level of the log item being logged. (Default: Informational)

.PARAMETER InputObject
The Object to write.

.PARAMETER Metadata
An optional hashtable of Metadata to include with the log item.

.PARAMETER Override
An optional array of override options, to override certain properties of log methods.
Created using the New-PodeLogEventViewerOverride, etc. functions.

.EXAMPLE
$object | Write-PodeLog -Name 'LogTypeName'

.EXAMPLE
$object | Write-PodeLog -Name 'LogTypeName1', 'LogTypeName2'

.EXAMPLE
$object | Write-PodeLog -Name 'LogTypeName' -Level 'Debug' -Metadata @{ Key = 'Value' }

.EXAMPLE
$object | Write-PodeLog -Name 'LogTypeName' -Override @(New-PodeLogEventViewerOverride -EventId 1337)
#>
function Write-PodeLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]
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
        $Metadata,

        [Parameter()]
        [hashtable[]]
        $Override
    )

    process {
        foreach ($n in $Name) {
            $PodeContext.Server.Logging.Logger.Add($n, $Level, $InputObject, $Metadata, $Override)
        }
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
Create a new Terminal Log Method.

.DESCRIPTION
Creates a new Terminal Log Method for outputting log items to the terminal.
Can be used with Enable-PodeLogRequestType, Enable-PodeLogErrorType, or Add-PodeLogType.

.PARAMETER Id
An optional ID to assign to the Log Method. If not supplied, a random ID will be generated.

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
    return Add-PodeLogMethodInternal -Id $Id -Batch $BatchInfo -Config @{
        Type        = 'Terminal'
        ScriptBlock = Get-PodeLoggingTerminalMethod
        Arguments   = @{}
    }
}

<#
.SYNOPSIS
Create new Override options for the Terminal Log Method.

.DESCRIPTION
Creates new set of override options for the Terminal Log Method.

.PARAMETER Id
The ID of the Terminal Log Method to override. (Default: 'Terminal')

.PARAMETER Ignore
Whether to ignore the Terminal Log Method when writing log items.

.EXAMPLE
$override = New-PodeLogTerminalOverride -Ignore

.EXAMPLE
$override = New-PodeLogTerminalOverride -Id 'TerminalMethod' -Ignore
#>
function New-PodeLogTerminalOverride {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter()]
        [string]
        $Id,

        [switch]
        $Ignore
    )

    $Id = Protect-PodeValue -Value $Id -Default 'Terminal'

    return @{
        Id     = $Id
        Ignore = $Ignore.IsPresent
    }
}

<#
.SYNOPSIS
Create a new File Log Method.

.DESCRIPTION
Creates a new File Log Method for outputting log items to files.
Can be used with Enable-PodeLogRequestType, Enable-PodeLogErrorType, or Add-PodeLogType.

.PARAMETER Id
An optional ID to assign to the Log Method. If not supplied, a random ID will be generated.

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
    return Add-PodeLogMethodInternal -Id $Id -Batch $BatchInfo -Config @{
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
Create new Override options for the File Log Method.

.DESCRIPTION
Creates a new set of override options for the File Log Method.

.PARAMETER Id
The ID of the File Log Method to override. (Default: 'File')

.PARAMETER Ignore
Whether to ignore the File Log Method when writing log items.

.EXAMPLE
$override = New-PodeLogFileOverride -Ignore

.EXAMPLE
$override = New-PodeLogFileOverride -Id 'FileMethod' -Ignore
#>
function New-PodeLogFileOverride {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter()]
        [string]
        $Id,

        [switch]
        $Ignore
    )

    $Id = Protect-PodeValue -Value $Id -Default 'File'

    return @{
        Id     = $Id
        Ignore = $Ignore.IsPresent
    }
}

<#
.SYNOPSIS
Create a new Event Viewer Log Method.

.DESCRIPTION
Creates a new Event Viewer Log Method for outputting log items to the Windows Event Viewer.
Can be used with Enable-PodeLogRequestType, Enable-PodeLogErrorType, or Add-PodeLogType.

.PARAMETER Id
An optional ID to assign to the Log Method. If not supplied, a random ID will be generated.

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
    return Add-PodeLogMethodInternal -Id $Id -Batch $BatchInfo -Config @{
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
Create new Override options for the Event Viewer Log Method.

.DESCRIPTION
Creates a new set of override options for the Event Viewer Log Method.

.PARAMETER Id
The ID of the Event Viewer Log Method to override. (Default: 'EventViewer')

.PARAMETER EventID
An optional EventID to override the EventID of the Event Viewer Log Method.

.PARAMETER Ignore
Whether to ignore the Event Viewer Log Method when writing log items.

.EXAMPLE
$override = New-PodeLogEventViewerOverride -Ignore

.EXAMPLE
$override = New-PodeLogEventViewerOverride -EventID 1337

.EXAMPLE
$override = New-PodeLogEventViewerOverride -Id 'EventViewerMethod' -EventID 1337
#>
function New-PodeLogEventViewerOverride {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter()]
        [string]
        $Id,

        [Parameter()]
        [int]
        $EventID,

        [switch]
        $Ignore
    )

    $Id = Protect-PodeValue -Value $Id -Default 'EventViewer'

    return @{
        Id      = $Id
        EventID = $EventID
        Ignore  = $Ignore.IsPresent
    }
}

<#
.SYNOPSIS
Create a new Custom Log Method.

.DESCRIPTION
Creates a new Custom Log Method for outputting log items using custom logic defined in a ScriptBlock.
Can be used with Enable-PodeLogRequestType, Enable-PodeLogErrorType, or Add-PodeLogType.

.PARAMETER Id
An optional ID to assign to the Log Method. If not supplied, a random ID will be generated.

.PARAMETER ScriptBlock
The ScriptBlock that defines how to output a log item.

.PARAMETER ArgumentList
An array of arguments to supply to the Custom Logging output method's ScriptBlock.

.PARAMETER Version
The version of the Log Method, this determines the arguments which are supplied to the ScriptBlock. (Default: 1)
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
    return Add-PodeLogMethodInternal -Id $Id -Batch $BatchInfo -Config @{
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
Creates a new set of override options for the Custom Log Method.

.DESCRIPTION
Creates a new set of override options for the Custom Log Method.
This allows you to specify custom data for Custom Log Methods, and can be retrieved via Get-PodeLogOverride per Log Event.

.PARAMETER Id
An optional ID to assign to the Log Method to override. (Default: 'Custom')

.PARAMETER Data
A hashtable of custom data to associate with the Custom Log Method override.

.PARAMETER Ignore
Whether to ignore the Custom Log Method when writing log items.

.EXAMPLE
$override = New-PodeLogCustomOverride -Data @{ Key = 'Value' }

.EXAMPLE
$override = New-PodeLogCustomOverride -Id 'CustomMethod' -Data @{ Key = 'Value' }

.EXAMPLE
$override = New-PodeLogCustomOverride -Ignore
#>
function New-PodeLogCustomOverride {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter()]
        [string]
        $Id,

        [Parameter()]
        [hashtable]
        $Data,

        [switch]
        $Ignore
    )

    $Id = Protect-PodeValue -Value $Id -Default 'Custom'

    return @{
        Id     = $Id
        Data   = $Data
        Ignore = $Ignore.IsPresent
    }
}

<#
.SYNOPSIS
Creates a new API Log Method.

.DESCRIPTION
Creates a new API Log Method for outputting log items to custom API endpoints.

.PARAMETER Id
An optional ID to assign to the Log Method. If not supplied, a random ID will be generated.

.PARAMETER Type
An optional Type to assign to the Log Method. (Default: API)

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

.PARAMETER HeadersArguments
An optional hashtable of arguments to pass to the HeadersScriptBlock.

.PARAMETER BodyScriptBlock
A ScriptBlock that returns the body of the API request as a valid string, based on a collection of log items.
Protect-PodeLogItem will be automatically applied to the returned string.

.PARAMETER BodyArguments
An optional hashtable of arguments to pass to the BodyScriptBlock.

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
    param($logItems)
    return $logItems.Data | ConvertTo-Json -Compress
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
        [ValidateSet('Get', 'Post', 'Put', 'Patch')]
        [string]
        $Method = 'Post',

        [Parameter()]
        [hashtable]
        $Headers = @{},

        [Parameter()]
        [scriptblock]
        $HeadersScriptBlock,

        [Parameter()]
        [hashtable]
        $HeadersArguments,

        [Parameter(Mandatory = $true)]
        [scriptblock]
        $BodyScriptBlock,

        [Parameter()]
        [hashtable]
        $BodyArguments,

        [Parameter()]
        [hashtable]
        $BatchInfo = $null,

        [switch]
        $SkipCertificateCheck,

        [switch]
        $Compress
    )

    # default type
    $Type = Protect-PodeValue -Value $Type -Default 'API'

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
    return Add-PodeLogMethodInternal -Id $Id -Batch $BatchInfo -Config @{
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
                Arguments      = $HeadersArguments
            }
            Body                 = @{
                ScriptBlock    = $BodyScriptBlock
                UsingVariables = $bodyUsingVars
                Arguments      = $BodyArguments
            }
            SkipCertificateCheck = $SkipCertificateCheck.IsPresent
        }
    }
}

<#
.SYNOPSIS
Creates a new set of override options for the API Log Method.

.DESCRIPTION
Creates a new set of override options for the API Log Method.
This allows you to specify custom data for API Log Methods, and can be retrieved via Get-PodeLogOverride per Log Event.

.PARAMETER Id
An optional ID to assign to the Log Method to override. (Default: 'API')

.PARAMETER Type
An optional Type to assign to the Log Method to override. (Default: API)

.PARAMETER Data
A hashtable of custom data to associate with the API Log Method override.

.PARAMETER Ignore
Whether to ignore the API Log Method when writing log items.

.EXAMPLE
$override = New-PodeLogApiOverride -Data @{ Key = 'Value' }

.EXAMPLE
$override = New-PodeLogApiOverride -Id 'ApiMethod' -Data @{ Key = 'Value' }

.EXAMPLE
$override = New-PodeLogApiOverride -Ignore

.EXAMPLE
$override = New-PodeLogApiOverride -Type 'NewRelic' -Data @{ Key = 'Value' }
#>
function New-PodeLogApiOverride {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter()]
        [string]
        $Id,

        [Parameter()]
        [string]
        $Type,

        [Parameter()]
        [hashtable]
        $Data,

        [switch]
        $Ignore
    )

    $Type = Protect-PodeValue -Value $Type -Default 'API'
    $Id = Protect-PodeValue -Value $Id -Default $Type

    return @{
        Id     = $Id
        Data   = $Data
        Ignore = $Ignore.IsPresent
    }
}

<#
.SYNOPSIS
Creates a new Splunk Log Method.

.DESCRIPTION
Creates a new Splunk Log Method for outputting log items to a Splunk HTTP Event Collector (HEC) endpoint.

.PARAMETER Id
An optional ID to assign to the Log Method. If not supplied, a random ID will be generated.

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
        param($logItems, $options)

        # build array of events
        $events = @(foreach ($item in $logItems) {
                # build base event object
                $evt = @{
                    event  = $item.Data
                    host   = $PodeContext.Server.ComputerName
                    time   = ConvertTo-PodeUnixEpoch -DateTime $item.Event.Timestamp
                    fields = @{
                        severity = ConvertTo-PodeSplunkLevel -Level $item.Event.Level
                    }
                }

                # get any overrides for this method
                $override = Get-PodeLogOverride -LogEvent $item.Event

                # add source type
                $sourceType = Protect-PodeValue -Value $override.SourceType -Default $options.SourceType
                if (![string]::IsNullOrEmpty($sourceType)) {
                    $evt.sourcetype = $sourceType
                }

                # add source
                $source = Protect-PodeValue -Value $override.Source -Default $options.Source
                if (![string]::IsNullOrEmpty($source)) {
                    $evt.source = $source
                }

                # add index
                $index = Protect-PodeValue -Value $override.Index -Default $options.Index
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
        Authorization = "Splunk $($Token)"
    }

    # add method to server
    $bodyArgs = @{
        SourceType = $SourceType
        Source     = $Source
        Index      = $Index
    }

    return New-PodeLogApiMethod `
        -Id $Id `
        -Type 'Splunk' `
        -BatchInfo $BatchInfo `
        -Url "$($BaseUrl.TrimEnd('/'))/services/collector" `
        -Headers $headers `
        -BodyScriptBlock $bodyScriptBlock `
        -BodyArguments $bodyArgs `
        -SkipCertificateCheck:$SkipCertificateCheck.IsPresent `
        -Compress
}

<#
.SYNOPSIS
Creates a new set of override options for the Splunk Log Method.

.DESCRIPTION
Creates a new set of override options for the Splunk Log Method.

.PARAMETER Id
The ID of the Splunk Log Method to override. (Default: 'Splunk')

.PARAMETER Source
An optional source to override the source of the Splunk Log Method.

.PARAMETER SourceType
An optional source type to override the source type of the Splunk Log Method.

.PARAMETER Index
An optional index to override the index of the Splunk Log Method.

.PARAMETER Ignore
Whether to ignore the Splunk Log Method when writing log items.

.EXAMPLE
$override = New-PodeLogSplunkOverride -Source 'my_source' -SourceType 'syslog' -Index 'main'

.EXAMPLE
$override = New-PodeLogSplunkOverride -Id 'SplunkMethod' -Ignore
#>
function New-PodeLogSplunkOverride {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter()]
        [string]
        $Id,

        [Parameter()]
        [string]
        $Source,

        [Parameter()]
        [string]
        $SourceType,

        [Parameter()]
        [string]
        $Index,

        [switch]
        $Ignore
    )

    $Id = Protect-PodeValue -Value $Id -Default 'Splunk'

    return @{
        Id         = $Id
        Source     = $Source
        SourceType = $SourceType
        Index      = $Index
        Ignore     = $Ignore.IsPresent
    }
}

<#
.SYNOPSIS
Creates a new Datadog Log Method.

.DESCRIPTION
Creates a new Datadog Log Method for outputting log items to a Datadog's HTTP v2 logging API endpoint.

.PARAMETER Id
An optional ID to assign to the Log Method. If not supplied, a random ID will be generated.

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
        param($logItems, $options)

        # build array of events
        $events = @(foreach ($item in $logItems) {
                # build base event object
                $evt = @{
                    message   = $item.Data
                    hostname  = $PodeContext.Server.ComputerName
                    status    = ConvertTo-PodeDatadogLevel -Level $item.Event.Level
                    timestamp = $item.Event.Timestamp.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
                }

                # get any overrides for this method
                $override = Get-PodeLogOverride -LogEvent $item.Event

                # add service
                $service = Protect-PodeValue -Value $override.Service -Default $options.Service
                if (![string]::IsNullOrEmpty($service)) {
                    $evt.service = $service
                }

                # add source
                $source = Protect-PodeValue -Value $override.Source -Default $options.Source
                if (![string]::IsNullOrEmpty($source)) {
                    $evt.ddsource = $source
                }

                # add tags
                $_tags = @{}
                if ($options.Tags.Count -gt 0) {
                    $_tags = $options.Tags
                }

                if (($null -ne $override.Tags) -and ($override.Tags.Count -gt 0)) {
                    switch ($override.TagsAction) {
                        'replace' { $_tags = $override.Tags }
                        'merge' {
                            foreach ($key in $override.Tags.Keys) {
                                $_tags[$key] = $override.Tags[$key]
                            }
                        }
                    }
                }

                if ($_tags.Count -gt 0) {
                    $evt.ddtags = @(foreach ($key in $_tags.Keys) { "$($key):$($_tags[$key])" }) -join ','
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
    $bodyArgs = @{
        Service = $Service
        Source  = $Source
        Tags    = $Tags
    }

    return New-PodeLogApiMethod `
        -Id $Id `
        -Type 'Datadog' `
        -BatchInfo $BatchInfo `
        -Url "$($BaseUrl.TrimEnd('/'))/api/v2/logs" `
        -Headers $headers `
        -BodyScriptBlock $bodyScriptBlock `
        -BodyArguments $bodyArgs `
        -SkipCertificateCheck:$SkipCertificateCheck.IsPresent `
        -Compress
}

<#
.SYNOPSIS
Creates a new set of override options for the Datadog Log Method.

.DESCRIPTION
Creates a new set of override options for the Datadog Log Method.

.PARAMETER Id
An optional ID to assign to the Log Method to override. (Default: 'Datadog')

.PARAMETER Service
An optional service name to override the service of the Datadog Log Method.

.PARAMETER Source
An optional source name to override the source of the Datadog Log Method.

.PARAMETER Tags
An optional hashtable of tags to override the tags of the Datadog Log Method.

.PARAMETER TagsAction
An optional action to determine how to handle the tags of the Datadog Log Method. (Default: 'Merge')

.PARAMETER Ignore
Whether to ignore the Datadog Log Method when writing log items.

.EXAMPLE
$override = New-PodeLogDatadogOverride -Service 'my_service' -Source 'my_source' -Tags @{ env = 'prod' } -TagsAction 'Append'

.EXAMPLE
$override = New-PodeLogDatadogOverride -Id 'DatadogMethod' -Ignore
#>
function New-PodeLogDatadogOverride {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter()]
        [string]
        $Id,

        [Parameter()]
        [string]
        $Service,

        [Parameter()]
        [string]
        $Source,

        [Parameter()]
        [hashtable]
        $Tags,

        [Parameter()]
        [ValidateSet('Merge', 'Replace')]
        [string]
        $TagsAction = 'Merge',

        [switch]
        $Ignore
    )

    $Id = Protect-PodeValue -Value $Id -Default 'Datadog'

    return @{
        Id         = $Id
        Service    = $Service
        Source     = $Source
        Tags       = $Tags
        TagsAction = $TagsAction.ToLowerInvariant()
        Ignore     = $Ignore.IsPresent
    }
}

<#
.SYNOPSIS
Creates a new Azure Log Analytics Log Method.

.DESCRIPTION
Creates a new Azure Log Analytics Log Method for outputting log items to an Azure Log Analytics workspace.
The Azure Log Method created will either use the legacy Workspace method, or the new Data Collection logic.

.PARAMETER Id
An optional ID to assign to the Log Method. If not supplied, a random ID will be generated.

.PARAMETER WorkspaceId
The Workspace ID of the Azure Log Analytics workspace.

.PARAMETER SharedKey
The Shared Key of the Azure Log Analytics workspace.

.PARAMETER LogType
The Log Type to use for the log items in Azure Log Analytics, used for the Log-Type header.

.PARAMETER Endpoint
The Data Collection Endpoint used for ingestion into Azure Monitor/Azure Log Analytics.

.PARAMETER ImmutableId
The Data Collection Rule Immutable ID.

.PARAMETER StreamName
The Stream Name in the Data Collection Rule that should handle the logs.

.PARAMETER ClientId
The Client ID from registering a new app.

.PARAMETER ClientSecret
The Client Secret from registering a new app.

.PARAMETER TenantId
The Directory/Tenant ID from registering a new app.

.PARAMETER Source
An optional source to include with the log items. (Default: the server's AppName)

.PARAMETER BatchInfo
An optional hashtable containing batch configuration for writing log items in bulk.
Should be created using New-PodeLogBatchInfo.

.PARAMETER SkipCertificateCheck
If supplied, the API request will skip certificate validation checks.

.EXAMPLE
$methodId = New-PodeLogAzureMethod -WorkspaceId '<workspace_id>' -SharedKey '<shared_key>' -LogType 'MyCustomLog'

.EXAMPLE
$batchInfo = New-PodeLogBatchInfo -Size 10 -Timeout 10
$methodId = New-PodeLogAzureMethod -WorkspaceId '<workspace_id>' -SharedKey '<shared_key>' -LogType 'MyCustomLog' -BatchInfo $batchInfo -Source 'my_source'
#>
function New-PodeLogAzureMethod {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [string]
        $Id,

        [Parameter(Mandatory = $true, ParameterSetName = 'Workspace')]
        [string]
        $WorkspaceId,

        [Parameter(Mandatory = $true, ParameterSetName = 'Workspace')]
        [string]
        $SharedKey,

        [Parameter(Mandatory = $true, ParameterSetName = 'Workspace')]
        [string]
        $LogType,

        [Parameter(Mandatory = $true, ParameterSetName = 'DataCollection')]
        [string]
        $Endpoint,

        [Parameter(Mandatory = $true, ParameterSetName = 'DataCollection')]
        [string]
        $ImmutableId,

        [Parameter(Mandatory = $true, ParameterSetName = 'DataCollection')]
        [string]
        $StreamName,

        [Parameter(Mandatory = $true, ParameterSetName = 'DataCollection')]
        [string]
        $ClientId,

        [Parameter(Mandatory = $true, ParameterSetName = 'DataCollection')]
        [string]
        $ClientSecret,

        [Parameter(Mandatory = $true, ParameterSetName = 'DataCollection')]
        [string]
        $TenantId,

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

    # return appropriate azure logging
    switch ($PSCmdlet.ParameterSetName) {
        'Workspace' {
            return New-PodeLogAzureWorkspaceMethod `
                -Id $Id `
                -WorkspaceId $WorkspaceId `
                -SharedKey $SharedKey `
                -LogType $LogType `
                -Source $Source `
                -BatchInfo $BatchInfo `
                -SkipCertificateCheck:$SkipCertificateCheck
        }

        'DataCollection' {
            return New-PodeLogAzureDataCollectionMethod `
                -Id $Id `
                -Endpoint $Endpoint `
                -ImmutableId $ImmutableId `
                -StreamName $StreamName `
                -ClientId $ClientId `
                -ClientSecret $ClientSecret `
                -TenantId $TenantId `
                -Source $Source `
                -BatchInfo $BatchInfo `
                -SkipCertificateCheck:$SkipCertificateCheck
        }
    }
}

<#
.SYNOPSIS
Creates a new set of override options for the Azure Log Method.

.DESCRIPTION
Creates a new set of override options for the Azure Log Method.

.PARAMETER Id
An optional ID to assign to the Log Method to override. (Default: 'Azure')

.PARAMETER Source
An optional source to override the source of the Azure Log Method.

.PARAMETER Ignore
Whether to ignore the Azure Log Method when writing log items.

.EXAMPLE
$override = New-PodeLogAzureOverride -Source 'my_source'

.EXAMPLE
$override = New-PodeLogAzureOverride -Id 'AzureMethod' -Ignore
#>
function New-PodeLogAzureOverride {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter()]
        [string]
        $Id,

        [Parameter()]
        [string]
        $Source,

        [switch]
        $Ignore
    )

    $Id = Protect-PodeValue -Value $Id -Default 'Azure'

    return @{
        Id     = $Id
        Source = $Source
        Ignore = $Ignore.IsPresent
    }
}

<#
.SYNOPSIS
Creates a new AWS CloudWatch Log Method.

.DESCRIPTION
Creates a new AWS CloudWatch Log Method for outputting log items to an AWS CloudWatch Logs group and stream.

.PARAMETER Id
An optional ID to assign to the Log Method. If not supplied, a random ID will be generated.

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
$methodId = New-PodeLogAwsMethod -LogGroupName 'my-log-group' -LogStreamName 'my-log-stream' -Region 'us-east-1' -Token '<token>'

.EXAMPLE
$batchInfo = New-PodeLogBatchInfo -Size 10 -Timeout 10
$methodId = New-PodeLogAwsMethod -LogGroupName 'my-log-group' -LogStreamName 'my-log-stream' -Region 'us-east-1' -Token '<token>' -BatchInfo $batchInfo
#>
function New-PodeLogAwsMethod {
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
        $Region,

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
        param($logItems, $options)

        # build array of events
        $events = @(foreach ($item in $logItems) {
                # build base event object
                $evt = @{
                    event    = $item.Data
                    host     = $PodeContext.Server.ComputerName
                    time     = ConvertTo-PodeUnixEpoch -DateTime $item.Event.Timestamp
                    severity = ConvertTo-PodeSplunkLevel -Level $item.Event.Level
                }

                # get any overrides for this method
                $override = Get-PodeLogOverride -LogEvent $item.Event

                # add source type
                $sourceType = Protect-PodeValue -Value $override.SourceType -Default $options.SourceType
                if (![string]::IsNullOrEmpty($sourceType)) {
                    $evt.sourcetype = $sourceType
                }

                # add source
                $source = Protect-PodeValue -Value $override.Source -Default $options.Source
                if (![string]::IsNullOrEmpty($source)) {
                    $evt.source = $source
                }

                # add index
                $index = Protect-PodeValue -Value $override.Index -Default $options.Index
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
        Authorization = "Bearer $($Token)"
    }

    # add method to server
    $bodyArgs = @{
        SourceType = $SourceType
        Source     = $Source
        Index      = $Index
    }

    return New-PodeLogApiMethod `
        -Id $Id `
        -Type 'AWS' `
        -BatchInfo $BatchInfo `
        -Url "https://logs.$($Region).amazonaws.com/services/collector/event?logGroup=$($LogGroupName)&logStream=$($LogStreamName)" `
        -Headers $headers `
        -BodyScriptBlock $bodyScriptBlock `
        -BodyArguments $bodyArgs `
        -SkipCertificateCheck:$SkipCertificateCheck.IsPresent `
        -Compress
}

<#
.SYNOPSIS
Creates a new set of override options for the AWS Log Method.

.DESCRIPTION
Creates a new set of override options for the AWS Log Method.

.PARAMETER Id
An optional ID to assign to the Log Method to override. (Default: 'AWS')

.PARAMETER Source
An optional source to override the source of the AWS Log Method.

.PARAMETER SourceType
An optional source type to override the source type of the AWS Log Method.

.PARAMETER Index
An optional index to override the index of the AWS Log Method.

.PARAMETER Ignore
Whether to ignore the AWS Log Method when writing log items.

.EXAMPLE
$override = New-PodeLogAwsOverride -Source 'my_source' -SourceType 'syslog' -Index 'main'

.EXAMPLE
$override = New-PodeLogAwsOverride -Id 'AwsMethod' -Ignore
#>
function New-PodeLogAwsOverride {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter()]
        [string]
        $Id,

        [Parameter()]
        [string]
        $Source,

        [Parameter()]
        [string]
        $SourceType,

        [Parameter()]
        [string]
        $Index,

        [switch]
        $Ignore
    )

    $Id = Protect-PodeValue -Value $Id -Default 'AWS'

    return @{
        Id         = $Id
        Source     = $Source
        SourceType = $SourceType
        Index      = $Index
        Ignore     = $Ignore.IsPresent
    }
}

<#
.SYNOPSIS
Creates a new network Log Method.

.DESCRIPTION
Creates a new network Log Method for outputting log items to a remote server over UDP, TCP, or TLS.

.PARAMETER Id
An optional ID to assign to the Log Method. If not supplied, a random ID will be generated.

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
    return Add-PodeLogMethodInternal -Id $Id -Batch $BatchInfo -Config @{
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
Creates a new set of override options for the Network Log Method.

.DESCRIPTION
Creates a new set of override options for the Network Log Method.

.PARAMETER Id
An optional ID to assign to the Log Method to override. (Default: 'Network')

.PARAMETER Ignore
Whether to ignore the Network Log Method when writing log items.

.EXAMPLE
$override = New-PodeLogNetworkOverride -Ignore

.EXAMPLE
$override = New-PodeLogNetworkOverride -Id 'NetworkMethod' -Ignore
#>
function New-PodeLogNetworkOverride {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter()]
        [string]
        $Id,

        [switch]
        $Ignore
    )

    $Id = Protect-PodeValue -Value $Id -Default 'Network'

    return @{
        Id     = $Id
        Ignore = $Ignore.IsPresent
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

<#
.SYNOPSIS
Creates a new Pode Log W3C Info object.

.DESCRIPTION
Creates a new Pode Log W3C Info object with the specified fields, version, and log header settings.

.PARAMETER Fields
The fields to include in the W3C log, created using Add-PodeLogW3CField or Add-PodeLogW3CCustomField.

.PARAMETER Version
The version of the W3C log format. (Default: 1.0)

.PARAMETER NoLogHeader
If supplied, the W3C log will not include the log header.

.EXAMPLE
$fields = @(
    Add-PodeLogW3CField -Name 'date'
    Add-PodeLogW3CField -Name 'time'
    Add-PodeLogW3CField -Name 'c-ip'
    Add-PodeLogW3CField -Name 'cs-method'
    Add-PodeLogW3CField -Name 'cs-uri-stem'
    Add-PodeLogW3CCustomField -Name 'custom-field' -Type 'Request'
)
$info = New-PodeLogW3CInfo -Fields $fields
#>
function New-PodeLogW3CInfo {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [hashtable[]]
        $Fields,

        [Parameter()]
        [version]
        $Version = [version]'1.0',

        [switch]
        $NoLogHeader
    )

    return @{
        Fields      = $Fields
        Version     = $Version
        NoLogHeader = $NoLogHeader.IsPresent
    }
}

<#
.SYNOPSIS
Creates a new Pode Log W3C Field object.

.DESCRIPTION
Creates a new Pode Log W3C Field object with the specified name.

.PARAMETER Name
The name of the W3C field to create.

.EXAMPLE
$field = Add-PodeLogW3CField -Name 'date'
#>
function Add-PodeLogW3CField {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('date', 'time', 'c-ip', 'cs-username', 's-ip', 's-port', 's-computername', 'cs-method', 'cs-uri-stem', 'cs-uri-query', 'sc-status', 'time-taken', 'sc-bytes', 'cs-bytes', 'cs-version', 'cs-host')]
        [string]
        $Name
    )

    return @{
        Type      = 'Standard'
        FieldName = $Name.ToLowerInvariant()
    }
}

<#
.SYNOPSIS
Creates a new Pode Log W3C Custom Field object.

.DESCRIPTION
Creates a new Pode Log W3C Custom Field object with the specified name and type.

.PARAMETER Name
The name of the custom field to create. Custom field names can only contain alphanumeric characters, hyphens, and underscores.

.PARAMETER Type
The type of the custom field, which can be 'Request', 'Response', or 'Environment'.

Request: retrieved from the request headers, and wrapped with "cs(...)" in the W3C log.
Response: retrieved from the response headers, and wrapped with "sc(...)" in the W3C log.
Environment: retrieved from the process environment variables, and prefixed with "x-" in the W3C log.

.EXAMPLE
$field = Add-PodeLogW3CCustomField -Name 'custom-field' -Type 'Request'

.EXAMPLE
$field = Add-PodeLogW3CCustomField -Name 'custom-field' -Type 'Response'

.EXAMPLE
$field = Add-PodeLogW3CCustomField -Name 'custom-field' -Type 'Environment'
#>
function Add-PodeLogW3CCustomField {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[a-z0-9\-_]+$')]
        [string]
        $Name,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Request', 'Response', 'Environment')]
        [string]
        $Type
    )

    $fieldName = switch ($Type) {
        'Request' { "cs($($Name))" }
        'Response' { "sc($($Name))" }
        'Environment' { "x-$($Name)" }
    }

    return @{
        Type      = $Type
        Name      = $Name
        FieldName = $fieldName
    }
}

<#
.SYNOPSIS
Gets the override options for a Pode Log event, for a Log Method.

.DESCRIPTION
Gets the override options for a Pode Log event, for a specific Log Method.

.PARAMETER LogEvent
The Pode Log Event object to retrieve the override options for.

.PARAMETER Id
The ID of the Log Method to retrieve the override options for. (Default: $MethodId)
The Default value is the ID of the Log Method that is currently being processed.

.PARAMETER Type
The type of the Log Method to retrieve the override options for. (Default: $MethodType)
The Default value is the type of the Log Method that is currently being processed.

.EXAMPLE
$override = Get-PodeLogOverride -LogEvent $logEvent

.EXAMPLE
$override = Get-PodeLogOverride -LogEvent $logEvent -Id 'DatadogMethod' -Type 'Datadog'
#>
function Get-PodeLogOverride {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [Pode.Utilities.Logging.IPodeLogEvent]
        $LogEvent,

        [Parameter()]
        [string]
        $Id,

        [Parameter()]
        [string]
        $Type
    )

    $Id = Protect-PodeValue -Value $Id -Default $MethodId
    $Type = Protect-PodeValue -Value $Type -Default $MethodType
    return $LogEvent.GetOverride($Id, $Type)
}