
<#
.SYNOPSIS
    Creates a new terminal logging method in Pode.

.DESCRIPTION
    This function sets up a logging method that outputs log messages to the terminal using Pode's internal terminal logging logic. It allows specifying a custom date format, or uses the ISO 8601 format if requested. Additionally, it supports logging time in UTC.

.PARAMETER DataFormat
    The custom date format to use for log entries. If not provided, a default format of 'dd/MMM/yyyy:HH:mm:ss zzz' is used.
    This parameter is mutually exclusive with the ISO8601 parameter.

.PARAMETER ISO8601
    If set, the date format will follow ISO 8601 (equivalent to -DataFormat 'yyyy-MM-ddTHH:mm:ssK').
    This parameter is mutually exclusive with the DataFormat parameter.

.PARAMETER AsUTC
    If set, the time will be logged in UTC instead of local time.

.PARAMETER DefaultTag
    The tag to use if none is specified on the log entry. Defaults to '-'.

.OUTPUTS
    Hashtable: Returns a hashtable containing the logging method configuration.

.EXAMPLE
    $logMethod = New-PodeTerminalLoggingMethod -DataFormat 'yyyy/MM/dd HH:mm:ss'

    Creates a terminal logging method using the specified custom date format.

.EXAMPLE
    $logMethod = New-PodeTerminalLoggingMethod -ISO8601 -AsUTC

    Creates a terminal logging method that logs messages using the ISO 8601 date format and logs the time in UTC.
#>
function New-PodeTerminalLoggingMethod {
    [CmdletBinding(DefaultParameterSetName = 'DataFormat')]
    [OutputType([hashtable])]
    param(
        [Parameter(ParameterSetName = 'DataFormat')]
        [ValidateScript({
                Test-PodeDateFormat $_
            })]
        [string]
        $DataFormat,

        [Parameter(ParameterSetName = 'ISO8601')]
        [switch]
        $ISO8601,

        [Parameter()]
        [switch]
        $AsUTC,

        [Parameter()]
        [string]
        $DefaultTag = '-'
    )

    # Determine the date format based on parameter set
    switch ($PSCmdlet.ParameterSetName.ToLowerInvariant()) {
        'iso8601' {
            # Use ISO8601 format if specified
            $DataFormat = 'yyyy-MM-ddTHH:mm:ssK'
        }
        default {
            # Use default format if no DataFormat is provided
            if ([string]::IsNullOrEmpty($DataFormat)) {
                $DataFormat = 'dd/MMM/yyyy:HH:mm:ss zzz' # Default format
            }
        }
    }

    # Terminal logging logic
    $methodId = New-PodeGuid
    $PodeContext.Server.Logging.Method[$methodId] = @{
        ScriptBlock = (Get-PodeLoggingTerminalMethod)
        Queue       = [System.Collections.Concurrent.ConcurrentQueue[hashtable]]::new()
    }

    # Return the logging method configuration
    return @{
        Type      = 'Terminal'
        Id        = $methodId
        Batch     = New-PodeLogBatchInfo
        Logger    = @()
        Arguments = @{
            DataFormat = $DataFormat
            AsUTC      = $AsUTC.IsPresent
            DefaultTag = $DefaultTag
        }
    }
}

<#
.SYNOPSIS
    Creates a new file-based logging method in Pode.

.DESCRIPTION
    This function sets up a logging method that outputs log messages to a file. It supports configuring log file paths, names, formats, sizes, and retention policies, along with various log formatting options such as custom date formats or ISO 8601.

.PARAMETER Path
    The file path where the logs will be stored. Defaults to './logs'.

.PARAMETER Name
    The base name for the log files. This parameter is mandatory.

.PARAMETER Format
    The format of the log entries. Supported options are: RFC3164, RFC5424, Simple, and Default (Default: Default).

.PARAMETER Separator
    The character(s) used to separate log fields in each entry. Defaults to a space (' ').

.PARAMETER MaxLength
    The maximum length of log entries. Defaults to -1 (no limit).

.PARAMETER MaxDays
    The maximum number of days to keep log files. Logs older than this will be removed automatically. Defaults to 0 (no automatic removal).

.PARAMETER MaxSize
    The maximum size of a log file in bytes. Once this size is exceeded, a new log file will be created. Defaults to 0 (no size limit).

.PARAMETER FailureAction
    Specifies the action to take if logging fails. Options are: Ignore, Report, Halt (Default: Ignore).

.PARAMETER DataFormat
    The custom date format for log entries. Mutually exclusive with ISO8601.

.PARAMETER Encoding
    The encoding to use for Syslog messages. Supported values are ASCII, BigEndianUnicode, Default, Unicode, UTF32, UTF7, and UTF8. Defaults to UTF8.

.PARAMETER ISO8601
    If set, uses the ISO 8601 date format for log entries. Mutually exclusive with DataFormat.

.PARAMETER AsUTC
    If set, logs the time in UTC instead of the local time.

.PARAMETER DefaultTag
    The tag to use if none is specified on the log entry. Defaults to '-'.

.OUTPUTS
    Hashtable: Returns a hashtable containing the logging method configuration.


.EXAMPLE
    $logMethod = New-PodeFileLoggingMethod -Path './logs' -Name 'requests'

    Creates a new file logging method that stores logs in the './logs' directory with the base name 'requests'.

.EXAMPLE
    $logMethod = New-PodeFileLoggingMethod -Name 'requests' -MaxDays 7 -MaxSize 100MB

    Creates a file logging method that keeps logs for 7 days and creates new files once the log file reaches 100MB in size.
#>
function New-PodeFileLoggingMethod {
    [CmdletBinding(DefaultParameterSetName = 'DataFormat')]
    [OutputType([hashtable])]
    param(
        [string]
        $Path = './logs',

        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter()]
        [ValidateSet('RFC3164', 'RFC5424', 'Simple', 'Default')]
        [string]
        $Format = 'Default',

        [Parameter()]
        [string]
        $Separator = ' ',

        [Parameter()]
        [int]
        $MaxLength = -1,

        [Parameter()]
        [ValidateRange(0, [int]::MaxValue)]
        [int]
        $MaxDays = 0,

        [Parameter()]
        [ValidateRange(0, [int]::MaxValue)]
        [int]
        $MaxSize = 0,

        [Parameter()]
        [ValidateSet('Ignore', 'Report', 'Halt')]
        [string]
        $FailureAction = 'Ignore',

        [Parameter(ParameterSetName = 'DataFormat')]
        [ValidateScript({
                Test-PodeDateFormat $_
            })]
        [string]
        $DataFormat,

        [Parameter()]
        [ValidateSet('ASCII', 'BigEndianUnicode', 'Default', 'Unicode', 'UTF32', 'UTF7', 'UTF8')]
        [string]
        $Encoding = 'UTF8',

        [Parameter(ParameterSetName = 'ISO8601')]
        [switch]
        $ISO8601,

        [Parameter()]
        [switch]
        $AsUTC,

        [Parameter()]
        [string]
        $DefaultTag = '-'
    )

    # Determine the date format based on the parameter set
    switch ($PSCmdlet.ParameterSetName.ToLowerInvariant()) {
        'iso8601' {
            $DataFormat = 'yyyy-MM-ddTHH:mm:ssK' # ISO8601 format
        }
        default {
            if ([string]::IsNullOrEmpty($DataFormat)) {
                $DataFormat = 'dd/MMM/yyyy:HH:mm:ss zzz' # Default format
            }
        }
    }

    # Resolve the log file path
    $Path = (Protect-PodeValue -Value $Path -Default './logs')
    $Path = (Get-PodeRelativePath -Path $Path -JoinRoot -Resolve)
    if (! (Test-Path -Path $Path -PathType Leaf)) {
        $null = New-Item -Path $Path -ItemType Directory -Force
    }
    # Create a unique ID for this logging method
    $methodId = New-PodeGuid

    # Register the logging method in Pode's context
    $PodeContext.Server.Logging.Method[$methodId] = @{
        ScriptBlock = (Get-PodeLoggingFileMethod)
        Queue       = [System.Collections.Concurrent.ConcurrentQueue[hashtable]]::new()
    }

    # Return the logging method configuration
    return @{
        Type      = 'File'
        Id        = $methodId
        Batch     = New-PodeLogBatchInfo
        Logger    = @()
        Arguments = @{
            Name          = $Name
            Path          = $Path
            MaxDays       = $MaxDays
            MaxSize       = $MaxSize
            FileId        = 0
            Date          = $null
            NextClearDown = [datetime]::Now.Date
            FailureAction = $FailureAction
            DataFormat    = $DataFormat
            AsUTC         = $AsUTC.IsPresent
            Encoding      = $Encoding
            Format        = $Format
            MaxLength     = $MaxLength
            Separator     = $Separator
            DefaultTag    = $DefaultTag
        }
    }
}

<#
.SYNOPSIS
    Creates a new Event Viewer logging method in Pode.

.DESCRIPTION
    This function sets up a logging method that outputs log messages to the Windows Event Viewer. It allows configuring the log name, source, and event ID, along with date formatting options like custom formats or ISO 8601.

.PARAMETER EventLogName
    The name of the event log to write to. Defaults to 'Application'.

.PARAMETER Source
    The source of the log entries. Defaults to 'Pode'.

.PARAMETER EventID
    The ID of the event to log. Defaults to 0.

.PARAMETER FailureAction
    Specifies the action to take if logging fails. Options are: Ignore, Report, Halt (Default: Ignore).

