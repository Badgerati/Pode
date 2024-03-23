# SSE

You can convert regular HTTP requests made to a Route into an SSE connection, allowing you to stream events from your server to one or more connected clients. Connections can be scoped to just the Route that converted the request and it will be closed at the end of the Route like a normal request flow (Local), or you can keep the connection open beyond the request flow and be used server-wide for sending events (Global).

SSE connections are typically made from client browsers via JavaScript, using the [EventSource](https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events/Using_server-sent_events) class.

## Convert Request

To convert a request into an SSE connection use [`ConvertTo-PodeSseConnection`](../../../../Functions/SSE/ConvertTo-PodeSseConnection). This will automatically send back the appropriate HTTP response headers to the client, converting it into an SSE connection; allowing the connection to be kept open, and for events to be streamed back to the client. A `-Name` must be supplied during the conversion, allowing for easier reference to all connections later on, and allowing for different connection groups (of which, you can also have `-Group` within a Name as well).

!!! important
    For a request to be convertible, it must have an `Accept` HTTP request header value of `text/event-stream`.

Any requests to the following Route will be converted to a globally scoped SSE connection, and be available under the `Events` name:

```powershell
Add-PodeRoute -Method Get -Path '/events' -ScriptBlock {
    ConvertTo-PodeSseConnection -Name 'Events'
}
```

