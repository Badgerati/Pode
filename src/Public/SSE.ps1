<#
.SYNOPSIS
Sets the current HTTP request to a Route to be an SSE connection.

.DESCRIPTION
Sets the current HTTP request to a Route to be an SSE connection, by sending the required headers back to the client.
The connection can only be configured if the request's Accept header is "text/event-stream", unless Forced.

.PARAMETER Name
The Name of the SSE connection, which ClientIds will be stored under.

.PARAMETER Scope
The Scope of the SSE connection, either Local or Global (Default: Global).
- If the Scope is Local, then the SSE connection will only be opened for the duration of the request to a Route that configured it.
- If the Scope is Global, then the SSE connection will be cached internally so events can be sent to the connection from Tasks, Timers, and other Routes, etc.

.PARAMETER RetryDuration
An optional RetryDuration, in milliseconds, for the period of time a browser should wait before reattempting a connection if lost (Default: 0).

.PARAMETER ClientId
An optional ClientId to use for the SSE connection, this value will be signed if signing is enabled (Default: GUID).

.PARAMETER AllowAllOrigins
If supplied, then Access-Control-Allow-Origin will be set to * on the response.

.PARAMETER Force
If supplied, the Accept header of the request will be ignored; attempting to configure an SSE connection even if the header isn't "text/event-stream".

.EXAMPLE
Set-PodeSseConnection -Name 'Actions'

.EXAMPLE
Set-PodeSseConnection -Name 'Actions' -Scope Local

.EXAMPLE
Set-PodeSseConnection -Name 'Actions' -AllowAllOrigins

.EXAMPLE
Set-PodeSseConnection -Name 'Actions' -ClientId 'my-client-id'
#>
function Set-PodeSseConnection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter()]
        [ValidateSet('Local', 'Global')]
        [string]
        $Scope = 'Global',

        [Parameter()]
        [int]
        $RetryDuration = 0,

        [Parameter()]
        [string]
        $ClientId,

        [switch]
        $AllowAllOrigins,

        [switch]
        $Force
    )

    # check Accept header - unless forcing
    if (!$Force -and ((Get-PodeHeader -Name 'Accept') -ine 'text/event-stream')) {
        throw 'SSE can only be configured on requests with an Accept header value of text/event-stream'
    }

    # generate clientId
    $ClientId = New-PodeSseClientId -ClientId $ClientId

    # set adn send SSE headers
    $ClientId = $WebEvent.Response.SetSseConnection($Scope, $ClientId, $Name, $RetryDuration, $AllowAllOrigins.IsPresent)

    # create SSE property on WebEvent
    $WebEvent.Sse = @{
        Name        = $Name
        ClientId    = $ClientId
        LastEventId = Get-PodeHeader -Name 'Last-Event-ID'
        IsLocal     = ($Scope -ieq 'local')
    }
}

<#
.SYNOPSIS
Send an Event to one or more SSE connections.

.DESCRIPTION
Send an Event to one or more SSE connections. This can either be:
- Every client for an SSE connection Name
- Specific ClientIds for an SSE connection Name
- The current SSE connection being referenced within $WebEvent.Sse

.PARAMETER Name
An SSE connection Name.

.PARAMETER ClientId
An optional array of 1 or more SSE connection ClientIds to send Events to, for the specified SSE connection Name.

.PARAMETER Id
An optional ID for the Event being sent.

.PARAMETER EventType
An optional EventType for the Event being sent.

.PARAMETER Data
The Data for the Event being sent, either as a String or a Hashtable/PSObject. If the latter, it will be converted into JSON.

.PARAMETER Depth
The Depth to generate the JSON document - the larger this value the worse performance gets.

.PARAMETER FromEvent
If supplied, the SSE connection Name and ClientId will atttempt to be retrived from $WebEvent.Sse.
These details will be set if Set-PodeSseConnection has just been called. Or if X-PODE-SSE-CLIENT-ID and X-PODE-SSE-CLIENT-NAME are set on an HTTP request.

.EXAMPLE
Send-PodeSseEvent -FromEvent -Data 'This is an event'

.EXAMPLE
Send-PodeSseEvent -FromEvent -Data @{ Message = 'A message' }

.EXAMPLE
Send-PodeSseEvent -Name 'Actions' -Data @{ Message = 'A message' }

