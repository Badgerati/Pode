# Endpoints

Pode has support for upgrading regular HTTP requests, made to a Route, to WebSocket (Signal) connections. This allows you to stream events/messages from your server to one or more connected clients, and vice-versa from clients to the server. Connections can be scoped to just the Route that converted the request and it will be closed at the end of the Route like a normal request flow (Local), or you can keep the connection open beyond the request flow and be used server-wide for sending events and messages (Global).

WebSocket connections are typically made from client browsers via JavaScript, using the [WebSocket](https://developer.mozilla.org/en-US/docs/Web/API/WebSocket) class. But they can also be made via other languages such as .NET, Java, etc. Examples on this page will use JavaScript.

!!! note
    The maximum size for WebSocket payloads in Pode depends on the version of PowerShell being used:

    - **PowerShell <= 6.0**, the maximum payload size is **32KB**.
    - **PowerShell >= 7.0**, the maximum payload size is **16KB**.

    If a message exceeds these limits, the connection may be closed or the message may not be delivered correctly.

!!! important
    For backwards compatibility the default upgrade path for WebSockets is to "auto-upgrade" when a valid HTTP request, with a `Sec-WebSocket-Key` header, is sent to the server. There is now a manual upgrade path, via `ConvertTo-PodeSignalConnection`, which can be used to align with SSE connections.

    The default auto-upgrade logic should now be considered deprecated, and will eventually be removed. This page will assume the manual approach, but will reference the legacy auto-upgrade approach as well.

## Server Side

### Listening

The first thing you'll need to do to enable your server to listen for WebSocket requests, is to setup an Endpoint via [`Add-PodeEndpoint`](../../Functions/Core/Add-PodeEndpoint) with a protocol of either `Ws` or `Wss`. This Endpoint will later be used by Pode to receive, send, and parse WebSocket messages once the initial HTTP request has be upgraded.

```powershell
Add-PodeEndpoint -Address * -Port 8091 -Protocol Ws -NoAutoUpgradeWebSockets

# or for secure sockets:
Add-PodeEndpoint -Address * -Port 8091 -Certificate './path/cert.pfx' -CertificatePassword 'dummy' `
    -Protocol Wss NoAutoUpgradeWebSockets
```

!!! note
    For those using the legacy auto-upgrade approach, you'll need to omit `-NoAutoUpgradeWebSockets`.

### Convert Request

To convert a request into a WebSocket connection use [`ConvertTo-PodeSignalConnection`](../../../Functions/Signals/ConvertTo-PodeSignalConnection). This will automatically send back the appropriate HTTP response headers to the client, converting it into a WebSocket connection; allowing the connection to be kept open, and for messages to be streamed back to the client - and vice-versa. A `-Name` must be supplied during the conversion, allowing for easier reference to all connections later on, and allowing for different connection groups (of which, you can also have `-Group` within a Name as well).

For example, any requests to the following Route will be converted to a globally scoped WebSocket connection, and be available under the `ResponseTimes` name:

```powershell
Add-PodeRoute -Method Get -Path '/response-times' -ScriptBlock {
    ConvertTo-PodeSignalConnection -Name 'ResponseTimes'
}
```

You could then use [`Send-PodeSignal`](../../../Functions/Signals/Send-PodeSignal) in a Schedule (more info [below](#send-messages)) to broadcast a message, every minute, to all connected clients within the `ResponseTimes` name:

```powershell
Add-PodeSchedule -Name 'Example' -Cron (New-PodeCron -Every Minute) -ScriptBlock {
    Send-PodeSignal -Name 'ResponseTimes' -Data @{ Durations = @(123, 101, 104) }
}
```

Once [`ConvertTo-PodeSignalConnection`](../../../Functions/Signals/ConvertTo-PodeSignalConnection) has been called, the `$WebEvent` object will be extended to include a new `Signal` property. This new property will have the following items:

| Name     | Description                                                                                             |
| -------- | ------------------------------------------------------------------------------------------------------- |
| Name     | The Name given to the connection                                                                        |
| Group    | An optional Group assigned to the connection within the Name                                            |
| ClientId | The assigned ClientId for the connection - this will be different to a passed ClientId if using signing |
| IsLocal  | Is the connection Local                                                                                 |
| IsGlobal | Is the connection Global                                                                                |

Therefore, after converting a request, you can get the client ID back via:

```powershell
Add-PodeRoute -Method Get -Path '/response-times' -ScriptBlock {
    ConvertTo-PodeSignalConnection -Name 'ResponseTimes'
    $clientId = $WebEvent.Signal.ClientId
}
```

!!! tip
    The Name, Group, and Client ID values are also sent back on the HTTP response during conversion as headers. These won't be available if you're using JavaScript's `WebSocket` class, but could be if using other WebSocket libraries. The headers are:

    * `X-PODE-SIGNAL-CLIENT-ID`
    * `X-PODE-SIGNAL-NAME`
    * `X-PODE-SIGNAL-GROUP`

#### ClientIds

ClientIds created by [`ConvertTo-PodeSignalConnection`](../../../Functions/Signals/ConvertTo-PodeSignalConnection) will be a GUID by default however, you can supply your own IDs via the `-ClientId` parameter:

```powershell
Add-PodeRoute -Method Get -Path '/response-times' -ScriptBlock {
    $clientId = Get-Random -Minimum 10000 -Maximum 999999
    ConvertTo-PodeSignalConnection -Name 'ResponseTimes' -ClientId $clientId
}
```

You can also [sign clientIds](#signing-clientids) as well.

#### Scopes

The default scope for a new WebSocket connection is "Global", which means the connection will be stored internally and can be used outside of the converting Route to stream messages back to the client.

The default scope for new WebSocket connections can be altered by using [`Set-PodeSignalDefaultScope`](../../../Functions/Signals/Set-PodeSignalDefaultScope). For example, if you wanted all new WebSocket connections to instead default to a Local scope:

```powershell
Set-PodeSignalDefaultScope -Scope Local
```

##### Global

A Globally scoped WebSocket connection is the default (unless altered via [`Set-PodeSignalDefaultScope`](../../../Functions/Signals/Set-PodeSignalDefaultScope)). A Global connection has the following features:

* They are kept open, even after the Route that converted the request has finished.
* The connection is stored internally, so that messages can be streamed to the clients from other Routes, Timers, etc.
* You can send messages to a specific connection if you know the Name and ClientId for the connection.
* Global connections can be closed via [`Close-PodeSignalConnection`](../../../Functions/Signals/Close-PodeSignalConnection).

For example, the following will convert requests to `/response-times` into global WebSocket connections, and then a Schedule will send messages to them every minute:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address * -Port 8091 -Protocol Http
    Add-PodeEndpoint -Address * -Port 8081 -Protocol Ws -NoAutoUpgradeWebSockets

    Add-PodeRoute -Method Get -Path '/response-times' -ScriptBlock {
        ConvertTo-PodeSignalConnection -Name 'ResponseTimes'
    }

    Add-PodeSchedule -Name 'Example' -Cron (New-PodeCron -Every Minute) -ScriptBlock {
        Send-PodeSignal -Name 'ResponseTimes' -Data @{ Durations = @(123, 101, 104) }
    }
}
```

##### Local

A Local connection has the following features:

* When the Route that converted the request has finished, the connection will be closed - the same as HTTP requests.
* The connection is **not** stored internally, it is only available for the lifecycle of the HTTP request.
* You can send messages back to the connection from within the converting Route's scriptblock, but not from Timers, etc. When sending messages back for local connections you'll need to supply the Name of the connection to [`Send-PodeSignal`](../../../Functions/Signals/Send-PodeSignal), this will automatically detect it's a local connection and use the socket via the current `$WebEvent`.

For example, the following will convert requests to `/response-times` into local WebSocket connections, and two messages will be sent back to the client before the connection is closed:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address * -Port 8091 -Protocol Http
    Add-PodeEndpoint -Address * -Port 8081 -Protocol Ws -NoAutoUpgradeWebSockets

    Add-PodeRoute -Method Get -Path '/response-times' -ScriptBlock {
        ConvertTo-PodeSignalConnection -Name 'ResponseTimes' -Scope Local
        Send-PodeSignal -Name 'ResponseTimes' -Data @{ Durations = @(123, 101, 104) }
        Start-Sleep -Seconds 10
        Send-PodeSignal -Name 'ResponseTimes' -Data @{ Durations = @(234, 202, 205) }
    }
}
```

### Send Messages

To send a message from the server to one or more connected clients, you can use [`Send-PodeSignal`](../../../Functions/Signals/Send-PodeSignal). Using the `-Data` parameter, you can either send a raw string value, or a more complex hashtable/psobject which will be auto-converted into a JSON string.

For example, to broadcast a message to all clients on a "ResponseTimes" Signal connection:

```powershell
# simple string
Send-PodeSignal -Name 'ResponseTimes' -Data 'Times: 123, 101, 104'