You could then use [`Send-PodeSseEvent`](../../../../Functions/SSE/Send-PodeSseEvent) in a Schedule (more info [below](#send-events)) to broadcast an event, every minute, to all connected clients within the `Events` name:

```powershell
Add-PodeSchedule -Name 'Example' -Cron (New-PodeCron -Every Minute) -ScriptBlock {
    Send-PodeSseEvent -Name 'Events' -Data "Hello there! The datetime is: $([datetime]::Now.TimeOfDay)"
}
```

Once [`ConvertTo-PodeSseConnection`](../../../../Functions/SSE/ConvertTo-PodeSseConnection) has been called, the `$WebEvent` object will be extended to include a new `SSE` property. This new property will have the following items:

| Name        | Description                                                                                             |
| ----------- | ------------------------------------------------------------------------------------------------------- |
| Name        | The Name given to the connection                                                                        |
| Group       | An optional Group assigned to the connection within the Name                                            |
| ClientId    | The assigned ClientId for the connection - this will be different to a passed ClientId if using signing |
| LastEventId | The last EventId the client saw, if this is a reconnecting SSE request                                  |
| IsLocal     | Is the connection Local or Global                                                                       |

Therefore, after converting a request, you can get the client ID back via:

```powershell
Add-PodeRoute -Method Get -Path '/events' -ScriptBlock {
    ConvertTo-PodeSseConnection -Name 'Events'
    $clientId = $WebEvent.Sse.ClientId
}
```

!!! tip
    The Name, Group, and Client ID values are also sent back on the HTTP response during conversion as headers. These won't be available if you're using JavaScript's `EventSource` class, but could be if using other SSE libraries. The headers are:

    * `X-PODE-SSE-CLIENT-ID`
    * `X-PODE-SSE-NAME`
    * `X-PODE-SSE-GROUP`

### ClientIds

ClientIds created by [`ConvertTo-PodeSseConnection`](../../../../Functions/SSE/ConvertTo-PodeSseConnection) will be a GUID by default however, you can supply your own IDs via the `-ClientId` parameter:

```powershell
Add-PodeRoute -Method Get -Path '/events' -ScriptBlock {
    $clientId = Get-Random -Minimum 10000 -Maximum 999999
    ConvertTo-PodeSseConnection -Name 'Events' -ClientId $clientId
}
```

You can also [sign clientIds](#signing-clientids) as well.

### Scopes

The default scope for a new SSE connection is "Global", which means the connection will be stored internally and can be used outside of the converting Route to stream events back to the client.

The default scope for new SSE connections can be altered by using [`Set-PodeSseDefaultScope`](../../../../Functions/SSE/Set-PodeSseDefaultScope). For example, if you wanted all new SSE connections to instead default to a Local scope:

```powershell
Set-PodeSseDefaultScope -Scope Local
```

#### Global

A Globally scoped SSE connection is the default (unless altered via [`Set-PodeSseDefaultScope`](../../../../Functions/SSE/Set-PodeSseDefaultScope)). A Global connection has the following features:

* They are kept open, even after the Route that converted the request has finished.
* The connection is stored internally, so that events can be streamed to the clients from other Routes, Timers, etc.
* You can send events to a specific connection if you know the Name and ClientId for the connection.
* Global connections can be closed via [`Close-PodeSseConnection`](../../../../Functions/SSE/Close-PodeSseConnection).

For example, the following will convert requests to `/events` into global SSE connections, and then a Schedule will send events to them every minute:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address * -Port 8090 -Protocol Http

    Add-PodeRoute -Method Get -Path '/events' -ScriptBlock {
        ConvertTo-PodeSseConnection -Name 'Events'
    }

    Add-PodeSchedule -Name 'Example' -Cron (New-PodeCron -Every Minute) -ScriptBlock {
        Send-PodeSseEvent -Name 'Events' -Data "Hello there! The datetime is: $([datetime]::Now.TimeOfDay)"
    }
}
```

#### Local

A Local connection has the following features:

* When the Route that converted the request has finished, the connection will be closed - the same as HTTP requests.
* The connection is **not** stored internally, it is only available for the lifecycle of the HTTP request.
* You can send events back to the connection from within the converting Route's scriptblock, but not from Timers, etc. When sending events back for local connections you will need to use the `-FromEvent` switch on [`Send-PodeSseEvent`](../../../../Functions/SSE/Send-PodeSseEvent).

For example, the following will convert requests to `/events` into local SSE connections, and two events will be sent back to the client before the connection is closed:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address * -Port 8090 -Protocol Http

    Add-PodeRoute -Method Get -Path '/events' -ScriptBlock {
        ConvertTo-PodeSseConnection -Name 'Events' -Scope Local
        Send-PodeSseEvent -FromEvent -Data "Hello there! The datetime is: $([datetime]::Now.TimeOfDay)"
        Start-Sleep -Seconds 10
        Send-PodeSseEvent -FromEvent -Data "Hello there! The datetime is: $([datetime]::Now.TimeOfDay)"
    }
}
```

### Inbuilt Events

Pode has two inbuilt events that it will send to your SSE connections. These events will be sent automatically when a connection is opened, and when it is closed.

!!! important
    It is recommended to listen for the close event from Pode, as this way you'll know when Pode has closed the connection and you can perform any required clean-up.

#### Open

When an SSE connection is opened, via [`ConvertTo-PodeSseConnection`](../../../../Functions/SSE/ConvertTo-PodeSseConnection), Pode will send a `pode.open` event to your client. This event will also contain the `clientId`, `group`, and `name` of the SSE connection.

You can listen for this event in JavaScript if using `EventSource`, as follows:

```javascript
const sse = new EventSource('/events');

sse.addEventListener('pode.open', (e) => {
    var data = JSON.parse(e.data);
    let clientId = data.clientId;
    let group = data.group;
    let name = data.name;
});
```

#### Close

When an SSE connection is closed, either via [`Close-PodeSseConnection`](../../../../Functions/SSE/Close-PodeSseConnection) or when the Pode server stops, Pode will send a `pode.close` event to your clients. This will be an empty event, purely for clean-up purposes.

You can listen for this event in JavaScript if using `EventSource`, as follows:

```javascript
const sse = new EventSource('/events');

sse.addEventListener('pode.close', (e) => {
    sse.close();
});
```

## Send Events

To send an event from the server to one or more connected clients, you can use [`Send-PodeSseEvent`](../../../../Functions/SSE/Send-PodeSseEvent). Using the `-Data` parameter, you can either send a raw string value, or a more complex hashtable/psobject which will be auto-converted into a JSON string.

For example, to broadcast an event to all clients on an "Events" SSE connection:

```powershell
# simple string
Send-PodeSseEvent -Name 'Events' -Data 'Hello there!'

# complex object
Send-PodeSseEvent -Name 'Events' -Data @{ Value = 'Hello there!' }
```

Or to send an event to a specific client:

```powershell
Send-PodeSseEvent -Name 'Events' -ClientId 'some-client-id' -Data 'Hello there!'
```

You can also specify an optional `-Id` and `-EventType` for the SSE event being sent. The `-EventType` can be used in JavaScript to register event listeners, and the `-Id` is used by the browser to keep track of events being sent in case the connection is dropped.

```powershell
$id = [int][datetime]::Now.TimeOfDay.TotalSeconds
$data = @{ Date = [datetime]::Now.ToString() }

Send-PodeSseEvent -Name 'Events' -Id $id -EventType 'Date' -Data $data
```

### Broadcast Levels

By default, Pode will allow broadcasting of events to all clients for an SSE connection Name, Group, or a specific ClientId.

You can supply a custom broadcasting level for specific SSE connection names (or all), limiting broadcasting to requiring a specific ClientId for example, by using [`Set-PodeSseBroadcastLevel`](../../../../Functions/SSE/Set-PodeSseBroadcastLevel). If a `-Name` is not supplied then the level type is applied to all SSE connections.

For example, the following will only allow events to be broadcast to an SSE connection name if a ClientId is also specified on [`Send-PodeSseEvent`](../../../../Functions/SSE/Send-PodeSseEvent):

```powershell
# apply to all SSE connections
Set-PodeSseBroadcastLevel -Type 'ClientId'

# apply to just SSE connections with name = Events
Set-PodeSseBroadcastLevel -Name 'Events' -Type 'ClientId'
```

The following levels are available:

| Level    | Description                                                         |
| -------- | ------------------------------------------------------------------- |
| Name     | A Name is required. Groups/ClientIds are optional.                  |
| Group    | A Name is required. One of either a Group and ClientId is required. |
| ClientId | A Name and a ClientId are required.                                 |

## Signing ClientIds

Similar to Sessions and Cookies, you can sign SSE connection ClientIds. This can be done by calling [`Enable-PodeSseSigning`](../../../../Functions/SSE/Enable-PodeSseSigning) and supplying a `-Secret` to sign the ClientIds.

!!! tip
    You can use the inbuilt [`Get-PodeServerDefaultSecret`](../../../../Functions/Core/Get-PodeServerDefaultSecret) function to retrieve an internal Pode server secret which can be used. However, be warned that this secret is regenerated to a random value on every server start/restart.

```powershell
Enable-PodeSseSigning -Secret 'super-secret'
Enable-PodeSseSigning -Secret (Get-PodeServerDefaultSecret)
```

When signing is enabled, all clientIds will be signed regardless if they're an internally generated random GUID or supplied via `-ClientId` on [`ConvertTo-PodeSseConnection`](../../../../Functions/SSE/ConvertTo-PodeSseConnection). A signed clientId will look as follows, and have the structure `s:<clientId>.<signature>`:

```plain
s:5d12f974-7b1a-4524-ab93-6afbf42c4ffa.uvG49LcojTMuJ0l4yzBzr6jCqEV8gGC/0YgsYU1QEuQ=
```

You can also supply the `-Strict` switch to [`Enable-PodeSseSigning`](../../../../Functions/SSE/Enable-PodeSseSigning), which will extend the secret during signing with the client's IP Address and User Agent.

## Request Headers

If you have an SSE connection open for a client, and you want to have the client send AJAX requests to the server but have the responses streamed back over the SSE connection, then you can identify the SSE connection for the client using the following HTTP headers:

* `X-PODE-SSE-CLIENT-ID`
* `X-PODE-SSE-NAME`
* `X-PODE-SSE-GROUP`

At a minimum, you'll need the `X-PODE-SSE-CLIENT-ID` header. If supplied Pode will automatically verify the client ID for you, including if the signing of the client ID is valid - if you're using client ID signing.

When these headers are supplied in a request, Pode will set up the `$WebEvent.Sse` property again - similar to the property set up from [conversion](#convert-request) above:

| Name        | Description                                                        |
| ----------- | ------------------------------------------------------------------ |
| Name        | The Name for the connection from X-PODE-SSE-NAME                   |
| Group       | The Group for the connection from X-PODE-SSE-GROUP                 |
| ClientId    | The assigned ClientId for the connection from X-PODE-SSE-CLIENT-ID |
| LastEventId | `$null`                                                            |
| IsLocal     | `$false`                                                           |

!!! note
    If you only supply the Name or Group headers, then the `$WebEvent.Sse` property will not be configured. The ClientId is required as a minimum.
