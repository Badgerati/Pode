<#
.SYNOPSIS
Converts the current HTTP request to a Route to be a Signal (WebSocket) connection.

.DESCRIPTION
Converts the current HTTP request to a Route to be an Signal (WebSocket) connection, by sending the required headers back to the client.

.PARAMETER Name
The Name of the Signal connection, which ClientIds will be stored under.

.PARAMETER Group
An optional Group for the Signal connection, to enable broadcasting events to all connections for an Signal connection name in a Group.

.PARAMETER Scope
The Scope of the Signal connection, either Default, Local or Global (Default: Default).
- If the Scope is Default, then it will be Global unless the default has been updated via Set-PodeSignalDefaultScope.
- If the Scope is Local, then the Signal connection will only be opened for the duration of the request to a Route that configured it.
- If the Scope is Global, then the Signal connection will be cached internally so events can be sent to the connection from Tasks, Timers, and other Routes, etc.

.PARAMETER ClientId
An optional ClientId to use for the Signal connection, this value will be signed if signing is enabled (Default: GUID).

.EXAMPLE
ConvertTo-PodeSignalConnection -Name 'Metrics'

.EXAMPLE
ConvertTo-PodeSignalConnection -Name 'Metrics' -Scope Local

.EXAMPLE
ConvertTo-PodeSignalConnection -Name 'Metrics' -Group 'admins'

.EXAMPLE
ConvertTo-PodeSignalConnection -Name 'Metrics' -ClientId 'my-client-id'
#>
function ConvertTo-PodeSignalConnection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [Alias('Path')]
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
        [string]
        $ClientId
    )

    # check for default scope
    if ($Scope -ieq 'default') {
        $Scope = $PodeContext.Server.Signals.DefaultScope
    }

    # generate clientId if not supplied
    $ClientId = New-PodeSignalClientId -ClientId $ClientId

    # set and send WebSocket headers
    $trackEvents = Test-PodeSignalEvent -Name $Name -Type Connect, Disconnect
    $signalConnection = Wait-PodeTask -Task $WebEvent.Request.Context.UpgradeToWebSocket($Scope, $ClientId, $Name, $Group, $trackEvents)

    # create Signal property on WebEvent
    $WebEvent.Signal = $signalConnection

    # add local Signal endware to trigger disconnect event
    if ($WebEvent.Signal.IsLocal -and (Test-PodeSignalEvent -Name $Name -Type Disconnect)) {
        $WebEvent.OnEnd += @{
            Logic = {
                Invoke-PodeSignalEvent -Name $WebEvent.Signal.Name -Type Disconnect -Connection $WebEvent.Signal.ToHashtable()
            }
        }
    }
}

<#
.SYNOPSIS
Sets the default scope for new Signal connections.

.DESCRIPTION
Sets the default scope for new Signal connections.

.PARAMETER Scope
The default Scope for new Signal connections, either Local or Global.
- If the Scope is Local, then new Signal connections will only be opened for the duration of the request to a Route that configured it.
- If the Scope is Global, then new Signal connections will be cached internally so events can be sent to the connection from Tasks, Timers, and other Routes, etc.

.EXAMPLE
Set-PodeSignalDefaultScope -Scope Local

.EXAMPLE
Set-PodeSignalDefaultScope -Scope Global
#>
function Set-PodeSignalDefaultScope {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Local', 'Global')]
        [string]
        $Scope
    )

    $PodeContext.Server.Signals.DefaultScope = $Scope
}

<#
.SYNOPSIS
Retrieves the default Signal connection scope for new Signal connections.

.DESCRIPTION
Retrieves the default Signal connection scope for new Signal connections.

.EXAMPLE
$scope = Get-PodeSignalDefaultScope
#>
function Get-PodeSignalDefaultScope {
    [CmdletBinding()]
    param()

    return $PodeContext.Server.Signals.DefaultScope
}

<#
.SYNOPSIS
Broadcasts a message to one or more Signal (WebSocket) connections.