.PARAMETER DataFormat
    The custom date format for log entries. Mutually exclusive with ISO8601.

.PARAMETER ISO8601
    If set, uses the ISO 8601 date format for log entries. Mutually exclusive with DataFormat.

.PARAMETER AsUTC
    If set, logs the time in UTC instead of local time.

.OUTPUTS
    Hashtable: Returns a hashtable containing the logging method configuration.

.EXAMPLE
    $logMethod = New-PodeEventViewerLoggingMethod -EventLogName 'Application' -Source 'PodeApp'

    Creates a new Event Viewer logging method that writes to the 'Application' log with the source 'PodeApp'.

.EXAMPLE
    $logMethod = New-PodeEventViewerLoggingMethod -Source 'MyApp' -EventID 1001 -ISO8601

    Creates a new Event Viewer logging method with ISO 8601 date format, writing to the 'MyApp' source and using event ID 1001.

#>
function New-PodeEventViewerLoggingMethod {
    [CmdletBinding(DefaultParameterSetName = 'DataFormat')]
    [OutputType([hashtable])]
    param(
        [string]
        $EventLogName = 'Application',

        [string]
        $Source = 'Pode',

        [int]
        $EventID = 0,

        [ValidateSet('Ignore', 'Report', 'Halt')]
        [string]
        $FailureAction = 'Ignore',

        [Parameter(ParameterSetName = 'DataFormat')]
        [ValidateScript({ Test-PodeDateFormat $_ })]
        [string]
        $DataFormat,

        [Parameter(ParameterSetName = 'ISO8601')]
        [switch]
        $ISO8601,

        [Parameter()]
        [switch]
        $AsUTC
    )

    # Determine the date format based on parameter set
    switch ($PSCmdlet.ParameterSetName.ToLowerInvariant()) {
        'iso8601' {
            $DataFormat = 'yyyy-MM-ddTHH:mm:ssK' # ISO8601 format
        }
        default {
            if ([string]::IsNullOrEmpty($DataFormat)) {
                $DataFormat = 'dd/MMM/yyyy:HH:mm:ss zzz' # Default format
            }
        }
    }

    # Check if the platform is Windows
    if (!(Test-PodeIsWindows)) {
        # Event Viewer logging is only supported on Windows
        throw ($PodeLocale.eventViewerLoggingSupportedOnWindowsOnlyExceptionMessage)
    }

    # Ensure the event source exists in the Event Log
    if (![System.Diagnostics.EventLog]::SourceExists($Source)) {
        [System.Diagnostics.EventLog]::CreateEventSource($Source, $EventLogName)
    }

    # Create the method ID and configure the logging method
    $methodId = New-PodeGuid
    $PodeContext.Server.Logging.Method[$methodId] = @{
        ScriptBlock = (Get-PodeLoggingEventViewerMethod)
        Queue       = [System.Collections.Concurrent.ConcurrentQueue[hashtable]]::new()
    }

    # Return the logging method configuration
    return @{
        Type      = 'EventViewer'
        Id        = $methodId
        Batch     = New-PodeLogBatchInfo
        Logger    = @()
        Arguments = @{
            LogName       = $EventLogName
            Source        = $Source
            ID            = $EventID
            FailureAction = $FailureAction
            DataFormat    = $DataFormat
            AsUTC         = $AsUTC.IsPresent
            Tag           = $Source
        }
    }
}


<#
.SYNOPSIS
    Creates a new custom logging method in Pode.

.DESCRIPTION
    This function sets up a custom logging method that uses a script block to define the logging logic. It supports the option to run the logging method in a separate runspace and allows for custom options, date formatting, and failure handling.

.PARAMETER ScriptBlock
    A non-empty script block that defines the custom logging logic. This parameter is mandatory.

.PARAMETER ArgumentList
    An array of arguments to pass to the custom script block.

.PARAMETER CustomOptions
    A hashtable of custom options that will be passed to the script block when used inside a runspace.

.PARAMETER FailureAction
    Specifies the action to take if logging fails. Options are: Ignore, Report, Halt (Default: Ignore).

.PARAMETER DataFormat
    The custom date format for log entries. Mutually exclusive with ISO8601.

.PARAMETER ISO8601
    If set, uses the ISO 8601 date format for log entries. Mutually exclusive with DataFormat.

.PARAMETER AsUTC
    If set, logs the time in UTC instead of local time.

.EXAMPLE
    $logMethod = New-PodeCustomLoggingMethod -ScriptBlock { param($logItem) Write-Output $logItem } -UseRunspace

    Creates a custom logging method using a script block that writes log items to the output. The method runs in a separate runspace.

.EXAMPLE
    $logMethod = New-PodeCustomLoggingMethod -ScriptBlock { param($logItem) Write-Output $logItem } -DataFormat 'yyyy/MM/dd HH:mm:ss'

    Creates a custom logging method with a custom date format.

.OUTPUTS
    Hashtable: Returns a hashtable containing the custom logging method configuration.
#>
function New-PodeCustomLoggingMethod {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUSeDeclaredVarsMoreThanAssignments', '')]
    [CmdletBinding(DefaultParameterSetName = 'DataFormat')]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({
                if (Test-PodeIsEmpty $_) {
                    # A non-empty ScriptBlock is required for the Custom logging output method
                    throw ($PodeLocale.nonEmptyScriptBlockRequiredForCustomLoggingExceptionMessage)
                }
                return $true
            })
        ]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [object[]]
        $ArgumentList,

        [Parameter()]
        [hashtable]
        $CustomOptions = @{},

        [Parameter()]
        [ValidateSet('Ignore', 'Report', 'Halt')]
        [string]
        $FailureAction = 'Ignore',

        [Parameter(ParameterSetName = 'DataFormat')]
        [ValidateScript({ Test-PodeDateFormat $_ })]
        [string]
        $DataFormat,

        [Parameter(ParameterSetName = 'ISO8601')]
        [switch]
        $ISO8601,

        [Parameter()]
        [switch]
        $AsUTC
    )

    # Determine the date format based on the parameter set
    switch ($PSCmdlet.ParameterSetName.ToLowerInvariant()) {
        'iso8601' {
            $DataFormat = 'yyyy-MM-ddTHH:mm:ssK'
        }
        default {
            if ([string]::IsNullOrEmpty($DataFormat)) {
                $DataFormat = 'dd/MMM/yyyy:HH:mm:ss zzz' # Default format
            }
        }
    }

    # Create the script block for the custom logging method running in a separate runspace
    $enanchedScriptBlock = {
        param($MethodId)

        $log = @{}
        while (!$PodeContext.Tokens.Cancellation.IsCancellationRequested) {
            Start-Sleep -Milliseconds 100

            if ($PodeContext.Server.Logging.Method[$MethodId].Queue.TryDequeue([ref]$log)) {
                if ($null -ne $log) {
                    $Item = $log.item
                    $Options = $log.options
                    $RawItem = $log.rawItem
                    try {
                        # Original ScriptBlock Start
                        <# ScriptBlock #>
                        # Original ScriptBlock End
                    }
                    catch {
                        Invoke-PodeHandleFailure -Message "Custom Logging $MethodId Error. message: $_" -FailureAction $options.FailureAction
                    }
                }
            }
        }
    }

    $methodId = New-PodeGuid

    # Register the enhanced script block in Pode's logging method
    $PodeContext.Server.Logging.Method[$methodId] = @{
        ScriptBlock = [ScriptBlock]::Create($enanchedScriptBlock.ToString().Replace('<# ScriptBlock #>', $ScriptBlock.ToString()))
        Queue       = [System.Collections.Concurrent.ConcurrentQueue[hashtable]]::new()
    }

    return @{
        Type      = 'Custom'
        Id        = $methodId
        Batch     = New-PodeLogBatchInfo
        Logger    = @()
        Arguments = @{
            FailureAction = $FailureAction
            DataFormat    = $DataFormat
            AsUTC         = $AsUTC
        } + $CustomOptions
    }
}

<#
.SYNOPSIS
    Creates a new Syslog logging method in Pode.

.DESCRIPTION
    This function sets up a logging method that sends log messages to a remote Syslog server. It supports various Syslog protocols (RFC3164, RFC5424), transports (UDP, TCP, TLS), and encoding formats. The function also allows for custom date formatting or ISO 8601 compliance and can skip certificate checks for TLS connections.

.PARAMETER Server
    The Syslog server to send logs to. This parameter is mandatory.

.PARAMETER Port
    The port on the Syslog server to send logs to. Defaults to 514.

.PARAMETER Transport
    The transport protocol to use. Supported values are UDP, TCP, and TLS. Defaults to UDP.

.PARAMETER TlsProtocol
    The TLS protocol version to use if TLS transport is selected. Defaults to TLS 1.3.

.PARAMETER SyslogProtocol
    The Syslog protocol to use for message formatting. Supported values are RFC3164 and RFC5424. Defaults to RFC5424.

.PARAMETER Encoding
    The encoding to use for Syslog messages. Supported values are ASCII, BigEndianUnicode, Default, Unicode, UTF32, UTF7, and UTF8. Defaults to UTF8.

.PARAMETER SkipCertificateCheck
    If set, skips certificate validation for TLS connections.

.PARAMETER FailureAction
    Specifies the action to take if logging fails. Options are: Ignore, Report, Halt (Default: Ignore).

.PARAMETER DataFormat
    The custom date format for log entries. Mutually exclusive with ISO8601.

.PARAMETER ISO8601
    If set, uses the ISO 8601 date format for log entries. Mutually exclusive with DataFormat.

