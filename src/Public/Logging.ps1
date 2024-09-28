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

.PARAMETER Format
    The format of the log entries for the File logging method. Options are: RFC3164, RFC5424, Simple, Default (Default: Default).

.PARAMETER Separator
    The separator to use in log entries for the File logging method (Default: ' ').

.PARAMETER MaxLength
    The maximum length of log entries for the File logging method (Default: -1).

.PARAMETER MaxDays
    The maximum number of days to keep logs, before Pode automatically removes them.

.PARAMETER MaxSize
    The maximum size of a log file, before Pode starts writing to a new log file.

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

.PARAMETER Custom
    If supplied, will allow you to create a Custom Logging output method.

.PARAMETER UseRunspace
    If supplied, the Custom Logging output method will use its own separated runspace

.PARAMETER CustomOptions
    An hastable of properties to supply to the Custom Logging output method's ScriptBlock when used inside a runspace.
    The content is available using the variable `$options`

.PARAMETER ScriptBlock
    The ScriptBlock that defines how to output a log item.

.PARAMETER ArgumentList
    An array of arguments to supply to the Custom Logging output method's ScriptBlock.

.PARAMETER Syslog
    If supplied, will use the Syslog logging output method.

.PARAMETER Server
    The Syslog server to send logs to.

.PARAMETER Port
    The port on the Syslog server (Default: 514).

.PARAMETER Transport
    The transport protocol to use (Default: UDP).

.PARAMETER TlsProtocol
    The TLS protocol version to use (Default: TLS 1.3).

.PARAMETER SyslogProtocol
    The Syslog protocol to use (Default: RFC5424).

.PARAMETER Encoding
    The encoding to use for the Syslog messages (Default: UTF8).

.PARAMETER SkipCertificateCheck
    Skip certificate validation for TLS connections.

.PARAMETER Restful
    If supplied, will use the Restful logging output method.

.PARAMETER BaseUrl
    The base URL for the Restful logging endpoint.

.PARAMETER Platform
    The platform for Restful logging (Splunk, LogInsight).

.PARAMETER Token
    The token for authentication with Restful servers that require it.

.PARAMETER Id
    The LogInsight collector ID.

.PARAMETER FailureAction
    Defines the behavior in case of failure. Options are: Ignore, Report, Halt (Default: Ignore).

.PARAMETER DataFormat
    The date format to use for the log entries (Default: 'dd/MMM/yyyy:HH:mm:ss zzz').

.PARAMETER ISO8601
    If set, the date format will be ISO 8601 compliant (equivalent to -DataFormat 'yyyy-MM-ddTHH:mm:ssK')
    This parameter is mutually exclusive with DataFormat.

.PARAMETER AsUTC
    If set, the time will be logged in UTC instead of local time.

.EXAMPLE
    $term_logging = New-PodeLoggingMethod -Terminal

.EXAMPLE
    $file_logging = New-PodeLoggingMethod -File -Path ./logs -Name 'requests'

.EXAMPLE
    $custom_logging = New-PodeLoggingMethod -Custom -ScriptBlock { /* logic */ }

.EXAMPLE
    $syslog_logging = New-PodeLoggingMethod -Syslog -Server '192.168.1.1' -Port 514 -Transport 'UDP'

.EXAMPLE
    $restful_logging = New-PodeLoggingMethod -Restful -BaseUrl 'https://logserver.example.com' -Platform 'Splunk' -Token 'your-token'