.EXAMPLE
Send-PodeSseEvent -Name 'Actions' -Data @{ Message = 'A message' } -ID 123 -EventType 'action'
#>
function Send-PodeSseEvent {
    [CmdletBinding(DefaultParameterSetName = 'Name')]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'Name')]
        [string]
        $Name,

        [Parameter(ParameterSetName = 'Name')]
        [string[]]
        $ClientId,

        [Parameter()]
        [string]
        $Id,

        [Parameter()]
        [string]
        $EventType,

        [Parameter(Mandatory = $true)]
        $Data,

        [Parameter()]
        [int]
        $Depth = 10,

        [Parameter(ParameterSetName = 'WebEvent')]
        [switch]
        $FromEvent
    )

    # do nothing if no value
    if (($null -eq $Data) -or ([string]::IsNullOrEmpty($Data))) {
        return
    }

    # jsonify the value
    if ($Data -isnot [string]) {
        if ($Depth -le 0) {
            $Data = (ConvertTo-Json -InputObject $Data -Compress)
        }
        else {
            $Data = (ConvertTo-Json -InputObject $Data -Depth $Depth -Compress)
        }
    }

    # send directly back to current connection
    if ($FromEvent -and $WebEvent.Sse.IsLocal) {
        $WebEvent.Response.SendSseEvent($EventType, $Data, $Id)
        return
    }

    # from event and global?
    if ($FromEvent) {
        $Name = $WebEvent.Sse.Name
        $ClientId = $WebEvent.Sse.ClientId
    }

    # error if no name
    if ([string]::IsNullOrEmpty($Name)) {
        throw 'An SSE connection Name is required, either from -Name or $WebEvent.Sse.Name'
    }

    # send event
    $PodeContext.Server.Http.Listener.SendSseEvent($Name, $ClientId, $EventType, $Data, $Id)





    # mode - are we sending directly back to a client?
    # $direct = $false

    # check WebEvent
    # if ([string]::IsNullOrEmpty($Name) -and ($null -ne $WebEvent.Sse)) {
    #     $Name = $WebEvent.Sse.Name

    #     if (($null -eq $ClientId) -or ($ClientId.Length -eq 0)) {
    #         $ClientId = $WebEvent.Sse.ClientId
    #         $direct = $true
    #     }
    # }

    # error if no name
    # if ([string]::IsNullOrEmpty($Name)) {
    #     throw 'An SSE connection name is required, either from -Name or $WebEvent.Sse.Name'
    # }

    # jsonify the value
    # if ($Data -isnot [string]) {
    #     if ($Depth -le 0) {
    #         $Data = (ConvertTo-Json -InputObject $Data -Compress)
    #     }
    #     else {
    #         $Data = (ConvertTo-Json -InputObject $Data -Depth $Depth -Compress)
    #     }
    # }

    # send message
    # if ($direct) {
    #     $WebEvent.Response.SendSseEvent($EventType, $Data, $Id)
    # }
    # else {
    #     $PodeContext.Server.Http.Listener.SendSseEvent($Name, $ClientId, $EventType, $Data, $Id)
    # }
}

<#
.SYNOPSIS
Close one or more SSE connections.

.DESCRIPTION
Close one or more SSE connections. Either all connections for an SSE connection Name, or specific ClientIds for a Name.

.PARAMETER Name
The Name of the SSE connection which has the ClientIds for the connections to close.

.PARAMETER ClientId
An optional array of 1 or more SSE connection ClientIds, that are for the SSE connection Name.
If not supplied, every SSE connection for the supplied Name will be closed.

.EXAMPLE
Close-PodeSseConnection -Name 'Actions'

.EXAMPLE
Close-PodeSseConnection -Name 'Actions' -ClientId @('my-client-id', 'my-other'id')
#>
function Close-PodeSseConnection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter()]
        [string[]]
        $ClientId
    )

    $PodeContext.Server.Http.Listener.CloseSseConnection($Name, $ClientId)
}

<#
.SYNOPSIS
Test if an SSE connection ClientId is validly signed.

.DESCRIPTION
Test if an SSE connection ClientId is validly signed.

.PARAMETER ClientId
An optional SSE connection ClientId, if not supplied it will be retrieved from $WebEvent.

.EXAMPLE
if (Test-PodeSseClientIdValid) { ... }

.EXAMPLE
if (Test-PodeSseClientIdValid -ClientId 's:my-already-signed-client-id.uvG49LcojTMuJ0l4yzBzr6jCqEV8gGC/0YgsYU1QEuQ=') { ... }
#>
function Test-PodeSseClientIdSigned {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $ClientId
    )

    # get clientId from WebEvent if not passed
    if ([string]::IsNullOrEmpty($ClientId)) {
        $ClientId = Get-PodeSseClientId
    }

    # test if clientId is validly signed
    return Test-PodeValueSigned -Value $ClientId -Secret $PodeContext.Server.Sse.Secret -Strict:($PodeContext.Server.Sse.Strict)
}