.PARAMETER AsUTC
    If set, logs the time in UTC instead of local time.

.PARAMETER DefaultTag
    The tag to use if none is specified on the log entry. Defaults to '-'.

.EXAMPLE
    $logMethod = New-PodeSyslogLoggingMethod -Server '192.168.1.100' -Transport 'TCP' -SyslogProtocol 'RFC3164'

    Creates a new Syslog logging method that sends logs to the Syslog server at 192.168.1.100 using TCP and RFC3164 format.

.EXAMPLE
    $logMethod = New-PodeSyslogLoggingMethod -Server '192.168.1.100' -SyslogProtocol 'RFC5424' -ISO8601 -AsUTC

    Creates a Syslog logging method that uses RFC5424 format with ISO 8601 date formatting and logs time in UTC.

.OUTPUTS
    Hashtable: Returns a hashtable containing the Syslog logging method configuration.
#>
function New-PodeSyslogLoggingMethod {
    [CmdletBinding(DefaultParameterSetName = 'DataFormat')]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Server,

        [Parameter()]
        [Int16]
        $Port = 514,

        [Parameter()]
        [ValidateSet('UDP', 'TCP', 'TLS')]
        [string]
        $Transport = 'UDP',

        [Parameter()]
        [System.Security.Authentication.SslProtocols]
        $TlsProtocol = [System.Security.Authentication.SslProtocols]::Tls13,

        [Parameter()]
        [ValidateSet('RFC3164', 'RFC5424')]
        [string]
        $SyslogProtocol = 'RFC5424',

        [Parameter()]
        [ValidateSet('ASCII', 'BigEndianUnicode', 'Default', 'Unicode', 'UTF32', 'UTF7', 'UTF8')]
        [string]
        $Encoding = 'UTF8',

        [Parameter()]
        [switch]
        $SkipCertificateCheck,

        [Parameter()]
        [ValidateSet('Ignore', 'Report', 'Halt')]
        [string]
        $FailureAction = 'Ignore',

        [Parameter(ParameterSetName = 'DataFormat')]
        [ValidateScript({ Test-PodeDateFormat $_ })]
        [string]
        $DataFormat,

        [Parameter(ParameterSetName = 'ISO8601')]
        [switch]
        $ISO8601,

        [Parameter()]
        [switch]
        $AsUTC,

        [Parameter()]
        [string]
        $DefaultTag = '-'
    )

    # Determine the date format based on parameter set
    switch ($PSCmdlet.ParameterSetName.ToLowerInvariant()) {
        'iso8601' {
            $DataFormat = 'yyyy-MM-ddTHH:mm:ssK' # ISO8601 format
        }
        default {
            if ([string]::IsNullOrEmpty($DataFormat)) {
                $DataFormat = 'dd/MMM/yyyy:HH:mm:ss zzz' # Default format
            }
        }
    }

    # Select encoding based on the provided value
    $selectedEncoding = [System.Text.Encoding]::$Encoding
    if ($null -eq $selectedEncoding) {
        throw ($PodeLocale.invalidEncodingExceptionMessage -f $Encoding)
    }

    # Create the method ID and configure the logging method
    $methodId = New-PodeGuid
    $PodeContext.Server.Logging.Method[$methodId] = @{
        ScriptBlock = (Get-PodeLoggingSysLogMethod)
        Queue       = [System.Collections.Concurrent.ConcurrentQueue[hashtable]]::new()
    }

    # Return the logging method configuration
    return @{
        Type      = 'Syslog'
        Id        = $methodId
        Batch     = New-PodeLogBatchInfo
        Logger    = @()
        Arguments = @{
            Server               = $Server
            Port                 = $Port
            Transport            = $Transport
            Hostname             = $Hostname
            TlsProtocols         = $TlsProtocol
            SkipCertificateCheck = $SkipCertificateCheck.IsPresent
            SyslogProtocol       = $SyslogProtocol
            Encoding             = $selectedEncoding
            FailureAction        = $FailureAction
            DataFormat           = $DataFormat
            AsUTC                = $AsUTC.IsPresent
            DefaultTag           = $DefaultTag
        }
    }
}

<#
.SYNOPSIS
Configures logging to AWS CloudWatch Logs.

.DESCRIPTION
The `New-PodeAwsLoggingMethod` function configures a logging method for AWS CloudWatch Logs. It initializes a logging queue and sends log events to AWS CloudWatch using the specified log group and stream names.

.PARAMETER BaseUrl
The base URL for the AWS CloudWatch Logs API, typically `https://logs.<region>.amazonaws.com`.

.PARAMETER Region
The AWS region where the CloudWatch Log Group resides, such as `us-east-1`.

.PARAMETER LogGroupName
The name of the AWS CloudWatch Log Group to send logs to.

.PARAMETER LogStreamName
The name of the AWS CloudWatch Log Stream within the log group.

.PARAMETER AuthorizationHeader
The AWS authorization header, generated using AWS Signature Version 4.

.PARAMETER FailureAction
Specifies the action to take if the logging request fails. Valid values are `Ignore`, `Report`, and `Halt`. The default is `Ignore`.

.PARAMETER SkipCertificateCheck
If present, skips SSL certificate validation when sending logs.

.PARAMETER AsUTC
If present, converts timestamps to UTC.

.PARAMETER DefaultTag
Sets a default tag for log entries. Defaults to `-`.

.PARAMETER DataFormat
The custom date format for log entries. Mutually exclusive with ISO8601.

.PARAMETER ISO8601
If set, uses the ISO 8601 date format for log entries. Mutually exclusive with DataFormat.

.EXAMPLE
PS> New-PodeAwsLoggingMethod -BaseUrl 'https://logs.us-east-1.amazonaws.com' -Region 'us-east-1' -LogGroupName 'MyLogGroup' -LogStreamName 'MyLogStream' -AuthorizationHeader 'AWS4-HMAC-SHA256 ...'

Configures AWS CloudWatch logging with specified log group, log stream, and AWS authorization details.

.NOTES
This function sends logs to AWS CloudWatch in batches, using a `ConcurrentQueue` to manage queued logs.
#>
function New-PodeAwsLoggingMethod {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $BaseUrl,

        [Parameter(Mandatory = $true)]
        [string]
        $Region,

        [Parameter(Mandatory = $true)]
        [string]
        $LogGroupName,

        [Parameter(Mandatory = $true)]
        [string]
        $LogStreamName,

        [Parameter(Mandatory = $true)]
        [string]
        $AuthorizationHeader,

        [Parameter()]
        [ValidateSet('Ignore', 'Report', 'Halt')]
        [string]
        $FailureAction = 'Ignore',

        [Parameter()]
        [switch]
        $SkipCertificateCheck,

        [Parameter()]
        [switch]
        $AsUTC,

        [Parameter()]
        [string]
        $DefaultTag = '-',

        [Parameter(ParameterSetName = 'DataFormat')]
        [ValidateScript({ Test-PodeDateFormat $_ })]
        [string]
        $DataFormat,

        [Parameter(ParameterSetName = 'ISO8601')]
        [switch]
        $ISO8601
    )

    # Determine the date format based on parameter set
    switch ($PSCmdlet.ParameterSetName.ToLowerInvariant()) {
        'iso8601' {
            $DataFormat = 'yyyy-MM-ddTHH:mm:ssK' # ISO8601 format
        }
        default {
            if ([string]::IsNullOrEmpty($DataFormat)) {
                $DataFormat = 'dd/MMM/yyyy:HH:mm:ss zzz' # Default format
            }
        }
    }

    # Generate a unique ID for this logging method instance.
    $methodId = New-PodeGuid

    # Add the logging method configuration to the PodeContext for tracking and execution.
    $PodeContext.Server.Logging.Method[$methodId] = @{
        # Queue to hold log entries until they can be processed.
        # Using a concurrent queue ensures thread-safe interactions in the runspace.
        Queue       = [System.Collections.Concurrent.ConcurrentQueue[hashtable]]::new()

        # ScriptBlock responsible for processing log entries in a separate runspace.
        # This block continuously dequeues and sends log entries to AWS CloudWatch Logs.
        ScriptBlock = {
            param($MethodId)  # Pass the unique method ID to identify this logging configuration.

            # Temporary hashtable to hold a dequeued log entry.
            $log = @{ }

            # Loop continuously until a cancellation is requested (graceful shutdown).
            while (!$PodeContext.Tokens.Cancellation.IsCancellationRequested) {
                # Brief pause to reduce CPU usage in the loop.
                Start-Sleep -Milliseconds 100

                # Attempt to dequeue a log entry from the queue.
                if ($PodeContext.Server.Logging.Method[$MethodId].Queue.TryDequeue([ref]$log)) {
                    # Only process if a valid log entry was dequeued.
                    if ($null -ne $log) {
                        # Retrieve log data and configuration options.
                        $Item = $log.Item
                        $Options = $log.Options
                        $RawItem = $log.RawItem

                        # Ensure both $Item and $RawItem are treated as arrays to handle multiple log entries.
                        $Item = @($Item)
                        $RawItem = @($RawItem)

                        # Define the AWS CloudWatch Logs endpoint URL.
                        $url = "https://logs.$($Options.Region).amazonaws.com"

                        # Set up headers with the AWS authorization header and content type.
                        $headers = @{
                            'X-Amz-Date'    = (Get-Date -Format 'yyyyMMddTHHmmssZ')  # Current timestamp in AWS-required format
                            'Content-Type'  = 'application/x-amz-json-1.1'
                            'X-Amz-Target'  = 'Logs_20140328.PutLogEvents'  # AWS target for CloudWatch log ingestion
                            'Authorization' = $Options.AuthorizationHeader  # AWS Signature v4 for authentication
                        }

                        # Format each log entry for CloudWatch Logs.
                        $events = $Item | ForEach-Object {
                            @{
                                message   = ($_ | Protect-PodeLogItem)  # Sanitize log message content
                                timestamp = [math]::Round(($RawItem.Date).ToUniversalTime().Subtract(([datetime]::UnixEpoch)).TotalMilliseconds)  # Timestamp in milliseconds since epoch
                            }
                        }

                        # Create the payload body for AWS CloudWatch Logs.
                        $body = @{
                            logGroupName  = $Options.LogGroupName  # Target log group
                            logStreamName = $Options.LogStreamName  # Target log stream within the group
                            logEvents     = $events
                        } | ConvertTo-Json -Compress

                        # Send the log data to CloudWatch Logs via HTTP POST.
                        try {
                            Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $body -SkipCertificateCheck:$Options.SkipCertificateCheck
                        }
                        catch {
                            # Handle any failures based on the configured FailureAction (e.g., Ignore, Report, Halt).
                            Invoke-PodeHandleFailure -Message "Failed to send log to AWS CloudWatch Logs: $_" -FailureAction $Options.FailureAction
                        }
                    }
                }
            }
        }

    }

    # Return the logging method configuration as a hashtable.
    return @{
        Type      = 'AWS'  # Specifies the type of logging platform.
        Id        = $methodId  # Unique identifier for this logging method.
        Batch     = New-PodeLogBatchInfo  # Contains batch information for Pode logging.
        Logger    = @()  # Initialize an empty logger array if needed for Pode processing.
        Arguments = @{
            BaseUrl              = $BaseUrl
            Region               = $Region
            LogGroupName         = $LogGroupName
            LogStreamName        = $LogStreamName
            AuthorizationHeader  = $AuthorizationHeader
            FailureAction        = $FailureAction
            SkipCertificateCheck = $SkipCertificateCheck.IsPresent
            AsUTC                = $AsUTC.IsPresent
            DefaultTag           = $DefaultTag
            DataFormat           = $DataFormat
        }
    }
}

