<#
.SYNOPSIS
Converts the current HTTP request to a Route to be an SSE connection.

.DESCRIPTION
Converts the current HTTP request to a Route to be an SSE connection, by sending the required headers back to the client.
The connection can only be configured if the request's Accept header is "text/event-stream", unless Forced.

.PARAMETER Name
The Name of the SSE connection, which ClientIds will be stored under.

.PARAMETER Group
An optional Group for this SSE connection, to enable broadcasting events to all connections for an SSE connection name in a Group.

.PARAMETER Scope
The Scope of the SSE connection, either Default, Local or Global (Default: Default).
- If the Scope is Default, then it will be Global unless the default has been updated via Set-PodeSseDefaultScope.
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
ConvertTo-PodeSseConnection -Name 'Actions'

.EXAMPLE
ConvertTo-PodeSseConnection -Name 'Actions' -Scope Local

.EXAMPLE
ConvertTo-PodeSseConnection -Name 'Actions' -Group 'admins'

.EXAMPLE
ConvertTo-PodeSseConnection -Name 'Actions' -AllowAllOrigins

.EXAMPLE
ConvertTo-PodeSseConnection -Name 'Actions' -ClientId 'my-client-id'
#>
function ConvertTo-PodeSseConnection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter()]
        [string]
        $Group,

        [Parameter()]
        [ValidateSet('Default', 'Local', 'Global')]
        [string]
        $Scope = 'Default',

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
        # SSE can only be configured on requests with an Accept header value of text/event-stream
        throw ($PodeLocale.sseOnlyConfiguredOnEventStreamAcceptHeaderExceptionMessage)
    }

    # check for default scope, and set
    if ($Scope -ieq 'default') {
        $Scope = $PodeContext.Server.Sse.DefaultScope
    }

    # generate clientId
    $ClientId = New-PodeSseClientId -ClientId $ClientId

    # set and send SSE headers
    $ClientId = $WebEvent.Response.SetSseConnection($Scope, $ClientId, $Name, $Group, $RetryDuration, $AllowAllOrigins.IsPresent)

    # create SSE property on WebEvent
    $WebEvent.Sse = @{
        Name        = $Name
        Group       = $Group
        ClientId    = $ClientId
        LastEventId = Get-PodeHeader -Name 'Last-Event-ID'
        IsLocal     = ($Scope -ieq 'local')
    }
}

<#
.SYNOPSIS
Sets the default scope for new SSE connections.

.DESCRIPTION
Sets the default scope for new SSE connections.

.PARAMETER Scope
The default Scope for new SSE connections, either Local or Global.
- If the Scope is Local, then new SSE connections will only be opened for the duration of the request to a Route that configured it.
- If the Scope is Global, then new SSE connections will be cached internally so events can be sent to the connection from Tasks, Timers, and other Routes, etc.

.EXAMPLE
Set-PodeSseDefaultScope -Scope Local

.EXAMPLE
Set-PodeSseDefaultScope -Scope Global
#>
function Set-PodeSseDefaultScope {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Local', 'Global')]
        [string]
        $Scope
    )

    $PodeContext.Server.Sse.DefaultScope = $Scope
}

<#
.SYNOPSIS
Retrieves the default SSE connection scope for new SSE connections.

.DESCRIPTION
Retrieves the default SSE connection scope for new SSE connections.