# complex object
Send-PodeSignal -Name 'ResponseTimes' -Data @{ ResponseTimes = @(123, 101, 104) }
```

Or to send a message to a specific client:

```powershell
Send-PodeSignal -Name 'ResponseTimes' -ClientId 'some-client-id' -Data @{ ResponseTimes = @(123, 101, 104) }
```

!!! note
    For those using the legacy auto-upgrade approach, the `-Name` will be the URI path your WebSocket connected to. For example, if you connected to `ws://localhost:8080/messages` then you'll pass `/messages` to `-Name`.

### Routes

When a client sends a message back to the server on the connected WebSocket, Pode will automatically call [`Send-PodeSignal`](../../Functions/Responses/Send-PodeSignal) to re-broadcast the message back to all clients - or to a specific Path/ClientId if supplied by the sending client.

However, you can add custom routing logic for WebSocket paths using [`Add-PodeSignalRoute`](../../Functions/Routes/Add-PodeSignalRoute). This is much like [`Add-PodeRoute`](../../Functions/Routes/Add-PodeRoute), but allows you to run custom logic on paths for messages sent by clients. When you use a custom Signal Route, it is responsible for calling [`Send-PodeSignal`](../../Functions/Responses/Send-PodeSignal).

Also like [`Add-PodeRoute`](../../Functions/Routes/Add-PodeRoute) there is a `$SignalEvent` object that you can use, which contains the client's message data, the raw Request/Response objects, etc.