<#
.SYNOPSIS
Configures logging to Azure Monitor Logs.

.DESCRIPTION
The `New-PodeAzureLoggingMethod` function sets up logging for Azure Monitor Logs, allowing log data to be sent to a specified Azure Log Analytics workspace. It uses the shared key authorization method to authenticate with Azure.

.PARAMETER WorkspaceId
The Azure Log Analytics Workspace ID.

.PARAMETER AuthorizationHeader
The authorization header for Azure, generated using the Workspace ID and shared key.

.PARAMETER LogType
The custom log type name in Azure Monitor. Defaults to `CustomLog`.

.PARAMETER FailureAction
Specifies the action to take if the logging request fails. Valid values are `Ignore`, `Report`, and `Halt`. The default is `Ignore`.

.PARAMETER SkipCertificateCheck
If present, skips SSL certificate validation when sending logs.

.PARAMETER AsUTC
If present, converts timestamps to UTC.

.PARAMETER DefaultTag
Sets a default tag for log entries. Defaults to `-`.

.PARAMETER DataFormat
The custom date format for log entries. Mutually exclusive with ISO8601.

.PARAMETER ISO8601
If set, uses the ISO 8601 date format for log entries. Mutually exclusive with DataFormat.

.EXAMPLE
PS> New-PodeAzureLoggingMethod -WorkspaceId '12345' -AuthorizationHeader 'SharedKey 12345:abcdef...' -LogType 'ApplicationLogs'

Sets up Azure Monitor logging with the specified workspace ID and authorization details.

.NOTES
This function sends logs to Azure Monitor Logs using the Azure REST API, formatted for ingestion by Azure Log Analytics.
#>
function New-PodeAzureLoggingMethod {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $WorkspaceId,

        [Parameter(Mandatory = $true)]
        [string]
        $AuthorizationHeader, # Azure Shared Key authorization

        [Parameter()]
        [string]
        $LogType = 'CustomLog',

        [Parameter()]
        [ValidateSet('Ignore', 'Report', 'Halt')]
        [string]
        $FailureAction = 'Ignore',

        [Parameter()]
        [switch]
        $SkipCertificateCheck,

        [Parameter()]
        [switch]
        $AsUTC,

        [Parameter()]
        [string]
        $DefaultTag = '-',

        [Parameter(ParameterSetName = 'DataFormat')]
        [ValidateScript({ Test-PodeDateFormat $_ })]
        [string]
        $DataFormat,

        [Parameter(ParameterSetName = 'ISO8601')]
        [switch]
        $ISO8601
    )

    # Determine the date format based on parameter set
    switch ($PSCmdlet.ParameterSetName.ToLowerInvariant()) {
        'iso8601' {
            $DataFormat = 'yyyy-MM-ddTHH:mm:ssK' # ISO8601 format
        }
        default {
            if ([string]::IsNullOrEmpty($DataFormat)) {
                $DataFormat = 'dd/MMM/yyyy:HH:mm:ss zzz' # Default format
            }
        }
    }

    # Generate a unique ID for this logging method instance.
    $methodId = New-PodeGuid

    # Add the logging method configuration to the PodeContext for tracking and execution.
    $PodeContext.Server.Logging.Method[$methodId] = @{
        # Queue to hold log entries until they can be processed.
        # Using a concurrent queue ensures thread-safe interactions in the runspace.
        Queue       = [System.Collections.Concurrent.ConcurrentQueue[hashtable]]::new()

        # ScriptBlock responsible for processing log entries in a separate runspace.
        # This block continuously dequeues and sends log entries to Azure Monitor.
        ScriptBlock = {
            param($MethodId)  # Pass the unique method ID to identify this logging configuration.

            # Temporary hashtable to hold a dequeued log entry.
            $log = @{ }

            # Loop continuously until a cancellation is requested (graceful shutdown).
            while (!$PodeContext.Tokens.Cancellation.IsCancellationRequested) {
                # Brief pause to reduce CPU usage in the loop.
                Start-Sleep -Milliseconds 100

                # Attempt to dequeue a log entry from the queue.
                if ($PodeContext.Server.Logging.Method[$MethodId].Queue.TryDequeue([ref]$log)) {
                    # Only process if a valid log entry was dequeued.
                    if ($null -ne $log) {
                        # Retrieve log data and configuration options.
                        $Item = $log.Item
                        $Options = $log.Options
                        $RawItem = $log.RawItem

                        # Ensure both $Item and $RawItem are treated as arrays to handle multiple log entries.
                        $Item = @($Item)
                        $RawItem = @($RawItem)

                        # Define the Azure Monitor HTTP Data Collector API endpoint URL for the specified workspace.
                        $url = "https://$($Options.WorkspaceId).ods.opinsights.azure.com/api/logs?api-version=2016-04-01"

                        # Set up headers, including the authorization header, log type, and time-generated field.
                        $headers = @{
                            'Authorization'        = $Options.AuthorizationHeader  # Azure Shared Key
                            'Log-Type'             = $Options.LogType  # Specifies the Log Type name
                            'x-ms-date'            = (Get-Date -Format 'R')  # RFC1123 date format for request header
                            'time-generated-field' = 'timestamp'
                        }

                        # Format each log entry for Azure Monitor.
                        $records = $Item | ForEach-Object {
                            @{
                                message   = ($_ | Protect-PodeLogItem)  # Sanitize log message content
                                severity  = $RawItem.Level.ToUpperInvariant()  # Set log severity level
                                timestamp = $RawItem.Date.ToString('yyyy-MM-ddTHH:mm:ss.fffZ')  # Format timestamp in ISO 8601
                                tag       = $RawItem.Tag  # Include tag if provided
                            }
                        }

                        # Convert the list of records to JSON format for Azure Monitor ingestion.
                        $body = $records | ConvertTo-Json -Compress

                        # Send the log data to Azure Monitor via HTTP POST.
                        try {
                            Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $body -SkipCertificateCheck:$Options.SkipCertificateCheck
                        }
                        catch {
                            # Handle any failures based on the configured FailureAction (e.g., Ignore, Report, Halt).
                            Invoke-PodeHandleFailure -Message "Failed to send log to Azure Monitor: $_" -FailureAction $Options.FailureAction
                        }
                    }
                }
            }
        }
    }

    # Return the logging method configuration as a hashtable.
    return @{
        Type      = 'Azure'  # Specifies the type of logging platform.
        Id        = $methodId  # Unique identifier for this logging method.
        Batch     = New-PodeLogBatchInfo  # Contains batch information for Pode logging.
        Logger    = @()  # Initialize an empty logger array if needed for Pode processing.
        Arguments = @{
            WorkspaceId          = $WorkspaceId
            AuthorizationHeader  = $AuthorizationHeader
            LogType              = $LogType
            FailureAction        = $FailureAction
            SkipCertificateCheck = $SkipCertificateCheck.IsPresent
            AsUTC                = $AsUTC.IsPresent
            DefaultTag           = $DefaultTag
            DataFormat           = $DataFormat
        }
    }
}

<#
.SYNOPSIS
Configures logging to Google Cloud Logging.

.DESCRIPTION
The `New-PodeGoogleLoggingMethod` function sets up logging for Google Cloud Logging, allowing log entries to be sent to Google Cloud using the project ID and access token for authentication.