.DESCRIPTION
Send a message to one or more Signal connections. This can either be:
- Every client for a Signal connection Name
- Specific ClientIds for a Signal connection Name
- The current Signal connection being referenced within $WebEvent.Signal

.PARAMETER Data
The Data for the message being sent, either as a String or a Hashtable/PSObject. If the latter, it will be converted into JSON.

.PARAMETER Name
An Signal connection Name - multiple may be supplied.

.PARAMETER Group
An optional array of 1 or more Signal connection Groups to send messages to, for the specified Signal connection Name.

.PARAMETER ClientId
An optional array of 1 or more Signal connection ClientIds to send messages to, for the specified Signal connection Name.

.PARAMETER Depth
The Depth to generate the JSON document - the larger this value the worse performance gets.

.PARAMETER Mode
The Mode to broadcast a message: Auto, Broadcast, Direct. (Default: Auto). Legacy parameter, purely here for backwards compatibility.
- Auto: (Recommended) Decides whether to broadcast or send directly based on the context of the call.
- Broadcast: Always broadcast the message to the specified Name/Group/ClientIds.
- Direct: Always send the message directly back to the current Signal connection.

.PARAMETER IgnoreEvent
If supplied, any WebEvent/SignalEvent will be ignored.

.EXAMPLE
Send-PodeSignal -Data @{ Message = 'Hello, world!' }

.EXAMPLE
Send-PodeSignal -Data @{ Data = @(123, 100, 101) } -Name '/response-charts'
#>
function Send-PodeSignal {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true, Position = 0)]
        [Alias('Value')]
        $Data,

        [Parameter()]
        [Alias('Path')]
        [string[]]
        $Name,

        [Parameter()]
        [string[]]
        $Group = $null,

        [Parameter()]
        [string[]]
        $ClientId,

        [Parameter()]
        [int]
        $Depth = 10,

        [Parameter()]
        [ValidateSet('Auto', 'Broadcast', 'Direct')]
        [string]
        $Mode = 'Auto',

        [switch]
        $IgnoreEvent
    )

    begin {
        $pipelineValue = @()
    }

    process {
        $pipelineValue += $_
    }

    end {
        if ($pipelineValue.Count -gt 1) {
            $Data = $pipelineValue
        }

        # do nothing if no value
        if ([string]::IsNullOrEmpty($Data) -or ($Data.Length -eq 0)) {
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

        # send directly back to the current connection
        if (
            ($Mode -ieq 'Direct') -or
            (!$IgnoreEvent -and ($WebEvent.Response.Context.Signal.IsLocal -or $SignalEvent.Data.Direct))
        ) {
            $signal = $SignalEvent.Response.Context.Signal
            if ($null -eq $signal) {
                $signal = $WebEvent.Response.Context.Signal
            }

            $null = Wait-PodeTask -Task $signal.Send($Data)
            return
        }

        # from event and global?
        if (!$IgnoreEvent -and ($null -ne $SignalEvent)) {
            if ([string]::IsNullOrEmpty($Name)) {
                $Name = $SignalEvent.Data.Path
            }

            if ([string]::IsNullOrEmpty($Group)) {
                $Group = $SignalEvent.Data.Group
            }

            if ([string]::IsNullOrEmpty($ClientId)) {
                $ClientId = $SignalEvent.Data.ClientId
            }
        }

        # if no Names, get all Names
        if ([string]::IsNullOrEmpty($Name)) {
            $Name = Get-PodeSignalNameList
        }

        # broadcast message to clients
        foreach ($n in $Name) {
            # check the broadcast level
            if (!(Test-PodeSignalBroadcastLevel -Name $n -Group $Group -ClientId $ClientId)) {
                # Signal failed to broadcast due to defined Signal broadcast level
                throw ($PodeLocale.signalFailedToBroadcastExceptionMessage -f $n, (Get-PodeSignalBroadcastLevel -Name $n))
            }

            # send message
            $PodeContext.Server.Http.Listener.SendSignalMessage($n, $Group, $ClientId, $Data)
        }
    }
}

