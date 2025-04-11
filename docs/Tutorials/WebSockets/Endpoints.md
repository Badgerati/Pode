# Endpoints

Pode has support for creating WebSocket endpoints, for server-to-client and/or client-to-server communications. WebSockets allow you to broadcast messages directly from your server to connected clients. This allows you to get real-time continuous updates on the frontend without having to constantly refresh the page, or by using async javascript.

!!! note
    The maximum size for WebSocket payloads in Pode is **32KB**. If a message exceeds this size, the connection may be closed or the message may not be delivered correctly.

## Server Side

### Listening

On the server side, the first thing to do is register a new endpoint to listen on. To do this you can use [`Add-PodeEndpoint`](../../Functions/Core/Add-PodeEndpoint) with a protocol of either `Ws` or `Wss`:

```powershell
Add-PodeEndpoint -Address * -Port 8091 -Protocol Ws

# or for secure sockets:
Add-PodeEndpoint -Address * -Port 8091 -Certificate './path/cert.pfx' -CertificatePassword 'dummy' -Protocol Wss
```

### Broadcasting

To broadcast a message from the server to all connected clients you can use [`Send-PodeSignal`](../../Functions/Responses/Send-PodeSignal). You can either send raw JSON data, or you can pass a HashTable/PSObject and it will be converted to JSON for you.

To broadcast some data to all clients from a POST route, you could use the following. This will get some message from one of the clients, and then broadcast it back to every client:

```powershell
Add-PodeRoute -Method Post -Path '/broadcast' -ScriptBlock {
    Send-PodeSignal -Value @{ Message = $WebEvent.Data['message'] }
}
```

Because you can register WebSockets on different paths, you can also broadcast messages to all clients connected using a certain path.

For example, the below would send some response time data to all clients connected and listening for response times on the `/response-times` path:

```powershell
Send-PodeSignal -Value @{ ResponseTimes = @(123, 101, 104) } -Path '/response-times'
```

You can also broadcast messages from Timers, or from Schedules.

### Routes

When a client sends a message back to the server on the connected WebSocket, Pode will automatically call [`Send-PodeSignal`](../../Functions/Responses/Send-PodeSignal) to re-broadcast the message back to all clients - or to a specific Path/ClientId if supplied by the sending client.

However, you can add custom route logic for WebSocket paths using [`Add-PodeSignalRoute`](../../Functions/Routes/Add-PodeSignalRoute). This is much like [`Add-PodeRoute`](../../Functions/Routes/Add-PodeRoute), but allows you to run custom logic on paths for messages sent by clients. When you use a custom route, that route is responsible for calling [`Send-PodeSignal`](../../Functions/Responses/Send-PodeSignal).

Also like [`Add-PodeRoute`](../../Functions/Routes/Add-PodeRoute) there is a `$SignalEvent` object that you can use, which contains the client's message data, the raw Request/Response objects, etc.

For example, the following signal route will broadcast the current date back to all clients, if the main client sends the message `[date]` on the `/messages` path:

```powershell
Add-PodeSignalRoute -Path '/messages' -ScriptBlock {
    $msg = $SignalEvent.Data.Message

    if ($msg -ieq '[date]') {
        $msg = [datetime]::Now.ToString()
    }

    Send-PodeSignal -Value $msg
}
```

### Signal Event

When using custom signal routes, the `$SignalEvent` is a HashTable that is available for you to use - much like the `$WebEvent` object for normal routes.

This `$SignalEvent` object has the following properties:

| Name | Type | Description |
| ---- | ---- | ----------- |
| Data | hashtable | Contains the Message, an optional Path to broadcast back onto, and an optional ClientId to only broadcast back to |
| Endpoint | hashtable | Contains the Address and Protocol of the endpoint being hit - such as "pode.example.com" or "127.0.0.2", or WS or WSS for the Protocol |
| Lockable | hashtable | A synchronized hashtable that can be used with `Lock-PodeObject` |
| Path | string | The path of the WebSocket - such as "/messages" |
| Request | object | The raw Request object |
| Response | object | The raw Response object |
| Route | hashtable | The current Signal Route that is being invoked |
| Streamed | bool | Specifies whether the current server type uses streams for the Request/Response, or raw strings |
| Timestamp | datetime | The current date and time of the Signal |

## Client Side

### Receiving

On the client side, you need to use javascript to register a WebSocket and then bind the `onmessage` event to do something when a broadcasted message is received.

To create a WebSocket, you can do something like the following which will bind a WebSocket onto the root path '/':

```javascript
$(document).ready(() => {
    // create the websocket
    var ws = new WebSocket("ws://localhost:8091/");

    // event for inbound messages to append them
    ws.onmessage = function(evt) {
        var data = JSON.parse(evt.data)
        $('#messages').append(`<p>${data.Message}</p>`);
    }
})
```

### Sending

To send a message using the WebSocket, you can use the `.send` function. When you send a message from client-to-server, the data must be a JSON value containing the `message`, `path`, and `clientId`. Only the `message` is mandatory.

For example, if you have a form with input, you can send the message as follows:

```javascript
$('#form').submit(function(e) {
    e.preventDefault();
    ws.send(JSON.stringify({ message: $('#input').val() }));
    $('#input').val('');
})
```

This will send the message to the server, which will in-turn broadcast it to all other clients. To broadcast the message to just clients connected on a specific path, such as `/receive`:

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

## Full Example

> This full example is a cut-down version of the one found in `/examples/web-signal.ps1` of the main repository.

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
    Add-PodeEndpoint -Address * -Port 8091 -Protocol Http
    Add-PodeEndpoint -Address * -Port 8091 -Protocol Ws

    # request for web page
    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        Write-PodeViewResponse -Path 'index'
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
    var ws = new WebSocket("ws://localhost:8091/");

    // event for inbound messages to append them
    ws.onmessage = function(evt) {
        $('#messages').append(`<p>${evt.data}</p>`);
    }
});
```