.PARAMETER ProjectId
The Google Cloud Project ID.

.PARAMETER AccessToken
OAuth 2.0 access token for authenticating with Google Cloud.

.PARAMETER LogName
The name of the log in Google Cloud Logging. Defaults to `default_log`.

.PARAMETER FailureAction
Specifies the action to take if the logging request fails. Valid values are `Ignore`, `Report`, and `Halt`. The default is `Ignore`.

.PARAMETER SkipCertificateCheck
If present, skips SSL certificate validation when sending logs.

.PARAMETER AsUTC
If present, converts timestamps to UTC.

.PARAMETER DefaultTag
Sets a default tag for log entries. Defaults to `-`.

.PARAMETER DataFormat
The custom date format for log entries. Mutually exclusive with ISO8601.

.PARAMETER ISO8601
If set, uses the ISO 8601 date format for log entries. Mutually exclusive with DataFormat.

.EXAMPLE
PS> New-PodeGoogleLoggingMethod -ProjectId 'my-project-id' -AccessToken 'ya29.a0AfH6SM...' -LogName 'ApplicationLogs'

Sets up Google Cloud Logging with the specified project ID and access token.

.NOTES
This function sends log entries to Google Cloud Logging using the Google Cloud Logging REST API, allowing for structured logging within a specific project.
#>
function New-PodeGoogleLoggingMethod {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $ProjectId,

        [Parameter(Mandatory = $true)]
        [string]
        $AccessToken, # OAuth 2.0 token

        [Parameter()]
        [string]
        $LogName = 'default_log',

        [Parameter()]
        [ValidateSet('Ignore', 'Report', 'Halt')]
        [string]
        $FailureAction = 'Ignore',

        [Parameter()]
        [switch]
        $SkipCertificateCheck,

        [Parameter()]
        [switch]
        $AsUTC,

        [Parameter()]
        [string]
        $DefaultTag = '-',

        [Parameter(ParameterSetName = 'DataFormat')]
        [ValidateScript({ Test-PodeDateFormat $_ })]
        [string]
        $DataFormat,

        [Parameter(ParameterSetName = 'ISO8601')]
        [switch]
        $ISO8601
    )

    # Determine the date format based on parameter set
    switch ($PSCmdlet.ParameterSetName.ToLowerInvariant()) {
        'iso8601' {
            $DataFormat = 'yyyy-MM-ddTHH:mm:ssK' # ISO8601 format
        }
        default {
            if ([string]::IsNullOrEmpty($DataFormat)) {
                $DataFormat = 'dd/MMM/yyyy:HH:mm:ss zzz' # Default format
            }
        }
    }

    # Generate a unique ID for this logging method instance.
    $methodId = New-PodeGuid

    # Add the logging method configuration to the PodeContext for tracking and execution.
    $PodeContext.Server.Logging.Method[$methodId] = @{
        # Queue to hold log entries until they can be processed.
        # Using a concurrent queue ensures thread-safe interactions in the runspace.
        Queue       = [System.Collections.Concurrent.ConcurrentQueue[hashtable]]::new()

        # ScriptBlock responsible for processing log entries in a separate runspace.
        # This block continuously dequeues and sends log entries to Google Cloud Logging.
        ScriptBlock = {
            param($MethodId)  # Pass the unique method ID to identify this logging configuration.

            # Temporary hashtable to hold a dequeued log entry.
            $log = @{ }

            # Loop continuously until a cancellation is requested (graceful shutdown).
            while (!$PodeContext.Tokens.Cancellation.IsCancellationRequested) {
                # Brief pause to reduce CPU usage in the loop.
                Start-Sleep -Milliseconds 100

                # Attempt to dequeue a log entry from the queue.
                if ($PodeContext.Server.Logging.Method[$MethodId].Queue.TryDequeue([ref]$log)) {
                    # Only process if a valid log entry was dequeued.
                    if ($null -ne $log) {
                        # Retrieve log data and configuration options.
                        $Item = $log.Item
                        $Options = $log.Options
                        $RawItem = $log.RawItem

                        # Ensure both $Item and $RawItem are treated as arrays to handle multiple log entries.
                        $Item = @($Item)
                        $RawItem = @($RawItem)

                        # Define the Google Cloud Logging API endpoint URL.
                        $url = 'https://logging.googleapis.com/v2/entries:write'

                        # Set up headers with the authorization token and JSON content type.
                        $headers = @{
                            'Authorization' = "Bearer $($Options.AccessToken)"  # OAuth 2.0 Bearer token
                            'Content-Type'  = 'application/json'
                        }

                        # Format each log entry for Google Cloud Logging.
                        $entries = $Item | ForEach-Object {
                            @{
                                textPayload = ($_ | Protect-PodeLogItem)  # Sanitize log message content
                                severity    = $RawItem.Level.ToUpperInvariant()  # Set log severity level
                                timestamp   = $RawItem.Date.ToString('yyyy-MM-ddTHH:mm:ss.fffZ')  # Format timestamp in ISO 8601
                                labels      = @{
                                    tag = $RawItem.Tag  # Include tag if provided
                                }
                                resource    = @{
                                    type   = 'global'  # Set resource type to global
                                    labels = @{
                                        project_id = $Options.ProjectId  # Add the project ID
                                    }
                                }
                            }
                        }

                        # Create the payload body for Google Cloud Logging.
                        $body = @{
                            entries = $entries
                            logName = "projects/$($Options.ProjectId)/logs/$($Options.LogName)"  # Define log name path
                        } | ConvertTo-Json -Compress

                        # Send the log data to Google Cloud Logging via HTTP POST.
                        try {
                            Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $body -SkipCertificateCheck:$Options.SkipCertificateCheck
                        }
                        catch {
                            # Handle any failures based on the configured FailureAction (e.g., Ignore, Report, Halt).
                            Invoke-PodeHandleFailure -Message "Failed to send log to Google Cloud Logging: $_" -FailureAction $Options.FailureAction
                        }
                    }
                }
            }
        }
    }

    # Return the logging method configuration as a hashtable.
    return @{
        Type      = 'Google'  # Specifies the type of logging platform.
        Id        = $methodId  # Unique identifier for this logging method.
        Batch     = New-PodeLogBatchInfo  # Contains batch information for Pode logging.
        Logger    = @()  # Initialize an empty logger array if needed for Pode processing.
        Arguments = @{
            ProjectId            = $ProjectId
            AccessToken          = $AccessToken
            LogName              = $LogName
            FailureAction        = $FailureAction
            SkipCertificateCheck = $SkipCertificateCheck.IsPresent
            AsUTC                = $AsUTC.IsPresent
            DefaultTag           = $DefaultTag
            DataFormat           = $DataFormat
        }
    }
}

<#
.SYNOPSIS
Configures logging to Datadog Logs.

.DESCRIPTION
The `New-PodeDatadogLoggingMethod` function sets up logging for Datadog, allowing log entries to be sent to Datadog’s log intake endpoint using the provided API key.

.PARAMETER ApiKey
The Datadog API key used to authenticate requests.

.PARAMETER BaseUrl
The Datadog intake URL, typically `https://http-intake.logs.datadoghq.com/v1/input`.

.PARAMETER FailureAction
Specifies the action to take if the logging request fails. Valid values are `Ignore`, `Report`, and `Halt`. The default is `Ignore`.

.PARAMETER SkipCertificateCheck
If present, skips SSL certificate validation when sending logs.

.PARAMETER AsUTC
If present, converts timestamps to UTC.

.PARAMETER DefaultTag
Sets a default tag for log entries. Defaults to `-`.

.PARAMETER DataFormat
The custom date format for log entries. Mutually exclusive with ISO8601.

.PARAMETER ISO8601
If set, uses the ISO 8601 date format for log entries. Mutually exclusive with DataFormat.

.EXAMPLE
PS> New-PodeDatadogLoggingMethod -ApiKey 'my-datadog-api-key' -BaseUrl 'https://http-intake.logs.datadoghq.com/v1/input'

Configures Datadog logging using the provided API key and URL.