.EXAMPLE
$scope = Get-PodeSseDefaultScope
#>
function Get-PodeSseDefaultScope {
    [CmdletBinding()]
    param()

    return $PodeContext.Server.Sse.DefaultScope
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

.PARAMETER Group
An optional array of 1 or more SSE connection Groups to send Events to, for the specified SSE connection Name.

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
These details will be set if ConvertTo-PodeSseConnection has just been called. Or if X-PODE-SSE-CLIENT-ID and X-PODE-SSE-NAME are set on an HTTP request.

.EXAMPLE
Send-PodeSseEvent -FromEvent -Data 'This is an event'

.EXAMPLE
Send-PodeSseEvent -FromEvent -Data @{ Message = 'A message' }

.EXAMPLE
Send-PodeSseEvent -Name 'Actions' -Data @{ Message = 'A message' }

.EXAMPLE
Send-PodeSseEvent -Name 'Actions' -Group 'admins' -Data @{ Message = 'A message' }

.EXAMPLE
Send-PodeSseEvent -Name 'Actions' -Data @{ Message = 'A message' } -ID 123 -EventType 'action'
#>
function Send-PodeSseEvent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'Name')]
        [string]
        $Name,

        [Parameter(ParameterSetName = 'Name')]
        [string[]]
        $Group = $null,

        [Parameter(ParameterSetName = 'Name')]
        [string[]]
        $ClientId = $null,

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
        $Group = $WebEvent.Sse.Group
        $ClientId = $WebEvent.Sse.ClientId
    }

    # error if no name
    if ([string]::IsNullOrEmpty($Name)) {
        # An SSE connection Name is required, either from -Name or $WebEvent.Sse.Name
        throw ($PodeLocale.sseConnectionNameRequiredExceptionMessage)
    }

    # check if broadcast level
    if (!(Test-PodeSseBroadcastLevel -Name $Name -Group $Group -ClientId $ClientId)) {
        # SSE failed to broadcast due to defined SSE broadcast level
        throw ($PodeLocale.sseFailedToBroadcastExceptionMessage -f $Name, (Get-PodeSseBroadcastLevel -Name $Name))
    }

    # send event
    $PodeContext.Server.Http.Listener.SendSseEvent($Name, $Group, $ClientId, $EventType, $Data, $Id)
}

<#
.SYNOPSIS
Close one or more SSE connections.

.DESCRIPTION
Close one or more SSE connections. Either all connections for an SSE connection Name, or specific ClientIds for a Name.

.PARAMETER Name
The Name of the SSE connection which has the ClientIds for the connections to close. If supplied on its own, all connections will be closed.

.PARAMETER Group
An optional array of 1 or more SSE connection Groups, that are for the SSE connection Name. If supplied without any ClientIds, then all connections for the Group(s) will be closed.

.PARAMETER ClientId
An optional array of 1 or more SSE connection ClientIds, that are for the SSE connection Name.
If not supplied, every SSE connection for the supplied Name will be closed.

.EXAMPLE
Close-PodeSseConnection -Name 'Actions'

.EXAMPLE
Close-PodeSseConnection -Name 'Actions' -Group 'admins'

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
        $Group = $null,

        [Parameter()]
        [string[]]
        $ClientId = $null
    )

    $PodeContext.Server.Http.Listener.CloseSseConnection($Name, $Group, $ClientId)
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
        $ClientId = $WebEvent.Request.SseClientId
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
    [OutputType([bool])]
    param(
        [Parameter()]
        [string]
        $ClientId
    )

    # get clientId from WebEvent if not passed
    if ([string]::IsNullOrEmpty($ClientId)) {
        $ClientId = $WebEvent.Request.SseClientId
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
Test if the name of an SSE connection exists or not.

.DESCRIPTION
Test if the name of an SSE connection exists or not.

.PARAMETER Name
The Name of an SSE connection to test.

.EXAMPLE
if (Test-PodeSseName -Name 'Example') { ... }
#>
function Test-PodeSseName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    return $PodeContext.Server.Http.Listener.TestSseConnectionExists($Name)
}

<#
.SYNOPSIS
Test if an SSE connection ClientId exists or not.

.DESCRIPTION
Test if an SSE connection ClientId exists or not.

.PARAMETER Name
The Name of an SSE connection.

.PARAMETER ClientId
The SSE connection ClientId to test.

.EXAMPLE
if (Test-PodeSseClientId -Name 'Example' -ClientId 'my-client-id') { ... }
#>
function Test-PodeSseClientId {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $true)]
        [string]
        $ClientId
    )

    return $PodeContext.Server.Http.Listener.TestSseConnectionExists($Name, $ClientId)
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
A Secret to sign ClientIds, Get-PodeServerDefaultSecret can be used.

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
        [Parameter(Mandatory = $true)]
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