<#
.SYNOPSIS
Close one or more Signal connections.

.DESCRIPTION
Close one or more Signal connections. Either all connections for a Signal connection Name, or specific ClientIds for a Name.

.PARAMETER Name
The Name of the Signal connection which has the ClientIds for the connections to close. If supplied on its own, all connections will be closed.

.PARAMETER Group
An optional array of 1 or more Signal connection Groups, that are for the Signal connection Name. If supplied without any ClientIds, then all connections for the Group(s) will be closed.

.PARAMETER ClientId
An optional array of 1 or more Signal connection ClientIds, that are for the Signal connection Name.
If not supplied, every Signal connection for the supplied Name will be closed.

.EXAMPLE
Close-PodeSignalConnection -Name 'Metrics'

.EXAMPLE
Close-PodeSignalConnection -Name 'Metrics' -Group 'admins'

.EXAMPLE
Close-PodeSignalConnection -Name 'Metrics' -ClientId @('my-client-id', 'my-other'id')
#>
function Close-PodeSignalConnection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [Alias('Path')]
        [string]
        $Name,

        [Parameter()]
        [string[]]
        $Group = $null,

        [Parameter()]
        [string[]]
        $ClientId = $null
    )

    $PodeContext.Server.Http.Listener.CloseSignal($Name, $Group, $ClientId)
}

<#
.SYNOPSIS
Test if a Signal connection ClientId is validly signed.

.DESCRIPTION
Test if a Signal connection ClientId is validly signed.

.PARAMETER ClientId
An optional Signal connection ClientId, if not supplied it will be retrieved from $WebEvent.

.EXAMPLE
if (Test-PodeSignalClientIdValid) { ... }

.EXAMPLE
if (Test-PodeSignalClientIdValid -ClientId 's:my-already-signed-client-id.uvG49LcojTMuJ0l4yzBzr6jCqEV8gGC/0YgsYU1QEuQ=') { ... }
#>
function Test-PodeSignalClientIdSigned {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $ClientId
    )

    # get clientId from SignalEvent if not passed
    if ([string]::IsNullOrEmpty($ClientId)) {
        $ClientId = $SignalEvent.Data.ClientId
    }

    # test if clientId is validly signed
    return Test-PodeValueSigned -Value $ClientId -Secret $PodeContext.Server.Signals.Secret -Strict:($PodeContext.Server.Signals.Strict)
}

<#
.SYNOPSIS
Test if a Signal connection ClientId is valid.

.DESCRIPTION
Test if a Signal connection ClientId, passed or from $WebEvent, is valid. A ClientId is valid if it's not signed and we're not signing ClientIds,
or if we are signing ClientIds and the ClientId is validly signed.

.PARAMETER ClientId
An optional Signal connection ClientId, if not supplied it will be retrieved from $WebEvent.

.EXAMPLE
if (Test-PodeSignalClientIdValid) { ... }

.EXAMPLE
if (Test-PodeSignalClientIdValid -ClientId 'my-client-id') { ... }
#>
function Test-PodeSignalClientIdValid {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter()]
        [string]
        $ClientId
    )

    # get clientId from SignalEvent if not passed
    if ([string]::IsNullOrEmpty($ClientId)) {
        $ClientId = $SignalEvent.Data.ClientId
    }

    # if no clientId, then it's not valid
    if ([string]::IsNullOrEmpty($ClientId)) {
        return $false
    }

    # if we're not signing, then valid if not signed, but invalid if signed
    if (!$PodeContext.Server.Signals.Signed) {
        return !$ClientId.StartsWith('s:')
    }

    # test if clientId is validly signed
    return Test-PodeSignalClientIdSigned -ClientId $ClientId
}

<#
.SYNOPSIS
Test if the name of a Signal connection exists or not.