#>
function New-PodeLoggingMethod {
    [CmdletBinding(DefaultParameterSetName = 'Terminal')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUSeDeclaredVarsMoreThanAssignments', '')]
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

        [Parameter( ParameterSetName = 'File')]
        [ValidateSet('RFC3164' , 'RFC5424', 'Simple', 'Default' )]
        [string]
        $Format = 'Default',

        [Parameter( ParameterSetName = 'File')]
        [string]
        $Separator = ' ',

        [Parameter(  ParameterSetName = 'File')]
        [int]
        $MaxLength = -1,

        [Parameter(ParameterSetName = 'EventViewer')]
        [switch]
        $EventViewer,

        [Parameter(ParameterSetName = 'EventViewer')]
        [string]
        $EventLogName = 'Application',

        [Parameter(ParameterSetName = 'EventViewer')]
        [Parameter(ParameterSetName = 'Syslog')]
        [Parameter(ParameterSetName = 'File')]
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

        [Parameter(Mandatory = $true, ParameterSetName = 'Custom')]
        [Parameter(Mandatory = $true, ParameterSetName = 'CustomRunspace')]
        [switch]
        $Custom,

        [Parameter(Mandatory = $true, ParameterSetName = 'CustomRunspace')]
        [switch]
        $UseRunspace,

        [Parameter(ParameterSetName = 'CustomRunspace')]
        [hashtable]
        $CustomOptions = @{},

        [Parameter(Mandatory = $true, ParameterSetName = 'Custom')]
        [Parameter(Mandatory = $true, ParameterSetName = 'CustomRunspace')]
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
        $ArgumentList,

        [Parameter(Mandatory = $true, ParameterSetName = 'Syslog')]
        [switch]
        $Syslog,

        [Parameter(Mandatory = $true, ParameterSetName = 'Syslog')]
        [string]
        $Server,

        [Parameter( ParameterSetName = 'Syslog')]
        [Int16]
        $Port = 514,

        [Parameter( ParameterSetName = 'Syslog')]
        [ValidateSet('UDP', 'TCP', 'TLS' )]
        [string]
        $Transport = 'UDP',

        [Parameter( ParameterSetName = 'Syslog')]
        [System.Security.Authentication.SslProtocols]
        $TlsProtocol = [System.Security.Authentication.SslProtocols]::Tls13,

        [Parameter( ParameterSetName = 'Syslog')]
        [ValidateSet('RFC3164' , 'RFC5424')]
        [string]
        $SyslogProtocol = 'RFC5424',

        [Parameter( ParameterSetName = 'Syslog')]
        [Parameter( ParameterSetName = 'File')]
        [ValidateSet('ASCII', 'BigEndianUnicode', 'Default', 'Unicode', 'UTF32', 'UTF7', 'UTF8')]
        [string]
        $Encoding = 'UTF8',

        [Parameter( ParameterSetName = 'Syslog')]
        [Parameter(Mandatory = $true, ParameterSetName = 'Restful')]
        [switch]
        $SkipCertificateCheck,

        [Parameter(Mandatory = $true, ParameterSetName = 'Restful')]
        [switch]
        $Restful,

        [Parameter(Mandatory = $true, ParameterSetName = 'Restful')]
        [ValidatePattern('^(https?://|/).+')]
        [string]
        $BaseUrl,

        [Parameter( ParameterSetName = 'Restful')]
        [ValidateSet( 'Splunk', 'LogInsight')]
        $Platform = 'Splunk',

        [Parameter( ParameterSetName = 'Restful')]
        [string]
        $Token,

        [Parameter( ParameterSetName = 'Restful')]
        [string]
        $Id,

        [Parameter(ParameterSetName = 'EventViewer')]
        [Parameter(ParameterSetName = 'File')]
        [Parameter(ParameterSetName = 'CustomRunspace')]
        [Parameter( ParameterSetName = 'Restful')]
        [Parameter( ParameterSetName = 'Syslog')]
        [string]
        [ValidateSet('Ignore', 'Report', 'Halt' )]
        $FailureAction = 'Ignore',

        [Parameter()]
        [ValidateScript({
                # Define a sample date to test the format
                $sampleDate = [DateTime]::Now
                try {
                    # Try to format the sample date using the provided format
                    $formattedDate = $sampleDate.ToString($_)

                    # Try to parse the formatted date back to a DateTime object using the same format
                    [DateTime]::ParseExact($formattedDate, $_, $null)

                    # If no exceptions are thrown, the format is valid
                    $true
                }
                catch {
                    # If an exception is thrown, the format is invalid
                    $false
                }
            })]
        [string]
        $DataFormat,

        [Parameter()]
        [switch]
        $ISO8601,

        [Parameter()]
        [switch]
        $AsUTC
    )

    if ((! [string]::IsNullOrEmpty($DataFormat)) -and $ISO8601.IsPresent) {
        throw ("Parameters '{0}' and '{1}' are mutually exclusive." -f 'DataFormat', 'ISO8601')
    }
    if ($ISO8601.IsPresent) {
        $DataFormat = 'yyyy-MM-ddTHH:mm:ssK'
    }
    else {
        $DataFormat = 'dd/MMM/yyyy:HH:mm:ss zzz' # Default format
    }

    # batch details
    $batchInfo = @{
        Id         = New-PodeGuid
        Size       = $Batch
        Timeout    = $BatchTimeout
        LastUpdate = $null
        Items      = @()
        RawItems   = @()
    }

    # return info on appropriate logging type
    switch ($PSCmdlet.ParameterSetName.ToLowerInvariant()) {
        'terminal' {
            $methodId = New-PodeGuid
            $PodeContext.Server.Logging.Method[$methodId] = @{
                ScriptBlock = (Get-PodeLoggingTerminalMethod)
                Queue       = [System.Collections.Concurrent.ConcurrentQueue[hashtable]]::new()
            }
            return @{
                Id        = $methodId
                Batch     = $batchInfo
                Logger    = @()
                Arguments = @{
                    DataFormat = $DataFormat
                    AsUTC      = $AsUTC
                }
            }
        }

        'file' {
            $Path = (Protect-PodeValue -Value $Path -Default './logs')
            $Path = (Get-PodeRelativePath -Path $Path -JoinRoot -Resolve)
            $null = New-Item -Path $Path -ItemType Directory -Force
            $methodId = New-PodeGuid
            $PodeContext.Server.Logging.Method[$methodId] = @{
                ScriptBlock = (Get-PodeLoggingFileMethod)
                Queue       = [System.Collections.Concurrent.ConcurrentQueue[hashtable]]::new()
            }
            return @{
                Id        = $methodId
                Batch     = $batchInfo
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
                    AsUTC         = $AsUTC
                    Encoding      = $Encoding
                    Format        = $Format
                    MaxLength     = $MaxLength
                    Source        = $Source
                    Separator     = $Separator
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

            $methodId = New-PodeGuid
            $PodeContext.Server.Logging.Method[$methodId] = @{
                ScriptBlock = (Get-PodeLoggingEventViewerMethod)
                Queue       = [System.Collections.Concurrent.ConcurrentQueue[hashtable]]::new()
            }
            return @{
                Id        = $methodId
                Batch     = $batchInfo
                Logger    = @()
                Arguments = @{
                    LogName       = $EventLogName
                    Source        = $Source
                    ID            = $EventID
                    FailureAction = $FailureAction
                    DataFormat    = $DataFormat
                    AsUTC         = $AsUTC
                }
            }
        }

        'syslog' {
            # Get the encoding object based on the selected encoding name
            $selectedEncoding = [System.Text.Encoding]::$Encoding

            if ($null -eq $selectedEncoding) {
                throw ($PodeLocale.invalidEncodingExceptionMessage -f $Encoding)
            }

            $methodId = New-PodeGuid
            $PodeContext.Server.Logging.Method[$methodId] = @{
                ScriptBlock = (Get-PodeLoggingSysLogMethod)
                Queue       = [System.Collections.Concurrent.ConcurrentQueue[hashtable]]::new()
            }
            return @{
                Id        = $methodId
                Batch     = $batchInfo
                Logger    = @()
                Arguments = @{
                    Server               = $Server
                    Port                 = $Port
                    Transport            = $Transport
                    Hostname             = $Hostname
                    Source               = $Source
                    TslProtocols         = $TlsProtocol
                    SkipCertificateCheck = $SkipCertificateCheck
                    SyslogProtocol       = $SyslogProtocol
                    Encoding             = $selectedEncoding
                    FailureAction        = $FailureAction
                    DataFormat           = $DataFormat
                    AsUTC                = $AsUTC
                }
            }
        }

        'restful' {
            $methodId = New-PodeGuid
            $PodeContext.Server.Logging.Method[$methodId] = @{
                ScriptBlock = (Get-PodeLoggingRestfulMethod)
                Queue       = [System.Collections.Concurrent.ConcurrentQueue[hashtable]]::new()
            }
            return @{
                Id        = $methodId
                Batch     = $batchInfo
                Logger    = @()
                Arguments = @{
                    BaseUrl              = $BaseUrl
                    Platform             = $Platform
                    Hostname             = $Hostname
                    Source               = $Source
                    SkipCertificateCheck = $SkipCertificateCheck
                    Token                = $Token
                    Id                   = $Id
                    FailureAction        = $FailureAction
                    DataFormat           = $DataFormat
                    AsUTC                = $AsUTC
                }
            }
        }

        { ($_ -eq 'CustomRunspace') -or ($_ -eq 'custom') } {
            $methodId = New-PodeGuid
            if ($UseRunspace.IsPresent) {
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

                $PodeContext.Server.Logging.Method[$methodId] = @{
                    ScriptBlock = [ScriptBlock]::Create( $enanchedScriptBlock.ToString().Replace('<# ScriptBlock #>', $ScriptBlock.ToString()))
                    Queue       = [System.Collections.Concurrent.ConcurrentQueue[hashtable]]::new()
                }
                return @{
                    Id        = $methodId
                    Batch     = $batchInfo
                    Logger    = @()
                    Arguments = @{
                        FailureAction = $FailureAction
                        DataFormat    = $DataFormat
                        AsUTC         = $AsUTC
                    } + $CustomOptions
                }
            }
            else {
                $ScriptBlock, $usingVars = Convert-PodeScopedVariables -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState

                return @{
                    Id             = $methodId
                    ScriptBlock    = $ScriptBlock
                    UsingVariables = $usingVars
                    Batch          = $batchInfo
                    Logger         = @()
                    Arguments      = $ArgumentList
                    FailureAction  = $FailureAction
                    DataFormat     = $DataFormat
                    AsUTC          = $AsUTC
                    NoRunspace     = $true
                }
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

        $name = Get-PodeRequestLoggingName

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
                Raw        = $Raw
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
        [hashtable[]]
        $Method,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('Error', 'Warning', 'Informational', 'Verbose', 'Debug', '*')]
        [string[]]
        $Levels = @('Error'),

        [switch]
        $Raw
    )

    begin {
        $pipelineMethods = @()

        $name = Get-PodeErrorLoggingName
        # error if it's already enabled
        if ($PodeContext.Server.Logging.Type.Contains($Name)) {
            # Error Logging has already been enabled
            throw ($PodeLocale.loggingAlreadyEnabledExceptionMessage -f 'Error')
        }
        # all errors?
        if ($Levels -contains '*') {
            $Levels = @('Error', 'Warning', 'Informational', 'Verbose', 'Debug')
        }
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

        # add the error logger
        $PodeContext.Server.Logging.Type[$name] = @{
            Method      = $Method
            ScriptBlock = (Get-PodeLoggingInbuiltType -Type Errors)
            Arguments   = @{
                Raw        = $Raw
                Levels     = $Levels
                DataFormat = $Method.Arguments.DataFormat
            }
            Standard    = $true
        }

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
    $method | Enable-PodeGeneralLogging -Name "mysyslog"
#>
function Enable-PodeGeneralLogging {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [hashtable[]]
        $Method,

        [string[]]
        $Levels = @('Error', 'Emergency', 'Alert', 'Critical', 'Warning', 'Notice', 'Informational', 'Info', 'Verbose', 'Debug'),

        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [switch]
        $Raw
    )
    begin {
        $pipelineMethods = @()
        # error if it's already enabled
        if ($PodeContext.Server.Logging.Type.Contains($Name)) {
            throw ($PodeLocale.loggingAlreadyEnabledExceptionMessage -f $Name)
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
                Raw        = $Raw
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
    Disables a generic logging method in Pode.

.DESCRIPTION
    This function disables a generic logging method in Pode.

.PARAMETER Name
    The name of the logging method to be disable.

.EXAMPLE
    Disable-PodeGeneralLogging -Name 'TestLog'
#>
function Disable-PodeGeneralLogging {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name)

    Remove-PodeLogger -Name $Name
}


<#
.SYNOPSIS
    Enables the trace logging in Pode.

.DESCRIPTION
    This function enables the trace logging in Pode, allowing logs to be written based on the defined method and log levels. It ensures the method is not already enabled and validates the provided script block.

.PARAMETER Method
    The hashtable defining the logging method, including the ScriptBlock for log output.

.PARAMETER Raw
    If set, the raw log data will be included in the logging output.

.EXAMPLE
    $method = New-PodeLoggingMethod -syslog -Server 127.0.0.1 -Transport UDP
    $method | Enable-PodeTraceLogging
#>
function Enable-PodeTraceLogging {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [hashtable[]]
        $Method,

        [switch]
        $Raw
    )
    begin {
        $pipelineMethods = @()
        $name = Get-PodeMainLoggingName
        # error if it's already enabled
        if ($PodeContext.Server.Logging.Type.Contains($name)) {
            throw ($PodeLocale.loggingAlreadyEnabledExceptionMessage -f $name)
        }
    }

    process {
        # ensure the Method contains a scriptblock
        if ((! $PodeContext.Server.Logging.Method.ContainsKey($_.Id)) -and (! $_.ContainsKey('Scriptblock'))) {
            # The supplied output Method for the '{0}' Logging method requires a valid ScriptBlock.
            throw ($PodeLocale.loggingMethodRequiresValidScriptBlockExceptionMessage -f 'Main')
        }
        $pipelineMethods += $_
    }

    end {

        if ($pipelineMethods.Count -gt 1) {
            $Method = $pipelineMethods
        }

        # add the error logger
        $PodeContext.Server.Logging.Type[$name] = @{
            Method      = $Method
            ScriptBlock = (Get-PodeLoggingInbuiltType -Type Main)
            Arguments   = @{
                Raw        = $Raw
                DataFormat = $Method.Arguments.DataFormat
            }
            Standard    = $true
        }
        $Method.ForEach({ $_.Logger += $name })
    }
}

<#
.SYNOPSIS
Disables the trace logging method in Pode.

.DESCRIPTION
This function disables the trace logging method in Pode.

.EXAMPLE
Disable-PodeTraceLogging
#>
function Disable-PodeTraceLogging {
    [CmdletBinding()]
    param()

    Remove-PodeLogger -Name (Get-PodeMainLoggingName)
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

        # Record the operation on the trace log
        Write-PodeTraceLog -Operation $MyInvocation.MyCommand.Name -Parameters $PSBoundParameters

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
        # Record the operation on the trace log
        Write-PodeTraceLog -Operation $MyInvocation.MyCommand.Name -Parameters $PSBoundParameters

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
function Clear-PodeLoggers {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    [CmdletBinding()]
    param()

    # Record the operation on the trace log
    Write-PodeTraceLog -Operation $MyInvocation.MyCommand.Name -Parameters $PSBoundParameters

    $PodeContext.Server.Logging.Type.Clear()
}

# Create the alias for back compatibility
if (!(Test-Path Alias:Clear-PodeLoggers)) {
    New-Alias Clear-PodeLoggers -Value  Clear-PodeLogger
}

<#
.SYNOPSIS
    Writes an Exception or ErrorRecord using the built-in error logging.

.DESCRIPTION
    This function logs an Exception or ErrorRecord using Pode's built-in error logging mechanism. It allows specifying the error level and optionally checks for inner exceptions.

.PARAMETER Exception
    An Exception to log.

.PARAMETER ErrorRecord
    An ErrorRecord to log.

.PARAMETER ErrorMessage
    A custom error message to log.

.PARAMETER Category
    The error category for the custom error message (Default: NotSpecified).

.PARAMETER Level
    The level of the error being logged. Options are: Error, Warning, Informational, Verbose, Debug (Default: Error).

.PARAMETER CheckInnerException
    If specified, any inner exceptions of the provided exception are also logged.

.PARAMETER ThreadId
    The ID of the thread where the error occurred.

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

        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = 'ErrorRecord')]
        [System.Management.Automation.ErrorRecord]
        $ErrorRecord,

        [Parameter(Mandatory = $true, ParameterSetName = 'ErrorMessage')]
        [string]
        $ErrorMessage,

        [Parameter( ParameterSetName = 'ErrorMessage')]
        [System.Management.Automation.ErrorCategory]
        $Category = [System.Management.Automation.ErrorCategory]::NotSpecified,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('Error', 'Warning', 'Informational', 'Verbose', 'Debug')]
        [string]
        $Level = 'Error',

        [Parameter(ParameterSetName = 'Exception')]
        [switch]
        $CheckInnerException,

        [Parameter()]
        [int]
        $ThreadId
    )

    Process {
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

            'ErrorRecord' {
                $item = @{
                    Category   = $ErrorRecord.CategoryInfo.ToString()
                    Message    = $ErrorRecord.Exception.Message
                    StackTrace = $ErrorRecord.ScriptStackTrace
                }
            }
            'ErrorMessage' {
                $item = @{
                    Category = $Category.ToString()
                    Message  = $ErrorMessage
                }
            }
        }

        # add general info
        $item['Server'] = $PodeContext.Server.ComputerName
        $item['Level'] = $Level
        if ($PodeContext.Server.Logging.Type[$Name].Method.Arguments.AsUTC) {
            $Item.Date = [datetime]::UtcNow
        }
        else {
            $Item.Date = [datetime]::Now
        }

        if ($ThreadId) {
            $Item['ThreadId'] = $ThreadId
        }
        else {
            $item['ThreadId'] = [System.Threading.Thread]::CurrentThread.ManagedThreadId #[int]$ThreadId
        }

        $logItem = @{
            Name = $name
            Item = $item
        }

        # add the item to be processed
        $null = [Pode.PodeLogger]::Enqueue( $logItem)

        # for exceptions, check the inner exception
        if ($CheckInnerException -and ($null -ne $Exception.InnerException) -and ![string]::IsNullOrWhiteSpace($Exception.InnerException.Message)) {
            $Exception.InnerException | Write-PodeErrorLog
        }
    }
}