.NOTES
This function sends logs to Datadog Logs using a REST API call with the API key as authorization.
#>
function New-PodeDatadogLoggingMethod {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $ApiKey,

        [Parameter(Mandatory = $true)]
        [string]
        $BaseUrl,

        [Parameter()]
        [ValidateSet('Ignore', 'Report', 'Halt')]
        [string]
        $FailureAction = 'Ignore',

        [Parameter()]
        [switch]
        $SkipCertificateCheck,

        [Parameter()]
        [switch]
        $AsUTC,

        [Parameter()]
        [string]
        $DefaultTag = '-',

        [Parameter(ParameterSetName = 'DataFormat')]
        [ValidateScript({ Test-PodeDateFormat $_ })]
        [string]
        $DataFormat,

        [Parameter(ParameterSetName = 'ISO8601')]
        [switch]
        $ISO8601
    )

    # Determine the date format based on parameter set
    switch ($PSCmdlet.ParameterSetName.ToLowerInvariant()) {
        'iso8601' {
            $DataFormat = 'yyyy-MM-ddTHH:mm:ssK' # ISO8601 format
        }
        default {
            if ([string]::IsNullOrEmpty($DataFormat)) {
                $DataFormat = 'dd/MMM/yyyy:HH:mm:ss zzz' # Default format
            }
        }
    }

    # Generate a unique ID for this logging method instance.
    $methodId = New-PodeGuid

    # Add the logging method configuration to the PodeContext for tracking and execution.
    $PodeContext.Server.Logging.Method[$methodId] = @{
        # Queue to hold log entries until they can be processed.
        # Using a concurrent queue ensures thread-safe interactions in the runspace.
        Queue       = [System.Collections.Concurrent.ConcurrentQueue[hashtable]]::new()

        # ScriptBlock responsible for processing log entries in a separate runspace.
        # This block continuously dequeues and sends log entries to Datadog.
        ScriptBlock = {
            param($MethodId)  # Pass the unique method ID to identify this logging configuration.

            # Temporary hashtable to hold a dequeued log entry.
            $log = @{ }

            # Loop continuously until a cancellation is requested (graceful shutdown).
            while (!$PodeContext.Tokens.Cancellation.IsCancellationRequested) {
                # Brief pause to reduce CPU usage in the loop.
                Start-Sleep -Milliseconds 100

                # Attempt to dequeue a log entry from the queue.
                if ($PodeContext.Server.Logging.Method[$MethodId].Queue.TryDequeue([ref]$log)) {
                    # Only process if a valid log entry was dequeued.
                    if ($null -ne $log) {
                        # Retrieve log data and configuration options.
                        $Item = $log.Item
                        $Options = $log.Options
                        $RawItem = $log.RawItem

                        # Ensure both $Item and $RawItem are treated as arrays to handle multiple log entries.
                        $Item = @($Item)
                        $RawItem = @($RawItem)

                        # Construct the Datadog intake URL for log ingestion.
                        $url = $Options.BaseUrl

                        # Set up headers with the Datadog API key and JSON content type.
                        $headers = @{
                            'DD-API-KEY'   = $Options.ApiKey  # API key for Datadog
                            'Content-Type' = 'application/json'
                        }

                        # Format each log entry for Datadog.
                        $events = $Item | ForEach-Object {
                            @{
                                message       = ($_ | Protect-PodeLogItem)  # Sanitize log message content
                                host          = $PodeContext.Server.ComputerName  # Add hostname
                                service       = $RawItem.Tag  # Use tag as the service if provided
                                date_happened = [math]::Round(($RawItem.Date).ToUniversalTime().Subtract(([datetime]::UnixEpoch)).TotalSeconds)  # Convert timestamp to seconds since epoch
                                status        = $RawItem.Level.ToUpperInvariant()  # Set log severity level
                            }
                        }

                        # Convert the list of events to JSON format for Datadog ingestion.
                        $body = $events | ConvertTo-Json -Compress

                        # Send the log data to Datadog via HTTP POST.
                        try {
                            Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $body -SkipCertificateCheck:$Options.SkipCertificateCheck
                        }
                        catch {
                            # Handle any failures based on the configured FailureAction (e.g., Ignore, Report, Halt).
                            Invoke-PodeHandleFailure -Message "Failed to send log to Datadog: $_" -FailureAction $Options.FailureAction
                        }
                    }
                }
            }
        }
    }

    # Return the logging method configuration as a hashtable.
    return @{
        Type      = 'Datadog'  # Specifies the type of logging platform.
        Id        = $methodId  # Unique identifier for this logging method.
        Batch     = New-PodeLogBatchInfo  # Contains batch information for Pode logging.
        Logger    = @()  # Initialize an empty logger array if needed for Pode processing.
        Arguments = @{
            ApiKey               = $ApiKey
            BaseUrl              = $BaseUrl
            FailureAction        = $FailureAction
            SkipCertificateCheck = $SkipCertificateCheck.IsPresent
            AsUTC                = $AsUTC.IsPresent
            DefaultTag           = $DefaultTag
            DataFormat           = $DataFormat
        }
    }
}


<#
.SYNOPSIS
Configures logging to Elasticsearch.

.DESCRIPTION
The `New-PodeElasticsearchLoggingMethod` function configures logging for Elasticsearch, allowing log entries to be sent as documents to a specified Elasticsearch index.

.PARAMETER BaseUrl
The base URL for the Elasticsearch API, typically `http://<ELASTICSEARCH_SERVER_IP>:9200`.

.PARAMETER IndexName
The name of the Elasticsearch index where log entries will be stored.

.PARAMETER FailureAction
Specifies the action to take if the logging request fails. Valid values are `Ignore`, `Report`, and `Halt`. The default is `Ignore`.

.PARAMETER SkipCertificateCheck
If present, skips SSL certificate validation when sending logs.

.PARAMETER AsUTC
If present, converts timestamps to UTC.

.PARAMETER DefaultTag
Sets a default tag for log entries. Defaults to `-`.

.PARAMETER DataFormat
The custom date format for log entries. Mutually exclusive with ISO8601.

.PARAMETER ISO8601
If set, uses the ISO 8601 date format for log entries. Mutually exclusive with DataFormat.

.EXAMPLE
PS> New-PodeElasticsearchLoggingMethod -BaseUrl 'http://localhost:9200' -IndexName 'application-logs'

Sets up Elasticsearch logging with the specified base URL and index name.

.NOTES
This function sends log entries to Elasticsearch by creating documents in the specified index.
#>
function New-PodeElasticsearchLoggingMethod {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $BaseUrl,

        [Parameter(Mandatory = $true)]
        [string]
        $IndexName,

        [Parameter()]
        [ValidateSet('Ignore', 'Report', 'Halt')]
        [string]
        $FailureAction = 'Ignore',

        [Parameter()]
        [switch]
        $SkipCertificateCheck,

        [Parameter()]
        [switch]
        $AsUTC,

        [Parameter()]
        [string]
        $DefaultTag = '-',

        [Parameter(ParameterSetName = 'DataFormat')]
        [ValidateScript({ Test-PodeDateFormat $_ })]
        [string]
        $DataFormat,

        [Parameter(ParameterSetName = 'ISO8601')]
        [switch]
        $ISO8601
    )

    # Determine the date format based on parameter set
    switch ($PSCmdlet.ParameterSetName.ToLowerInvariant()) {
        'iso8601' {
            $DataFormat = 'yyyy-MM-ddTHH:mm:ssK' # ISO8601 format
        }
        default {
            if ([string]::IsNullOrEmpty($DataFormat)) {
                $DataFormat = 'dd/MMM/yyyy:HH:mm:ss zzz' # Default format
            }
        }
    }

    # Generate a unique ID for this logging method instance.
    $methodId = New-PodeGuid

    # Add the logging method configuration to the PodeContext for tracking and execution.
    $PodeContext.Server.Logging.Method[$methodId] = @{
        # Queue to hold log entries until they can be processed.
        # Using a concurrent queue ensures thread-safe interactions in the runspace.
        Queue       = [System.Collections.Concurrent.ConcurrentQueue[hashtable]]::new()

        # ScriptBlock responsible for processing log entries in a separate runspace.
        # This block continuously dequeues and sends log entries to Elasticsearch.
        ScriptBlock = {
            param($MethodId)  # Pass the unique method ID to identify this logging configuration.

            # Temporary hashtable to hold a dequeued log entry.
            $log = @{ }

            # Loop continuously until a cancellation is requested (graceful shutdown).
            while (!$PodeContext.Tokens.Cancellation.IsCancellationRequested) {
                # Brief pause to reduce CPU usage in the loop.
                Start-Sleep -Milliseconds 100

                # Attempt to dequeue a log entry from the queue.
                if ($PodeContext.Server.Logging.Method[$MethodId].Queue.TryDequeue([ref]$log)) {
                    # Only process if a valid log entry was dequeued.
                    if ($null -ne $log) {
                        # Retrieve log data and configuration options.
                        $Item = $log.Item
                        $Options = $log.Options
                        $RawItem = $log.RawItem

                        # Ensure both $Item and $RawItem are treated as arrays to handle multiple log entries.
                        $Item = @($Item)
                        $RawItem = @($RawItem)

                        # Construct the Elasticsearch URL for document ingestion using the specified index.
                        $url = "$($Options.BaseUrl)/$($Options.IndexName)/_doc/"

                        # Set up headers for JSON content type required by Elasticsearch.
                        $headers = @{
                            'Content-Type' = 'application/json'
                        }

                        # Format each log entry for Elasticsearch.
                        $documents = $Item | ForEach-Object {
                            @{
                                message   = ($_ | Protect-PodeLogItem)  # Sanitize log message content
                                timestamp = $RawItem.Date.ToString('yyyy-MM-ddTHH:mm:ss.fffZ')  # Format timestamp in ISO 8601
                                severity  = $RawItem.Level.ToUpperInvariant()  # Set log severity level
                                host      = $PodeContext.Server.ComputerName  # Add hostname
                                tag       = $RawItem.Tag  # Include tag if provided
                            }
                        }

                        # Convert the list of documents to JSON format for Elasticsearch ingestion.
                        $body = $documents | ConvertTo-Json -Compress

                        # Send the log data to Elasticsearch via HTTP POST.
                        try {
                            Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $body -SkipCertificateCheck:$Options.SkipCertificateCheck
                        }
                        catch {
                            # Handle any failures based on the configured FailureAction (e.g., Ignore, Report, Halt).
                            Invoke-PodeHandleFailure -Message "Failed to send log to Elasticsearch: $_" -FailureAction $Options.FailureAction
                        }
                    }
                }
            }
        }
    }

    # Return the logging method configuration as a hashtable.
    return @{
        Type      = 'Elasticsearch'  # Specifies the type of logging platform.
        Id        = $methodId  # Unique identifier for this logging method.
        Batch     = New-PodeLogBatchInfo  # Contains batch information for Pode logging.
        Logger    = @()  # Initialize an empty logger array if needed for Pode processing.
        Arguments = @{
            BaseUrl              = $BaseUrl
            IndexName            = $IndexName
            FailureAction        = $FailureAction
            SkipCertificateCheck = $SkipCertificateCheck.IsPresent
            AsUTC                = $AsUTC.IsPresent
            DefaultTag           = $DefaultTag
            DataFormat           = $DataFormat
        }
    }
}