.DESCRIPTION
Test if the name of a Signal connection exists or not.

.PARAMETER Name
The Name of a Signal connection to test.

.EXAMPLE
if (Test-PodeSignalName -Name 'Example') { ... }
#>
function Test-PodeSignalName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    return $PodeContext.Server.Http.Listener.TestSignalConnectionExists($Name)
}

<#
.SYNOPSIS
Test if a Signal connection ClientId exists or not.

.DESCRIPTION
Test if a Signal connection ClientId exists or not.

.PARAMETER Name
The Name of a Signal connection.

.PARAMETER Group
An optional Group for the Signal connection.

.PARAMETER ClientId
The Signal connection ClientId to test.

.EXAMPLE
if (Test-PodeSignalClientId -Name 'Example' -ClientId 'my-client-id') { ... }
#>
function Test-PodeSignalClientId {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter()]
        [string[]]
        $Group = $null,

        [Parameter(Mandatory = $true)]
        [string]
        $ClientId
    )

    return $PodeContext.Server.Http.Listener.TestSignalConnectionExists($Name, $Group, $ClientId)
}

<#
.SYNOPSIS
Generate a new Signal connection ClientId.

.DESCRIPTION
Generate a new Signal connection ClientId, which will be signed if signing enabled.

.PARAMETER ClientId
An optional Signal connection ClientId to use, if a custom ClientId is needed and required to be signed.

.EXAMPLE
$clientId = New-PodeSignalClientId

.EXAMPLE
$clientId = New-PodeSignalClientId -ClientId 'my-client-id'

.EXAMPLE
$clientId = New-PodeSignalClientId -ClientId 's:my-already-signed-client-id.uvG49LcojTMuJ0l4yzBzr6jCqEV8gGC/0YgsYU1QEuQ='
#>
function New-PodeSignalClientId {
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
    if ($PodeContext.Server.Signals.Signed -and !$ClientId.StartsWith('s:')) {
        $ClientId = Invoke-PodeValueSign -Value $ClientId -Secret $PodeContext.Server.Signals.Secret -Strict:($PodeContext.Server.Signals.Strict)
    }

    # return the clientId
    return $ClientId
}

<#
.SYNOPSIS
Enable the signing of Signal connection ClientIds.

.DESCRIPTION
Enable the signing of Signal connection ClientIds.

.PARAMETER Secret
A Secret to sign ClientIds, Get-PodeServerDefaultSecret can be used.

.PARAMETER Strict
If supplied, the Secret will be extended using the client request's UserAgent and RemoteIPAddress.

.EXAMPLE
Enable-PodeSignalSigning

.EXAMPLE
Enable-PodeSignalSigning -Strict

.EXAMPLE
Enable-PodeSignalSigning -Secret 'Sup3rS3cr37!' -Strict

.EXAMPLE
Enable-PodeSignalSigning -Secret 'Sup3rS3cr37!'
#>
function Enable-PodeSignalSigning {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Secret,

        [switch]
        $Strict
    )

    # flag that we're signing Signal connections
    $PodeContext.Server.Signals.Signed = $true
    $PodeContext.Server.Signals.Secret = $Secret
    $PodeContext.Server.Signals.Strict = $Strict.IsPresent
}

<#
.SYNOPSIS
Disable the signing of Signal connection ClientIds.

.DESCRIPTION
Disable the signing of Signal connection ClientIds.

.EXAMPLE
Disable-PodeSignalSigning
#>
function Disable-PodeSignalSigning {
    [CmdletBinding()]
    param()

    # flag that we're not signing Signal connections
    $PodeContext.Server.Signals.Signed = $false
    $PodeContext.Server.Signals.Secret = $null
    $PodeContext.Server.Signals.Strict = $false
}

<#
.SYNOPSIS
Set an allowed broadcast level for Signal connections.

.DESCRIPTION
Set an allowed broadcast level for Signal connections, either for all Signal connection names or specific ones.

.PARAMETER Name
An optional Name for an Signal connection (default: *).

