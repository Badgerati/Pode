# Web Sockets

Pode has support for server-to-client communications using WebSockets, including secure WebSockets.

!!! note
    Currently only broadcasting messages to connected clients/browsers from the server is supported. Client-to-server communications is in the works!

WebSockets allow you to send messages directly from your server to connected clients. This allows you to get real-time continuous updates for the frontend without having to constantly refresh the page, or by using async javascript!

## Server Side

### Listening

On the server side, the only real work required is to register a new endpoint to listen on. To do this you can use the normal [`Add-PodeEndpoint`](../../Functions/Core/Add-PodeEndpoint) function, but with a protocol of either `Ws` or `Wss`:

```powershell
Add-PodeEndpoint -Address * -Port 8091 -Protocol Ws

# or for secure sockets:
Add-PodeEndpoint -Address * -Port 8091 -Certificate './path/cert.pfx' -CertificatePassword 'dummy' -Protocol Wss
```

### Broadcasting

To broadcast a message from the server to all connected clients you can use the [`Send-PodeSignal`](../../Functions/Responses/Send-PodeSignal) function. You can either send raw JSON data, or you can pass a HashTable/PSObject and it will be converted to JSON for you.

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

The following is the Pode server code, that will create two routes.

* The first route will be for some home page, with a button/input for broadcasting messages.
* The second route will be invoked when the button above is clicked. It will then broadcast some message to all clients.

```powershell
Start-PodeServer {

    # listen
    Add-PodeEndpoint -Address * -Port 8090 -Protocol Http
    Add-PodeEndpoint -Address * -Port 8091 -Protocol Ws

    # request for web page
    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        Write-PodeViewResponse -Path 'index'
    }

    # broadcast a received message back out to ever connected client via websockets
    Add-PodeRoute -Method Post -Path '/broadcast' -ScriptBlock {
        param($e)
        Send-PodeSignal -Value @{ Message = $e.Data['message'] }
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

Finally, the following is the client-side javascript to register a WebSocket for the client. It will also invoke the `/broadcast` endpoint when the button is clicked:

```javascript
$(document).ready(() => {
    // bind submit on the form to send message to the server
    $('#bc-form').submit(function(e) {
        e.preventDefault();

        $.ajax({
            url: '/broadcast',
            type: 'post',
            data: $('#bc-form').serialize()
        })

        $('input[name=message]').val('')
    })

    // create the websocket
    var ws = new WebSocket("ws://localhost:8091/");

    // event for inbound messages to append them
    ws.onmessage = function(evt) {
        var data = JSON.parse(evt.data)
        $('#messages').append(`<p>${data.Message}</p>`);
    }
})
```