<#
.SYNOPSIS
    Writes an object to a configured custom or built-in logging method.

.DESCRIPTION
    This function writes an object to a configured logging method in Pode.
    It supports both custom and built-in logging methods, allowing for structured logging with different log levels and messages.

.PARAMETER Name
    The name of the logging method.

.PARAMETER InputObject
    The object to write to the logging method.

.PARAMETER Level
    The log level for the custom logging method (Default: 'Informational').

.PARAMETER Message
    The log message for the custom logging method.

.PARAMETER Tag
    A string that identifies the source application, service, or process generating the log message.
    The tag helps in distinguishing log messages from different sources and makes it easier to filter and analyze logs.
    It is typically a short identifier such as the application name or process ID.

.PARAMETER ThreadId
    The ID of the thread where the log entry is generated.

.EXAMPLE
    $object | Write-PodeLog -Name 'LogName'

.EXAMPLE
    Write-PodeLog -Name 'CustomLog' -Level 'Error' -Message 'An error occurred.'
#>
function Write-PodeLog {
    [CmdletBinding(DefaultParameterSetName = 'inbuilt')]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = 'inbuilt')]
        [object]
        $InputObject,

        [Parameter( ParameterSetName = 'custom')]
        [string]
        $Level = 'Informational',

        [Parameter( Mandatory = $true, ParameterSetName = 'custom')]
        [string]
        $Message,

        [Parameter( ParameterSetName = 'custom')]
        [string]
        $Tag = '-',

        [Parameter()]
        [int]
        $ThreadId

    )
    Process {
        # do nothing if logging is disabled, or logger isn't setup
        if (!(Test-PodeLoggerEnabled -Name $Name)) {
            return
        }

        switch ($PSCmdlet.ParameterSetName.ToLowerInvariant()) {
            'inbuilt' {
                $logItem = @{
                    Name = $Name
                    Item = $InputObject
                }
                break
            }
            'custom' {
                $logItem = @{
                    Name = $Name
                    Item = @{
                        Level   = $Level
                        Message = $Message
                        Tag     = $Tag
                    }
                }
                break
            }
        }
        $log = $PodeContext.Server.Logging.Type[$Name]
        if ($log.Standard) {
            $logItem.Item.Server = $PodeContext.Server.ComputerName

            if ($log.Method.Arguments.AsUTC) {
                $logItem.Item.Date = [datetime]::UtcNow
            }
            else {
                $logItem.Item.Date = [datetime]::Now
            }

            if ($ThreadId) {
                $logItem.Item.ThreadId = $ThreadId
            }
            else {
                $logItem.Item.ThreadId = [System.Threading.Thread]::CurrentThread.ManagedThreadId
            }
        }
        # add the item to be processed
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
    Enable-PodeLogging
    This example enables all logging except terminal logging.

.EXAMPLE
    Enable-PodeLogging -Terminal
    This example enables all logging including terminal logging for the Pode C# listener.
#>
function Enable-PodeLogging {
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
    Disable-PodeLogging
    This example disables all logging including terminal logging.

.EXAMPLE
    Disable-PodeLogging -KeepTerminal
    This example disables all logging except terminal logging.
#>
function Disable-PodeLogging {
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
    [pode.PodeLogger]::Clear()
}