.PARAMETER Type
The broadcast level Type for the Signal connection.
Name = Allow broadcasting at all levels, including broadcasting to all Groups and/or ClientIds for an Signal connection Name.
Group = Allow broadcasting to only Groups or specific ClientIds. If neither Groups nor ClientIds are supplied, sending an event will fail.
ClientId = Allow broadcasting to only ClientIds. If no ClientIds are supplied, sending an event will fail.

.EXAMPLE
Set-PodeSignalBroadcastLevel -Type Name

.EXAMPLE
Set-PodeSignalBroadcastLevel -Type Group

.EXAMPLE
Set-PodeSignalBroadcastLevel -Name 'Actions' -Type ClientId
#>
function Set-PodeSignalBroadcastLevel {
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

    $PodeContext.Server.Signals.BroadcastLevel[$Name] = $Type.ToLowerInvariant()
}

<#
.SYNOPSIS
Retrieve the broadcast level for an Signal connection Name.

.DESCRIPTION
Retrieve the broadcast level for an Signal connection Name. If one hasn't been set explicitly then the base level will be checked.
If no broadcasting level have been set at all, then the "Name" level will be returned.

.PARAMETER Name
The Name of an Signal connection.

.EXAMPLE
$level = Get-PodeSignalBroadcastLevel -Name 'Actions'
#>
function Get-PodeSignalBroadcastLevel {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    # if no levels, return null
    if ($PodeContext.Server.Signals.BroadcastLevel.Count -eq 0) {
        return 'name'
    }

    # get level or default level
    $level = $PodeContext.Server.Signals.BroadcastLevel[$Name]
    if ([string]::IsNullOrEmpty($level)) {
        $level = $PodeContext.Server.Signals.BroadcastLevel['*']
    }

    if ([string]::IsNullOrEmpty($level)) {
        $level = 'name'
    }

    # return level
    return $level
}

<#
.SYNOPSIS
Test if an Signal connection can be broadcasted to, given the Name, Group, and ClientIds.

.DESCRIPTION
Test if an Signal connection can be broadcasted to, given the Name, Group, and ClientIds.

.PARAMETER Name
The Name of the Signal connection.

.PARAMETER Group
An array of 1 or more Groups.

.PARAMETER ClientId
An array of 1 or more ClientIds.

.EXAMPLE
if (Test-PodeSignalBroadcastLevel -Name 'Actions') { ... }

.EXAMPLE
if (Test-PodeSignalBroadcastLevel -Name 'Actions' -Group 'admins') { ... }

.EXAMPLE
if (Test-PodeSignalBroadcastLevel -Name 'Actions' -ClientId 'my-client-id') { ... }
#>
function Test-PodeSignalBroadcastLevel {
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
    $level = Get-PodeSignalBroadcastLevel -Name $Name
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

<#
.SYNOPSIS
Returns a list of all Signal connection names.

.DESCRIPTION
Returns a list of all Signal connection names.

.EXAMPLE
$names = Get-PodeSignalNameList
#>
function Get-PodeSignalNameList {
    [CmdletBinding()]
    [OutputType([string[]])]
    param()

    return $PodeContext.Server.Http.Listener.Signals.Keys
}

<#
.SYNOPSIS
Retrieve a list of all Groups for an Signal connection Name.

.DESCRIPTION
Retrieve a list of all Groups for an Signal connection Name.

.PARAMETER Name
The Name of an Signal connection.

.EXAMPLE
$groups = Get-PodeSignalGroupList -Name 'Example'
#>
function Get-PodeSignalGroupList {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    # check if name exists
    if (!(Test-PodeSignalName -Name $Name)) {
        # Signal connection not found
        throw ($PodeLocale.signalConnectionNameNotFoundExceptionMessage -f $Name)
    }

    return $PodeContext.Server.Http.Listener.Signals.GetGroups($Name)
}

<#
.SYNOPSIS
Returns a list of ClientIds connected to a Signal.

.DESCRIPTION
Returns a list of ClientIds connected to a Signal. You can filter by Group.

.PARAMETER Name
The Name of the Signal connection.

.PARAMETER Group
An optional Group(s) for the Signal connection.

.EXAMPLE
$clientIds = Get-PodeSignalClientIdList -Name 'Example'

.EXAMPLE
$clientIds = Get-PodeSignalClientIdList -Name 'Example' -Group 'Admins'
#>
function Get-PodeSignalClientIdList {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter()]
        [string[]]
        $Group = $null
    )

    # check if name exists
    if (!(Test-PodeSignalName -Name $Name)) {
        # Signal connection not found
        throw ($PodeLocale.signalConnectionNameNotFoundExceptionMessage -f $Name)
    }

    return $PodeContext.Server.Http.Listener.Signals.GetClientIds($Name, $Group)
}