<#
.SYNOPSIS
Test if an SSE connection ClientId is valid.

.DESCRIPTION
Test if an SSE connection ClientId, passed or from $WebEvent, is valid. A ClientId is valid if it's not signed and we're not signing ClientIds,
or if we are signing ClientIds and the ClientId is validly signed.

.PARAMETER ClientId
An optional SSE connection ClientId, if not supplied it will be retrieved from $WebEvent.

.EXAMPLE
if (Test-PodeSseClientIdValid) { ... }

.EXAMPLE
if (Test-PodeSseClientIdValid -ClientId 'my-client-id') { ... }
#>
function Test-PodeSseClientIdValid {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $ClientId
    )

    # get clientId from WebEvent if not passed
    if ([string]::IsNullOrEmpty($ClientId)) {
        $ClientId = Get-PodeSseClientId
    }

    # if no clientId, then it's not valid
    if ([string]::IsNullOrEmpty($ClientId)) {
        return $false
    }

    # if we're not signing, then valid if not signed, but invalid if signed
    if (!$PodeContext.Server.Sse.Signed) {
        return !$ClientId.StartsWith('s:')
    }

    # test if clientId is validly signed
    return Test-PodeSseClientIdSigned -ClientId $ClientId
}

<#
.SYNOPSIS
Retrieves an SSE connection ClientId from the current $WebEvent.

.DESCRIPTION
Retrieves an SSE connection ClientId from the current $WebEvent, which is set via the X-PODE-SSE-CLIENT-ID request header.
This ClientId could be used to send events back to an originating SSE connection.

.EXAMPLE
$clientId = Get-PodeSseClientId
#>
function Get-PodeSseClientId {
    [CmdletBinding()]
    param()

    # get clientId from WebEvent
    return $WebEvent.Request.SseClientId
}

<#
.SYNOPSIS
Generate a new SSE connection ClientId.

.DESCRIPTION
Generate a new SSE connection ClientId, which will be signed if signing enabled.

.PARAMETER ClientId
An optional SSE connection ClientId to use, if a custom ClientId is needed and required to be signed.

.EXAMPLE
$clientId = New-PodeSseClientId

.EXAMPLE
$clientId = New-PodeSseClientId -ClientId 'my-client-id'

.EXAMPLE
$clientId = New-PodeSseClientId -ClientId 's:my-already-signed-client-id.uvG49LcojTMuJ0l4yzBzr6jCqEV8gGC/0YgsYU1QEuQ='
#>
function New-PodeSseClientId {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $ClientId
    )

    # if no clientId passed, generate a random guid
    if ([string]::IsNullOrEmpty($ClientId)) {
        $ClientId = New-PodeGuid -Secure
    }

    # if we're signing the clientId, and it's not already signed, then sign it
    if ($PodeContext.Server.Sse.Signed -and !$ClientId.StartsWith('s:')) {
        $ClientId = Invoke-PodeValueSign -Value $ClientId -Secret $PodeContext.Server.Sse.Secret -Strict:($PodeContext.Server.Sse.Strict)
    }

    # return the clientId
    return $ClientId
}

<#
.SYNOPSIS
Enable the signing of SSE connection ClientIds.

.DESCRIPTION
Enable the signing of SSE connection ClientIds.

.PARAMETER Secret
An optional Secret to sign ClientIds (Default: random GUID).

.PARAMETER Strict
If supplied, the Secret will be extended using the client request's UserAgent and RemoteIPAddress.

.EXAMPLE
Enable-PodeSseSigning

.EXAMPLE
Enable-PodeSseSigning -Strict

.EXAMPLE
Enable-PodeSseSigning -Secret 'Sup3rS3cr37!' -Strict

.EXAMPLE
Enable-PodeSseSigning -Secret 'Sup3rS3cr37!'
#>
function Enable-PodeSseSigning {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Secret,

        [switch]
        $Strict
    )

    # flag that we're signing SSE connections
    $PodeContext.Server.Sse.Signed = $true
    $PodeContext.Server.Sse.Secret = $Secret
    $PodeContext.Server.Sse.Strict = $Strict.IsPresent
}

<#
.SYNOPSIS
Disable the signing of SSE connection ClientIds.

.DESCRIPTION
Disable the signing of SSE connection ClientIds.

.EXAMPLE
Disable-PodeSseSigning
#>
function Disable-PodeSseSigning {
    [CmdletBinding()]
    param()

    # flag that we're not signing SSE connections
    $PodeContext.Server.Sse.Signed = $false
    $PodeContext.Server.Sse.Secret = $null
    $PodeContext.Server.Sse.Strict = $false
}