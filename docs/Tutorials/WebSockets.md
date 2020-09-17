# Web Sockets

Pode has support for using WebSockets, including secure WebSockets, for either server-to-client or vice-versa.

WebSockets allow you to send messages directly from your server to connected clients. This allows you to get real-time continuous updates for the frontend without having to constantly refresh the page, or by using async javascript!

## Server Side

### Listening

On the server side, the only real work required is to register a new endpoint to listen on. To do this you can use the normal [`Add-PodeEndpoint`](../../Functions/Core/Add-PodeEndpoint), but with a protocol of either `Ws` or `Wss`:

```powershell
Add-PodeEndpoint -Address * -Port 8091 -Protocol Ws

# or for secure sockets:
Add-PodeEndpoint -Address * -Port 8091 -Certificate './path/cert.pfx' -CertificatePassword 'dummy' -Protocol Wss
```

### Broadcasting

To broadcast a message from the server to all connected clients you can use [`Send-PodeSignal`](../../Functions/Responses/Send-PodeSignal). You can either send raw JSON data, or you can pass a HashTable/PSObject and it will be converted to JSON for you.

To broadcast some data to all clients from a POST route, you could use the following. This will get some message from one of the clients, and then broadcast it to every other client:

```powershell
Add-PodeRoute -Method Post -Path '/broadcast' -ScriptBlock {
    param($e)
    Send-PodeSignal -Value @{ Message = $e.Data['message'] }
}
```

Because you can register WebSockets on different paths, you can also broadcast messages to all clients connected using a certain path.

For example, the below would send some response time data to all clients connected and listening for response times on the `/response-times` path:

```powershell
Send-PodeSignal -Value @{ ResponseTimes = @(123, 101, 104) } -Path '/response-times'
```

You can also broadcast messages from Timers, or from Schedules.

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

This will send the message to the server, which will in-turn broadcast to all other clients.

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
    Add-PodeEndpoint -Address * -Port 8090 -Protocol Http
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