<#
.SYNOPSIS
Set an allowed broadcast level for SSE connections.

.DESCRIPTION
Set an allowed broadcast level for SSE connections, either for all SSE connection names or specific ones.

.PARAMETER Name
An optional Name for an SSE connection (default: *).

.PARAMETER Type
The broadcast level Type for the SSE connection.
Name = Allow broadcasting at all levels, including broadcasting to all Groups and/or ClientIds for an SSE connection Name.
Group = Allow broadcasting to only Groups or specific ClientIds. If neither Groups nor ClientIds are supplied, sending an event will fail.
ClientId = Allow broadcasting to only ClientIds. If no ClientIds are supplied, sending an event will fail.

.EXAMPLE
Set-PodeSseBroadcastLevel -Type Name

.EXAMPLE
Set-PodeSseBroadcastLevel -Type Group

.EXAMPLE
Set-PodeSseBroadcastLevel -Name 'Actions' -Type ClientId
#>
function Set-PodeSseBroadcastLevel {
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name = '*',

        [Parameter()]
        [ValidateSet('Name', 'Group', 'ClientId')]
        [string]
        $Type
    )

    $PodeContext.Server.Sse.BroadcastLevel[$Name] = $Type.ToLowerInvariant()
}

<#
.SYNOPSIS
Retrieve the broadcast level for an SSE connection Name.

.DESCRIPTION
Retrieve the broadcast level for an SSE connection Name. If one hasn't been set explicitly then the base level will be checked.
If no broadcasting level have been set at all, then the "Name" level will be returned.

.PARAMETER Name
The Name of an SSE connection.

.EXAMPLE
$level = Get-PodeSseBroadcastLevel -Name 'Actions'
#>
function Get-PodeSseBroadcastLevel {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    # if no levels, return null
    if ($PodeContext.Server.Sse.BroadcastLevel.Count -eq 0) {
        return 'name'
    }

    # get level or default level
    $level = $PodeContext.Server.Sse.BroadcastLevel[$Name]
    if ([string]::IsNullOrEmpty($level)) {
        $level = $PodeContext.Server.Sse.BroadcastLevel['*']
    }

    if ([string]::IsNullOrEmpty($level)) {
        $level = 'name'
    }

    # return level
    return $level
}

<#
.SYNOPSIS
Test if an SSE connection can be broadcasted to, given the Name, Group, and ClientIds.

.DESCRIPTION
Test if an SSE connection can be broadcasted to, given the Name, Group, and ClientIds.

.PARAMETER Name
The Name of the SSE connection.

.PARAMETER Group
An array of 1 or more Groups.

.PARAMETER ClientId
An array of 1 or more ClientIds.

.EXAMPLE
if (Test-PodeSseBroadcastLevel -Name 'Actions') { ... }

.EXAMPLE
if (Test-PodeSseBroadcastLevel -Name 'Actions' -Group 'admins') { ... }

.EXAMPLE
if (Test-PodeSseBroadcastLevel -Name 'Actions' -ClientId 'my-client-id') { ... }
#>
function Test-PodeSseBroadcastLevel {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter()]
        [string[]]
        $Group,

        [Parameter()]
        [string[]]
        $ClientId
    )

    # get level, and if no level or level=name, return true
    $level = Get-PodeSseBroadcastLevel -Name $Name
    if ([string]::IsNullOrEmpty($level) -or ($level -ieq 'name')) {
        return $true
    }

    # if level=group, return false if no groups or clientIds
    # if level=clientId, return false if no clientIds
    switch ($level) {
        'group' {
            if ((($null -eq $Group) -or ($Group.Length -eq 0)) -and (($null -eq $ClientId) -or ($ClientId.Length -eq 0))) {
                return $false
            }
        }

        'clientid' {
            if (($null -eq $ClientId) -or ($ClientId.Length -eq 0)) {
                return $false
            }
        }
    }

    # valid, return true
    return $true
}