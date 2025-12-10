# Events

Pode lets you register scripts to be run when certain server events are triggered. The following types of events can have scripts registered:

| Event      | Description                                                                                        | Runspaces Open? |
| ---------- | -------------------------------------------------------------------------------------------------- | --------------- |
| Starting   | Triggered during the initialization phase of the server, just after configuration has been loaded. | No              |
| Start      | Triggered just after the server's `-ScriptBlock`  has been invoked.                                | No              |
| Running    | Triggered after all runspaces have been opened and are running.                                    | Yes             |
| Restarting | Triggered just after a server restarted is initiated, but just before clean-up has begun.          | Yes             |
| Restart    | Triggered after the server restarts, after the clean-up has occurred.                              | Yes             |
| Terminate  | Triggered just before the server terminates.                                                       | Yes             |
| Crash      | Triggered if the server terminates due to an unhandled exception being thrown.                     | Unstable        |
| Stop       | Triggered when the server stops - after either a Terminate or Crash.                               | Yes             |
| Suspending | Triggered when the server begins the suspension process.                                           | Yes             |
| Suspend    | Triggered when the server completes the suspension process.                                        | Yes             |
| Resuming   | Triggered when the server begins the resuming process after suspension                             | Yes             |
| Resume     | Triggered when the server resumes operation after suspension.                                      | Yes             |
| Enable     | Triggered when the server is enabled.                                                              | Yes             |
| Disable    | Triggered when the server is disabled.                                                             | No              |
| Browser    | Triggered when the server is told to open in a browser.                                            | Yes             |

And these events are triggered in the following order:

```mermaid
graph TD
    Launch((Launch)) --> Starting(Starting)
    Starting --> Start(Start)
    Start --> Running(Running)
    Running --natural stop --> Terminate(Terminate)
    Running --unhandled exception --> Crash(Crash)
    Running -- internal restart --> Restarting(Restarting)
    Running -- open --> Browser(Browser)
    Running --> Suspending(Suspending) --> Suspend(Suspend)
    Suspend --> Resuming(Resuming) --> Resume([Resume])
    Running --> Disable(Disable) --> Enable([Enable])
    Restarting --> Restart(Restart)
    Restart --> Starting
    Terminate --> Stop(Stop)
    Crash --> Stop
    Stop --> End((End))
```

!!! note
    Resume and Enable both end up back at the "Running" state, but will not trigger the Running event.

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

## Other Events

The events listed above are Server related events, you can find various other events for other functionality listed below:

* [Authentication](../Authentication/Overview#events)
* [Signals](../WebSockets/Endpoints#events)
* [SSE](../Routes/Utilities/SSE#events)