For example, the following Signal Route will broadcast the current date back to all clients connected to the `Date` WebSocket, when a client sends the message `[date]` on the `/date` WebSocket path:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address * -Port 8091 -Protocol Http
    Add-PodeEndpoint -Address * -Port 8081 -Protocol Ws -NoAutoUpgradeWebSockets

    Add-PodeRoute -Method Get -Path '/date' -ScriptBlock {
        ConvertTo-PodeSignalConnection -Name 'Date'
    }

    Add-PodeSignalRoute -Path '/date' -ScriptBlock {
        if ($SignalEvent.Data.Message -ieq '[date]') {
            Send-PodeSignal -Name 'Date' -Data ([datetime]::Now.ToString())
        }
    }
}
```

#### Signal Event

When using custom Signal Routes the `$SignalEvent` is a HashTable that is available for you to use - much like the `$WebEvent` object for normal Routes.

This `$SignalEvent` object has the following properties:

| Name      | Type      | Description                                                                                                                  |
| --------- | --------- | ---------------------------------------------------------------------------------------------------------------------------- |
| Data      | hashtable | Contains the Message, and an optional Path/ClientId/Group to broadcast back to                                               |
| Endpoint  | hashtable | Contains the Address/Protocol of the endpoint being hit - such as "pode.example.com"/"127.0.0.2", or WS/WSS for the Protocol |
| Lockable  | hashtable | A synchronized hashtable that can be used with `Lock-PodeObject`                                                             |
| Path      | string    | The path of the WebSocket - such as "/messages"                                                                              |
| Request   | object    | The raw Request object                                                                                                       |
| Response  | object    | The raw Response object                                                                                                      |
| Route     | hashtable | The current Signal Route that is being invoked                                                                               |
| Streamed  | bool      | Specifies whether the current server type uses streams for the Request/Response, or raw strings                              |
| Timestamp | datetime  | The current date and time of the Signal                                                                                      |

### Broadcast Levels

By default, Pode will allow the broadcasting of messages to all clients for a WebSocket connection Name, Group, or a specific ClientId.

You can supply a custom broadcasting level for specific WebSocket connection names (or all), limiting broadcasting to requiring a specific ClientId for example, by using [`Set-PodeSignalBroadcastLevel`](../../../Functions/Signals/Set-PodeSignalBroadcastLevel). If a `-Name` is not supplied then the level type is applied to all WebSocket connections.

For example, the following will only allow messages to be broadcast to a WebSocket connection name if a ClientId is also specified on [`Send-PodeSignal`](../../../Functions/Signals/Send-PodeSignal) - preventing accidentally broadcasting to every connected client:

```powershell
# apply to all WebSocket connections
Set-PodeSignalBroadcastLevel -Type 'ClientId'