<#
.SYNOPSIS
Registers an event for one or more Signal connections.

.DESCRIPTION
Registers an event for one or more Signal connections, allowing custom scriptblocks to be executed when the event is triggered.

.PARAMETER Name
The Name of the Signal connection(s) to register the event for.

.PARAMETER Type
The Type of event to register, either Connect or Disconnect.

.PARAMETER EventName
The name of the event being registered.

.PARAMETER ScriptBlock
The ScriptBlock to execute when the event is triggered.

.PARAMETER ArgumentList
An optional array of arguments to pass to the ScriptBlock when executed.

.EXAMPLE
Register-PodeSignalEvent -Name 'Metrics' -Type Connect -EventName 'OnConnect' -ScriptBlock {
    "Client connected: $($TriggeredEvent.Connection.ClientId)" | Out-Default
}
#>
function Register-PodeSignalEvent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]
        $Name,

        [Parameter(Mandatory = $true)]
        [Pode.PodeClientConnectionEventType]
        $Type,

        [Parameter(Mandatory = $true)]
        [string]
        $EventName,

        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [object[]]
        $ArgumentList
    )

    foreach ($n in $Name) {
        # create "connection" reference
        if (!$PodeContext.Server.Signals.Connections.ContainsKey($n)) {
            $PodeContext.Server.Signals.Connections[$n] = @{
                Events = @{}
            }
        }

        # error if event already registered
        if ($PodeContext.Server.Signals.Connections[$n].Events.ContainsKey($Type.ToString()) -and
            $PodeContext.Server.Signals.Connections[$n].Events[$Type.ToString()].Contains($EventName)) {
            # "$($Type) event already registered for Signal connection $($n): $($EventName)"
            throw ($PodeLocale.signalEventAlreadyRegisteredExceptionMessage -f $Type, $n, $EventName)
        }
    }

    foreach ($n in $Name) {
        # check for scoped vars
        $ScriptBlock, $usingVars = Convert-PodeScopedVariables -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState

        # add event
        if (!$PodeContext.Server.Signals.Connections[$n].Events.ContainsKey($Type.ToString())) {
            $PodeContext.Server.Signals.Connections[$n].Events[$Type.ToString()] = [ordered]@{}
        }

        $PodeContext.Server.Signals.Connections[$n].Events[$Type.ToString()][$EventName] = @{
            Name           = $n
            EventName      = $EventName
            Type           = $Type.ToString()
            ScriptBlock    = $ScriptBlock
            UsingVariables = $usingVars
            Arguments      = $ArgumentList
        }
    }
}

<#
.SYNOPSIS
Unregister an event for one or more Signal connections.

.DESCRIPTION
Unregister an event for one or more Signal connections.

.PARAMETER Name
The Name of the Signal connection(s) to unregister the event for.

.PARAMETER Type
The Type of event to unregister, either Connect or Disconnect.

.PARAMETER EventName
The name of the event being unregistered.

