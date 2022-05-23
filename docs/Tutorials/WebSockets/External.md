# External

Pode has support to connect to external WebSocket servers, and be able to receive messages from then as well as send messages to them as well. This is useful if you want to connect to external metrics servers to update dashboards; send messages to external WebSockets; or even create a bot.

## Connecting

You can connect to an external WebSocket either in the main [`Start-PodeServer`] script, or adhoc in Routes, Timers, etc. If you opt to connect adhoc, then you'll need to pass `WebSockets` to `-EnablePool`:

```powershell
Start-PodeServer -EnablePool WebSockets {
    # ...
}
```

The function to use to connect to external WebSockets is [`Connect-PodeWebSocket`], this expects a `-Name`; `-Url`, and a `-ScriptBlock`. The scriptblock is what will be invoked when a message is recieved from the WebSocket server.

!!! important
    The `-Url` should begin with either `ws://` or `wss://`

For example, if you have a WebSocket server running at `ws://localhost:8091` (like the [web-signal.ps1](https://github.com/Badgerati/Pode/blob/develop/examples/web-signal.ps1) example) then you can connect to it like below:

```powershell
Connect-PodeWebSocket -Name 'Example' -Url 'ws://localhost:8091' -ScriptBlock {
    $WsEvent.Request | Out-Default
}
```

This will simply output the message recieved from the WebSocket to the terminal. You'll notice the `$WsEvent` variable; this works like `$WebEvent` and others, and will contain details about the current event - mostly just the Request object with available Body.

When you're done with a WebSocket, you can optionally call [`Disconnect-PodeWebSocket`]. Or if at any point you need to reset a WebSocket connection, because the connection has/will expire then you can call [`Reset-PodeWebSocket`] - optionally with a new `-Url`.

## Send Message

You can also send messages back to a connected WebSocket by using [`Send-PodeWebSocket`]. This will need the `-Name` of the WebSocket to send the message, and naturally the `-Message` itself.

For example, using the connect example above, we can extend this to send back a response instead of outputting to the terminal:

```powershell
Connect-PodeWebSocket -Name 'Example' -Url 'ws://localhost:8091' -ScriptBlock {
    Send-PodeWebSocket -Message (@{ message = $WsEvent.Request.Body } | ConvertTo-Json -Compress)
}
```

!!! tip
    In the scope of `Connect-PodeWebSocket` you don't need to supply the `-Name` on `Send-PodeWebSocket`.