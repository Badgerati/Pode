# Events

Pode lets you register scripts to be run when certain server events are triggered. The following types of events can have scripts registered:

* Start
* Terminate
* Restart
* Browser
* Crash
* Stop

## Overview

You can use [`Register-PodeEvent`](../../Functions/Events/Register-PodeEvent) to register a script that can be run when an event within Pode is triggered. Each event can have multiple scripts registered, and you can unregister a script at any point using [`Unregister-PodeEvent`](../../Functions/Events/Unregister-PodeEvent):

```powershell
# register:
Register-PodeEvent -Type Start -Name '<name>' -ScriptBlock {
    # inform a portal, write a log, etc
}

# unregister:
Unregister-PodeEvent -Type Start -Name '<name>'
```

The scriptblock supplied to `Register-PodeEvent` also supports `$using:` variables. You can retrieve a registered script using [`Get-PodeEvent`](../../Functions/Events/Get-PodeEvent):

```powershell
$evt = Get-PodeEvent -Type Start -Name '<name>'
```

## Types

### Start

Scripts registered to the `Start` event will all be invoked just after the server's main scriptblock has been invoked - ie: the `-ScriptBlock` supplied to [`Start-PodeServer`](../../Functions/Core/Start-PodeServer).

These scripts will also be re-invoked after a server restart has occurred.

### Terminate

Scripts registered to the `Terminate` event will all be invoked just before the server terminates. Ie, when the `Terminating...` message usually appears in the terminal, the script will run just after this and just before the `Done` message.

These script *will not* run when a Restart is triggered.

### Restart

Scripts registered to the `Restart` event will all be invoked whenever an internal server restart occurs. This could be due to file monitoring, auto-restarting, `Ctrl+R`, or [`Restart-PodeServer`](../../Functions/Core/Restart-PodeServer). They will be invoked just after the `Restarting...` message appears in the terminal, and just before the `Done` message.

### Browser

Scripts registered to the `Browser` event will all be invoked whenever the server is told to open a browser, ie: when `Ctrl+B` is pressed.

### Crash

Scripts registered to the `Crash` event will all be invoked if the server ever terminates due to an exception being thrown. If a Crash event it triggered, then Terminate will not be triggered.

### Stop

Scripts registered to the `Stop` event will all be invoked when the server stops and closes. This event will be fired after either the Terminate or Crash events - which ever one causes the server to ultimately stop.