# apply to just WebSocket connections with name = ResponseTimes
Set-PodeSignalBroadcastLevel -Name 'ResponseTimes' -Type 'ClientId'
```

The following levels are available:

| Level    | Description                                                        |
| -------- | ------------------------------------------------------------------ |
| Name     | A Name is required. Groups/ClientIds are optional.                 |
| Group    | A Name is required. One of either a Group or ClientId is required. |
| ClientId | A Name and a ClientId are required.                                |

### Signing ClientIds

Similar to Sessions and Cookies, you can sign WebSocket connection ClientIds. This can be done by calling [`Enable-PodeSignalSigning`](../../../Functions/Signals/Enable-PodeSignalSigning) and supplying a `-Secret` to sign the ClientIds.

!!! tip
    You can use the inbuilt [`Get-PodeServerDefaultSecret`](../../../Functions/Core/Get-PodeServerDefaultSecret) function to retrieve an internal Pode server secret which can be used. However, be warned that this secret is regenerated to a random value on every server start/restart.

```powershell
Enable-PodeSignalSigning -Secret 'super-secret'
Enable-PodeSignalSigning -Secret (Get-PodeServerDefaultSecret)
```

When signing is enabled, all clientIds will be signed regardless if they're an internally generated random GUID or supplied via `-ClientId` on [`ConvertTo-PodeSignalConnection`](../../../Functions/Signals/ConvertTo-PodeSignalConnection). A signed clientId will look as follows, and have the structure `s:<clientId>.<signature>`:

```plain
s:5d12f974-7b1a-4524-ab93-6afbf42c4ffa.uvG49LcojTMuJ0l4yzBzr6jCqEV8gGC/0YgsYU1QEuQ=
```

You can also supply the `-Strict` switch to [`Enable-PodeSignalSigning`](../../../Functions/Signals/Enable-PodeSignalSigning), which will extend the secret during signing with the client's IP Address and User Agent.

### Request Headers

If you have a WebSocket connection open for a client, and you want to have the client send AJAX requests to the server but have the responses streamed back over that client's WebSocket connection, then you can identify the WebSocket connection for the client using the following HTTP headers:

* `X-PODE-SIGNAL-CLIENT-ID`
* `X-PODE-SIGNAL-NAME`
* `X-PODE-SIGNAL-GROUP`

At a minimum, you'll need the `X-PODE-SIGNAL-CLIENT-ID` header. If supplied Pode will automatically verify the client ID for you, including if the signing of the client ID is valid - if you're using client ID signing.

When these headers are supplied in a request, Pode will set up the `$WebEvent.Signal` property again - similar to the property set up from [conversion](#convert-request) above:

| Name     | Description                                                           |
| -------- | --------------------------------------------------------------------- |
| Name     | The Name for the connection from X-PODE-SIGNAL-NAME                   |
| Group    | The Group for the connection from X-PODE-SIGNAL-GROUP                 |
| ClientId | The assigned ClientId for the connection from X-PODE-SIGNAL-CLIENT-ID |
| IsLocal  | `$false`                                                              |
| IsGlobal | `$true`                                                               |

!!! note
    If you only supply the Name or Group headers, then the `$WebEvent.Signal` property will not be configured. The ClientId is required as a minimum.

## Client Side

### Receiving Messages

On the client side, you need to use javascript to register a WebSocket and then bind the `onmessage` event to do something when a broadcasted message is received.

To create a WebSocket, you can do something like the following which will bind a WebSocket onto the `/response-times` route:

```javascript
$(document).ready(() => {
    // create the websocket
    var ws = new WebSocket("ws://localhost:8091/response-times");

    // event for inbound messages to append them
    ws.onmessage = function(evt) {
        var data = JSON.parse(evt.data)
        $('#messages').append(`<p>${data.Message}</p>`);
    }
})
```

### Sending Messages

To send a message using the WebSocket, you can use the `.send` function. When you send a message from client-to-server, the data must be a JSON value containing the `message`, and optionally a `path`, `group`, `clientId`, `direct` properties.

For example, if you have a form with input, you can send the message as follows. If you have no Signal Route configured then this will broadcast to every connected client.

```javascript
$('#form').submit(function(e) {
    e.preventDefault();
    ws.send(JSON.stringify({ message: $('#input').val() }));
    $('#input').val('');
})
```

To broadcast the message to just clients connected on a specific path, such as `/receive`:

```javascript
$('#form').submit(function(e) {
    e.preventDefault();
    ws.send(JSON.stringify({ message: $('#input').val(), path: '/receive' }));
    $('#input').val('');
})
```

If you just want the server to on respond directly back to the sending client, and not broadcast to all clients, then set `direct` to true:

```javascript
$('#form').submit(function(e) {
    e.preventDefault();
    ws.send(JSON.stringify({ message: $('#input').val(), direct: true }));
    $('#input').val('');
})
```

## Events

Similar to [Server Events](../../Events) there are also events which you can register scriptblocks for Signal (WebSocket) connections. Currently the following events are supported:

| Event      | Description                                                                                 |
| ---------- | ------------------------------------------------------------------------------------------- |
| Connect    | Triggered when an HTTP request is successfully converted to a Signal (WebSocket) connection |
| Disconnect | Triggered when the signal connection is disconnected, either by the server or client        |

### Register

To register a scriptblock for a Signal connection event you use [`Register-PodeSignalEvent`](../../../Functions/Signals/Register-PodeSignalEvent). You'll need to supply the Name of the Signal connection - from [`ConvertTo-PodeSignalConnection`](../../../Functions/Signals/ConvertTo-PodeSignalConnection), or the URI path if using auto-upgrade - which you're registering the event against, as well as the type of the event, and a name for the event registration - and of course the scriptblock itself.

For example, to register for the Connect event of a Signal connection, to write the Client ID to the CLI, you would do:

```powershell
# register a Connect event
Register-PodeSignalEvent -Name 'Example' -Type Connect -EventName 'OnConnect' -ScriptBlock {
    "Connected: $($TriggeredEvent.Connection.Name) ($($TriggeredEvent.Connection.ClientId))" | Out-Default
}