<#
.SYNOPSIS
Configures logging to Graylog.

.DESCRIPTION
The `New-PodeGraylogLoggingMethod` function sets up logging for Graylog, sending log entries to the Graylog server using GELF (Graylog Extended Log Format) over HTTP.

.PARAMETER BaseUrl
The base URL for the Graylog API, typically `http://<GRAYLOG_SERVER_IP>:12201/gelf`.

.PARAMETER FailureAction
Specifies the action to take if the logging request fails. Valid values are `Ignore`, `Report`, and `Halt`. The default is `Ignore`.

.PARAMETER SkipCertificateCheck
If present, skips SSL certificate validation when sending logs.

.PARAMETER AsUTC
If present, converts timestamps to UTC.

.PARAMETER DefaultTag
Sets a default tag for log entries. Defaults to `-`.

.PARAMETER DataFormat
The custom date format for log entries. Mutually exclusive with ISO8601.

.PARAMETER ISO8601
If set, uses the ISO 8601 date format for log entries. Mutually exclusive with DataFormat.

.EXAMPLE
PS> New-PodeGraylogLoggingMethod -BaseUrl 'http://graylog-server:12201/gelf'

Configures Graylog logging using the specified base URL.

.NOTES
This function sends logs to Graylog using GELF, which allows for structured logging.
#>
function New-PodeGraylogLoggingMethod {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $BaseUrl,

        [Parameter()]
        [ValidateSet('Ignore', 'Report', 'Halt')]
        [string]
        $FailureAction = 'Ignore',

        [Parameter()]
        [switch]
        $SkipCertificateCheck,

        [Parameter()]
        [switch]
        $AsUTC,

        [Parameter()]
        [string]
        $DefaultTag = '-',

        [Parameter(ParameterSetName = 'DataFormat')]
        [ValidateScript({ Test-PodeDateFormat $_ })]
        [string]
        $DataFormat,

        [Parameter(ParameterSetName = 'ISO8601')]
        [switch]
        $ISO8601
    )

    # Determine the date format based on parameter set
    switch ($PSCmdlet.ParameterSetName.ToLowerInvariant()) {
        'iso8601' {
            $DataFormat = 'yyyy-MM-ddTHH:mm:ssK' # ISO8601 format
        }
        default {
            if ([string]::IsNullOrEmpty($DataFormat)) {
                $DataFormat = 'dd/MMM/yyyy:HH:mm:ss zzz' # Default format
            }
        }
    }

    # Generate a unique ID for this logging method instance.
    $methodId = New-PodeGuid

    # Add the logging method configuration to the PodeContext for tracking and execution.
    $PodeContext.Server.Logging.Method[$methodId] = @{
        # Queue to hold log entries until they can be processed.
        # Using a concurrent queue ensures thread-safe interactions in the runspace.
        Queue       = [System.Collections.Concurrent.ConcurrentQueue[hashtable]]::new()

        # ScriptBlock responsible for processing log entries in a separate runspace.
        # This block continuously dequeues and sends log entries to Graylog.
        ScriptBlock = {
            param($MethodId)  # Pass the unique method ID to identify this logging configuration.

            # Temporary hashtable to hold a dequeued log entry.
            $log = @{ }

            # Loop continuously until a cancellation is requested (graceful shutdown).
            while (!$PodeContext.Tokens.Cancellation.IsCancellationRequested) {
                # Brief pause to reduce CPU usage in the loop.
                Start-Sleep -Milliseconds 100

                # Attempt to dequeue a log entry from the queue.
                if ($PodeContext.Server.Logging.Method[$MethodId].Queue.TryDequeue([ref]$log)) {
                    # Only process if a valid log entry was dequeued.
                    if ($null -ne $log) {
                        # Retrieve log data and configuration options.
                        $Item = $log.Item
                        $Options = $log.Options
                        $RawItem = $log.RawItem

                        # Ensure both $Item and $RawItem are treated as arrays to handle multiple log entries.
                        $Item = @($Item)
                        $RawItem = @($RawItem)

                        # Construct the Graylog HTTP GELF URL.
                        $url = $Options.BaseUrl

                        # Set up headers for JSON content type required by Graylog.
                        $headers = @{
                            'Content-Type' = 'application/json'
                        }

                        # Format each log entry for Graylog.
                        $messages = $Item | ForEach-Object {
                            @{
                                version       = '1.1'  # GELF version
                                host          = $PodeContext.Server.ComputerName  # Add hostname
                                short_message = ($_ | Protect-PodeLogItem)  # Sanitize log message content
                                timestamp     = [math]::Round(($RawItem.Date).ToUniversalTime().Subtract(([datetime]::UnixEpoch)).TotalSeconds)  # Convert timestamp to seconds since epoch
                                level         = $RawItem.Level.ToUpperInvariant()  # Set log severity level
                                _tag          = $RawItem.Tag  # Include tag if provided
                            }
                        }

                        # Convert the list of messages to JSON format for Graylog ingestion.
                        $body = $messages | ConvertTo-Json -Compress

                        # Send the log data to Graylog via HTTP POST.
                        try {
                            Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $body -SkipCertificateCheck:$Options.SkipCertificateCheck
                        }
                        catch {
                            # Handle any failures based on the configured FailureAction (e.g., Ignore, Report, Halt).
                            Invoke-PodeHandleFailure -Message "Failed to send log to Graylog: $_" -FailureAction $Options.FailureAction
                        }
                    }
                }
            }
        }
    }

    # Return the logging method configuration as a hashtable.
    return @{
        Type      = 'Graylog'  # Specifies the type of logging platform.
        Id        = $methodId  # Unique identifier for this logging method.
        Batch     = New-PodeLogBatchInfo  # Contains batch information for Pode logging.
        Logger    = @()  # Initialize an empty logger array if needed for Pode processing.
        Arguments = @{
            BaseUrl              = $BaseUrl
            FailureAction        = $FailureAction
            SkipCertificateCheck = $SkipCertificateCheck.IsPresent
            AsUTC                = $AsUTC.IsPresent
            DefaultTag           = $DefaultTag
            DataFormat           = $DataFormat
        }
    }
}

<#
.SYNOPSIS
Configures logging to Splunk.

.DESCRIPTION
The `New-PodeSplunkLoggingMethod` function sets up logging for Splunk, sending log entries to a specified Splunk HTTP Event Collector (HEC) endpoint using a specified token.

.PARAMETER BaseUrl
The base URL for the Splunk HTTP Event Collector, typically `https://<SPLUNK_SERVER_IP>:8088/services/collector`.

.PARAMETER Token
The Splunk HEC token for authentication.

.PARAMETER FailureAction
Specifies the action to take if the logging request fails. Valid values are `Ignore`, `Report`, and `Halt`. The default is `Ignore`.

.PARAMETER SkipCertificateCheck
If present, skips SSL certificate validation when sending logs.

.PARAMETER AsUTC
If present, converts timestamps to UTC.

.PARAMETER DefaultTag
Sets a default tag for log entries. Defaults to `-`.

.PARAMETER DataFormat
The custom date format for log entries. Mutually exclusive with ISO8601.

.PARAMETER ISO8601
If set, uses the ISO 8601 date format for log entries. Mutually exclusive with DataFormat.

.EXAMPLE
PS> New-PodeSplunkLoggingMethod -BaseUrl 'https://splunk-server:8088/services/collector' -Token 'my-splunk-token'

Configures Splunk logging with the provided URL and token.

