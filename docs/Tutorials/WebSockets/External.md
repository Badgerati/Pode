# External

!!! Note
    This is still in the early stages, so if you find any issues or have any suggestion, please feel free to raise it over on [GitHub](https://github.com/Badgerati/Pode/issues)!

Pode has support to connect to external WebSocket servers, and has the ability to receive and send messages to/from them. This is useful if you want to connect to external metrics servers to update dashboards; send messages to external WebSockets; or even create a bot.

## Connecting

You can connect to an external WebSocket either in the main [`Start-PodeServer`](../../../Functions/Core/Start-PodeServer) script, or adhoc in Routes, Timers, etc. If you opt to connect adhoc, then you'll need to pass `WebSockets` to `-EnablePool`:

```powershell
Start-PodeServer -EnablePool WebSockets {
    # ...
}
```

The function to use to connect to external WebSockets is [`Connect-PodeWebSocket`](../../../Functions/WebSockets/Connect-PodeWebSocket), this expects a `-Name`, `-Url`, and a `-ScriptBlock`. The scriptblock is what will be invoked when a message is received from the WebSocket server.

!!! important
    The `-Url` should begin with either `ws://` or `wss://`

For example, if you have a WebSocket server running at `ws://localhost:8091` (like the [web-signal.ps1](https://github.com/Badgerati/Pode/blob/develop/examples/web-signal.ps1) example) then you can connect to it like below:

```powershell
Connect-PodeWebSocket -Name 'Example' -Url 'ws://localhost:8091' -ScriptBlock {
    $WsEvent.Request | Out-Default
}
```

This will simply output the message received from the WebSocket to the terminal. You'll notice the `$WsEvent` variable; this works like `$WebEvent` and others, and will contain details about the current event - mostly just the Request object and the Data received. By default the data received will be parsed from JSON, but you can customise this using the `-ContentType` parameter on [`Connect-PodeWebSocket`](../../../Functions/WebSockets/Connect-PodeWebSocket).

### Pre-Call

Sometimes you might need to make a call to a REST API first to retrieve the WebSocket URL to connect. The best way to achieve this is to just make an `Invoke-RestMethod` call first, then pass the URL into [`Connect-PodeWebSocket`](../../../Functions/WebSockets/Connect-PodeWebSocket):

```powershell
$response = Invoke-RestMethod -Url 'https://example.com/websocket/get_url'

Connect-PodeWebSocket -Name 'Example' -Url $response.url -ScriptBlock {
    $WsEvent.Request | Out-Default
}
```

### Disconnect

When you're done with a WebSocket, you can optionally call [`Disconnect-PodeWebSocket`](../../../Functions/WebSockets/Disconnect-PodeWebSocket) to close the connection. This can be called from within the scriptblock of [`Connect-PodeWebSocket`](../../../Functions/WebSockets/Connect-PodeWebSocket), or by passing the `-Name` of the WebSocket to close directly.

### Reconnect

If at any point you need to reset a WebSocket connection, because the connection has/will expire and you have a new URL, then you can call [`Reset-PodeWebSocket`](../../../Functions/WebSockets/Reset-PodeWebSocket). If called without `-Url` then it will attempt to reconnect using the existing connection details, or it will attempt to reconnect but use the new URL instead.

An example of this could be how Slack's Real Time Messaging works, where a new URL to connect to will be sent as a WebSocket message. You'll need to called [`Reset-PodeWebSocket`](../../../Functions/WebSockets/Reset-PodeWebSocket) using this new URL for the Slack connection to continue.

Or, you might have to reset an existing connection on the same details because the connection dropped.

## Send Message

You can also send messages back to a connected WebSocket by using [`Send-PodeWebSocket`](../../../Functions/WebSockets/Send-PodeWebSocket). This will need the `-Name` of the WebSocket to send the message, and naturally the `-Message` itself.

For example, using the connect example above, we can extend this to send back a response instead of outputting to the terminal:

```powershell
Connect-PodeWebSocket -Name 'Example' -Url 'ws://localhost:8091' -ScriptBlock {
    Send-PodeWebSocket -Message @{ message = $WsEvent.Request.Body }
}
```

If the `-Message` is a hashtable or a psobject then Pode will auto-convert these to JSON (unless a different `-ContentType` was supplied on [`Connect-PodeWebSocket`](../../../Functions/WebSockets/Connect-PodeWebSocket)). Or, you can supply a raw string message that will be used instead, with no auto-conversion.

!!! tip
    In the scope of [`Connect-PodeWebSocket`](../../../Functions/WebSockets/Connect-PodeWebSocket) you don't need to supply the `-Name` on [`Send-PodeWebSocket`](../../../Functions/WebSockets/Send-PodeWebSocket).

## WebSocket Event

When connecting to external WebSocket servers, the `$WsEvent` is a HashTable that is available for you to use - much like the `$WebEvent` object for normal routes.

This `$WsEvent` object has the following properties:

| Name | Type | Description |
| ---- | ---- | ----------- |
| Data | hashtable | Contains the message data received from the WebSocket |
| Lockable | hashtable | A synchronized hashtable that can be used with `Lock-PodeObject` |
| Request | object | The raw Request object |
| Timestamp | datetime | The current date and time of the received data |