# a Route to convert the HTTP request to a Signal connection
Add-PodeRoute -Method Get -Path '/signal' -ScriptBlock {
    ConvertTo-PodeSignalConnection -Name 'Example'
}
```

!!! note
    For those using the legacy auto-upgrade approach, the `-Name` supplied to `Register-PodeSignalEvent` will be the URI path your WebSocket connected to. For example, if you connected to `ws://localhost:8080/messages` then you'll pass `/messages` to `-Name`.

#### Event Data

Various metadata about the Signal connection event is supplied to your scriptblock, under the `$TriggeredEvent` variable - including the Connection object, the same one typically found under `$WebEvent.Signal`:

| Property   | Description                                                                           |
| ---------- | ------------------------------------------------------------------------------------- |
| Lockable   | A global lockable value you can use for `Lock-PodeObject`                             |
| Metadata   | Any additional metadata about the event, you can add your own properties here as well |
| Name       | The Name of the Signal connection which triggered the event                           |
| Type       | The type of event triggered - Connect, Disconnect                                     |
| Timestamp  | When the event was triggered, in UTC                                                  |
| Connection | The Connection object itself, containing the connection Name, Group, ClientId, etc.   |

### Unregister

To unregister an previous event registration, simply use [`Unregister-PodeSignalEvent`](../../../Functions/Signals/Unregister-PodeSignalEvent):