.EXAMPLE
Unregister-PodeSignalEvent -Name 'Metrics' -Type Connect -EventName 'OnConnect'
#>
function Unregister-PodeSignalEvent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]
        $Name,

        [Parameter(Mandatory = $true)]
        [Pode.PodeClientConnectionEventType]
        $Type,

        [Parameter(Mandatory = $true)]
        [string]
        $EventName
    )

    foreach ($n in $Name) {
        # error if event not registered
        if (!$PodeContext.Server.Signals.Connections.ContainsKey($n) -or
            !$PodeContext.Server.Signals.Connections[$n].Events[$Type.ToString()].Contains($EventName)) {
            # "$($Type) event not registered for Signal connection $($n): $($EventName)"
            throw ($PodeLocale.signalEventNotRegisteredExceptionMessage -f $Type, $n, $EventName)
        }

        # remove event
        $null = $PodeContext.Server.Signals.Connections[$n].Events[$Type.ToString()].Remove($EventName)
    }
}

<#
.SYNOPSIS
Test if one or more Signal connection events exist.

.DESCRIPTION
Test if one or more Signal connection events exist.

.PARAMETER Name
An optional Name of the Signal connection(s) to test.

.PARAMETER Type
The Type of event to test, either Connect or Disconnect.

.PARAMETER EventName
An optional name of the event being tested.

.EXAMPLE
if (Test-PodeSignalEvent -Name 'Metrics' -Type Connect -EventName 'OnConnect') { ... }

.EXAMPLE
if (Test-PodeSignalEvent -Type Disconnect) { ... }
#>
function Test-PodeSignalEvent {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter()]
        [string[]]
        $Name,

        [Parameter(Mandatory = $true)]
        [Pode.PodeClientConnectionEventType[]]
        $Type,

        [Parameter()]
        [string[]]
        $EventName
    )

    $evts = Get-PodeSignalEvent -Name $Name -Type $Type -EventName $EventName
    return (($null -ne $evts) -and ($evts.Count -gt 0))
}

<#
.SYNOPSIS
Retrieve one or more Signal connection events.

.DESCRIPTION
Retrieve one or more Signal connection events.

.PARAMETER Name
An optional Name of the Signal connection(s) to retrieve events for.

.PARAMETER Type
The Type of event to retrieve, either Connect or Disconnect.

.PARAMETER EventName
An optional name of the event being retrieved.

.EXAMPLE
$events = Get-PodeSignalEvent -Name 'Metrics' -Type Connect -EventName 'OnConnect'

.EXAMPLE
$events = Get-PodeSignalEvent -Type Disconnect
#>
function Get-PodeSignalEvent {
    [CmdletBinding()]
    [OutputType([System.Object[]])]
    param(
        [Parameter()]
        [string[]]
        $Name,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [Pode.PodeClientConnectionEventType[]]
        $Type,

        [Parameter()]
        [string[]]
        $EventName
    )

    # return null if no connections
    if (($null -eq $PodeContext.Server.Signals.Connections) -or ($PodeContext.Server.Signals.Connections.Count -eq 0)) {
        return $null
    }

    # get connections by name if specified, otherwise all
    if (($null -ne $Name) -and ($Name.Length -gt 0)) {
        $connections = @(foreach ($n in $Name) {
                if ($PodeContext.Server.Signals.Connections.ContainsKey($n)) {
                    $PodeContext.Server.Signals.Connections[$n]
                }
            })
    }
    else {
        $connections = $PodeContext.Server.Signals.Connections.Values
    }

    # if no connections, return null
    if (($null -eq $connections) -or ($connections.Count -eq 0)) {
        return $null
    }

    # get events by type
    $evts = @(foreach ($t in $Type) {
            $connections.Events[$t.ToString()].Values
        })
    $connections = $null

    # filter by event names if specified
    if (($null -ne $EventName) -and ($EventName.Length -gt 0)) {
        $evts = @(foreach ($e in $evts) {
                if ($EventName -icontains $e.Name) {
                    $e
                }
            })
    }

    # return events
    return $evts
}