.NOTES
This function sends logs to Splunk through its HTTP Event Collector (HEC).
#>
function New-PodeSplunkLoggingMethod {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $BaseUrl,

        [Parameter(Mandatory = $true)]
        [string]
        $Token,

        [Parameter()]
        [ValidateSet('Ignore', 'Report', 'Halt')]
        [string]
        $FailureAction = 'Ignore',

        [Parameter()]
        [switch]
        $SkipCertificateCheck,

        [Parameter()]
        [switch]
        $AsUTC,

        [Parameter()]
        [string]
        $DefaultTag = '-',

        [Parameter(ParameterSetName = 'DataFormat')]
        [ValidateScript({ Test-PodeDateFormat $_ })]
        [string]
        $DataFormat,

        [Parameter(ParameterSetName = 'ISO8601')]
        [switch]
        $ISO8601
    )

    # Determine the date format based on parameter set
    switch ($PSCmdlet.ParameterSetName.ToLowerInvariant()) {
        'iso8601' {
            $DataFormat = 'yyyy-MM-ddTHH:mm:ssK' # ISO8601 format
        }
        default {
            if ([string]::IsNullOrEmpty($DataFormat)) {
                $DataFormat = 'dd/MMM/yyyy:HH:mm:ss zzz' # Default format
            }
        }
    }

    # Generate a unique ID for this logging method instance.
    $methodId = New-PodeGuid

    # Add the logging method configuration to the PodeContext for tracking and execution.
    $PodeContext.Server.Logging.Method[$methodId] = @{
        # Queue to hold log entries until they can be processed.
        # Using a concurrent queue ensures thread-safe interactions in the runspace.
        Queue       = [System.Collections.Concurrent.ConcurrentQueue[hashtable]]::new()

        # ScriptBlock responsible for processing log entries in a separate runspace.
        # This block continuously dequeues and sends log entries to Splunk.
        ScriptBlock = {
            param($MethodId)  # Pass the unique method ID to identify this logging configuration.

            # Temporary hashtable to hold a dequeued log entry.
            $log = @{ }

            # Loop continuously until a cancellation is requested (graceful shutdown).
            while (!$PodeContext.Tokens.Cancellation.IsCancellationRequested) {
                # Brief pause to reduce CPU usage in the loop.
                Start-Sleep -Milliseconds 100

                # Attempt to dequeue a log entry from the queue.
                if ($PodeContext.Server.Logging.Method[$MethodId].Queue.TryDequeue([ref]$log)) {
                    # Only process if a valid log entry was dequeued.
                    if ($null -ne $log) {
                        # Retrieve log data and configuration options.
                        $Item = $log.Item
                        $Options = $log.Options
                        $RawItem = $log.RawItem

                        # Ensure both $Item and $RawItem are treated as arrays to handle multiple log entries.
                        $Item = @($Item)
                        $RawItem = @($RawItem)

                        # Construct the Splunk HEC URL.
                        $url = $Options.BaseUrl

                        # Set up headers for Splunk HEC authentication and content type.
                        $headers = @{
                            'Authorization' = "Splunk $($Options.Token)"  # HEC token for Splunk
                            'Content-Type'  = 'application/json'
                        }

                        # Format each log entry for Splunk.
                        $events = $Item | ForEach-Object {
                            @{
                                event  = ($_ | Protect-PodeLogItem)  # Sanitize log message content
                                host   = $PodeContext.Server.ComputerName  # Add hostname
                                source = $RawItem.Tag  # Use tag as the source if provided
                                time   = [math]::Round(($RawItem.Date).ToUniversalTime().Subtract(([datetime]::UnixEpoch)).TotalSeconds)  # Convert timestamp to seconds since epoch
                                fields = @{
                                    severity = $RawItem.Level.ToUpperInvariant()  # Set log severity level
                                }
                            }
                        }

                        # Convert the list of events to JSON format for Splunk ingestion.
                        $body = $events | ConvertTo-Json -Compress

                        # Send the log data to Splunk via HTTP POST.
                        try {
                            Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $body -SkipCertificateCheck:$Options.SkipCertificateCheck
                        }
                        catch {
                            # Handle any failures based on the configured FailureAction (e.g., Ignore, Report, Halt).
                            Invoke-PodeHandleFailure -Message "Failed to send log to Splunk: $_" -FailureAction $Options.FailureAction
                        }
                    }
                }
            }
        }
    }

    # Return the logging method configuration as a hashtable.
    return @{
        Type      = 'Splunk'  # Specifies the type of logging platform.
        Id        = $methodId  # Unique identifier for this logging method.
        Batch     = New-PodeLogBatchInfo  # Contains batch information for Pode logging.
        Logger    = @()  # Initialize an empty logger array if needed for Pode processing.
        Arguments = @{
            BaseUrl              = $BaseUrl
            Token                = $Token
            FailureAction        = $FailureAction
            SkipCertificateCheck = $SkipCertificateCheck.IsPresent
            AsUTC                = $AsUTC.IsPresent
            DefaultTag           = $DefaultTag
            DataFormat           = $DataFormat
        }
    }
}

<#
.SYNOPSIS
Configures logging to VMware Log Insight.

.DESCRIPTION
The `New-PodeLogInsightLoggingMethod` function sets up logging for VMware Log Insight, allowing log entries to be sent to the Log Insight API endpoint.

.PARAMETER BaseUrl
The base URL for the VMware Log Insight ingestion API, typically `https://<LOGINSIGHT_SERVER_IP>/api/v1/messages/ingest/<Id>`.

.PARAMETER Id
The ingestion ID for VMware Log Insight, used to target a specific log stream.

.PARAMETER FailureAction
Specifies the action to take if the logging request fails. Valid values are `Ignore`, `Report`, and `Halt`. The default is `Ignore`.

.PARAMETER SkipCertificateCheck
If present, skips SSL certificate validation when sending logs.

.PARAMETER AsUTC
If present, converts timestamps to UTC.

.PARAMETER DefaultTag
Sets a default tag for log entries. Defaults to `-`.

.PARAMETER DataFormat
The custom date format for log entries. Mutually exclusive with ISO8601.

.PARAMETER ISO8601
If set, uses the ISO 8601 date format for log entries. Mutually exclusive with DataFormat.

.EXAMPLE
PS> New-PodeLogInsightLoggingMethod -BaseUrl 'https://loginsight-server/api/v1/messages/ingest/' -Id 'my-log-id'

Configures Log Insight logging using the provided URL and ID.

.NOTES
This function sends logs to VMware Log Insight through its ingestion API.
#>
function New-PodeLogInsightLoggingMethod {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $BaseUrl,

        [Parameter(Mandatory = $true)]
        [string]
        $Id,

        [Parameter()]
        [ValidateSet('Ignore', 'Report', 'Halt')]
        [string]
        $FailureAction = 'Ignore',

        [Parameter()]
        [switch]
        $SkipCertificateCheck,

        [Parameter()]
        [switch]
        $AsUTC,

        [Parameter()]
        [string]
        $DefaultTag = '-',

        [Parameter(ParameterSetName = 'DataFormat')]
        [ValidateScript({ Test-PodeDateFormat $_ })]
        [string]
        $DataFormat,

        [Parameter(ParameterSetName = 'ISO8601')]
        [switch]
        $ISO8601
    )

    # Determine the date format based on parameter set
    switch ($PSCmdlet.ParameterSetName.ToLowerInvariant()) {
        'iso8601' {
            $DataFormat = 'yyyy-MM-ddTHH:mm:ssK' # ISO8601 format
        }
        default {
            if ([string]::IsNullOrEmpty($DataFormat)) {
                $DataFormat = 'dd/MMM/yyyy:HH:mm:ss zzz' # Default format
            }
        }
    }

    # Generate a unique method ID for this logging method instance
    $methodId = New-PodeGuid

    # Add the logging method configuration to the PodeContext for use in logging
    $PodeContext.Server.Logging.Method[$methodId] = @{
        # Queue to hold log entries until they can be processed.
        # Using a concurrent queue ensures thread-safe interactions in the runspace.
        Queue       = [System.Collections.Concurrent.ConcurrentQueue[hashtable]]::new()

        # ScriptBlock responsible for processing log entries in a separate runspace.
        # This block continuously dequeues and sends log entries to Splunk.
        ScriptBlock = {
            param($MethodId)

            # Temporary hashtable to store dequeued log information
            $log = @{ }

            # Run while cancellation has not been requested
            while (!$PodeContext.Tokens.Cancellation.IsCancellationRequested) {
                Start-Sleep -Milliseconds 100  # Sleep briefly to avoid constant polling

                # Try to dequeue a log entry from the method's queue
                if ($PodeContext.Server.Logging.Method[$MethodId].Queue.TryDequeue([ref]$log)) {
                    if ($null -ne $log) {
                        # Extract log data and configuration options
                        $Item = $log.Item
                        $Options = $log.Options
                        $RawItem = $log.RawItem

                        # Ensure both $Item and $RawItem are arrays to handle multiple log entries
                        $Item = @($Item)
                        $RawItem = @($RawItem)

                        # Build the target URL for the Log Insight API endpoint
                        $url = "$($Options.BaseUrl)/$($Options.Id)"
                        $headers = @{
                            'Content-Type' = 'application/json'
                        }

                        # Process each log entry and format as required by Log Insight
                        $messages = $Item | ForEach-Object {
                            @{
                                text      = ($_ | Protect-PodeLogItem)  # Sanitize the log message
                                timestamp = [math]::Round(($RawItem.Date).ToUniversalTime().Subtract(([datetime]::UnixEpoch)).TotalMilliseconds)  # Convert date to milliseconds since epoch
                                fields    = @{
                                    severity = $RawItem.Level.ToUpperInvariant()  # Add severity level
                                    tag      = $RawItem.Tag  # Add a tag if provided
                                }
                            }
                        }

                        # Prepare the payload with the formatted messages
                        $payload = @{
                            messages = $messages
                        }

                        # Convert the payload to JSON format
                        $body = $payload | ConvertTo-Json -Compress

                        try {
                            # Send the log data to VMware Log Insight via HTTP POST
                            Invoke-RestMethod -Uri $url -Method Post -Body $body -Headers $headers -SkipCertificateCheck:$Options.SkipCertificateCheck
                        }
                        catch {
                            # Handle any failures based on the configured FailureAction
                            Invoke-PodeHandleFailure -Message "Failed to send log to Log Insight: $_" -FailureAction $Options.FailureAction
                        }
                    }
                }
            }
        }
    }

    # Return the logging method configuration to the caller
    return @{
        Type      = 'LogInsight'
        Id        = $methodId
        Batch     = New-PodeLogBatchInfo  # Contains batch information if needed
        Logger    = @()
        Arguments = @{
            BaseUrl              = $BaseUrl
            Id                   = $Id
            FailureAction        = $FailureAction
            SkipCertificateCheck = $SkipCertificateCheck.IsPresent
            AsUTC                = $AsUTC.IsPresent
            DefaultTag           = $DefaultTag
            DataFormat           = $DataFormat
        }
    }
}