```powershell
# to remove the Connect event from above:
Unregister-PodeSignalEvent -Name 'Example' -Type Connect -EventName 'OnConnect'
```

## Full Example

> This full example is a tweaked version of the one found in `/examples/Web-SignalManual.ps1` of the main repository.

If you open this example on multiple browsers, sending messages will be automatically received by all browsers without using async javascript!

The file structure for these files is:

```plain
server.ps1
/views
    index.html
/public
    script.js
```

The following is the Pode server code, that will create one route, which will be for some home page, with a button/input for broadcasting messages.

```powershell
Start-PodeServer {

    # listen
    Add-PodeEndpoint -Address localhost -Port 8091 -Protocol Http
    Add-PodeEndpoint -Address localhost -Port 8091 -Protocol Ws -NoAutoUpgradeWebSockets

    # route for home page view
    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        Write-PodeViewResponse -Path 'websockets'
    }

    # route for websocket upgrade
    Add-PodeRoute -Method Get -Path '/msg' -ScriptBlock {
        ConvertTo-PodeSignalConnection -Name 'Msg'
    }

    # signal route, to return current date or broadcast sent message
    Add-PodeSignalRoute -Path '/msg' -ScriptBlock {
        $msg = $SignalEvent.Data.Message

        if ($msg -ieq '[date]') {
            $msg = [datetime]::Now.ToString()
        }

        Send-PodeSignal -Name 'Msg' -Value @{ message = $msg }
    }
}
```

Next we have the HTML web page with a basic button/input for broadcasting messages. There's also a `<div>` to append received messages:

```html
<html>
    <head>
        <title>WebSockets</title>
        <script src="https://ajax.googleapis.com/ajax/libs/jquery/3.4.1/jquery.min.js"></script>
        <script type="text/javascript" src="/script.js"></script>
    </head>
    <body>
        <p>Clicking submit will broadcast the message to all connected clients</p>
        <form id='bc-form'>
            <input type='text' name='message' placeholder='Enter any random text' />
            <input type='submit' value='Broadcast!' />
        </form>

        <div id='messages'></div>
    </body>
</html>
```

Finally, the following is the client-side javascript to register a WebSocket for the client. It will also invoke the `.send` function of the WebSocket when the button is clicked:

```javascript
$(document).ready(() => {
    // bind submit on the form to send message to the server
    $('#bc-form').submit(function(e) {
        e.preventDefault();

        ws.send(JSON.stringify({
            message: $('input[name=message]').val()
        }));

        $('input[name=message]').val('');
    });

    // create the websocket
    var ws = new WebSocket("ws://localhost:8091/msg");

    // event for inbound messages to append them
    ws.onmessage = function(evt) {
        $('#messages').append(`<p>${evt.data}</p>`);
    }
});
```
