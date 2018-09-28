# Server

## Description

The `Server` function is the most important function throughout all of Pode, as it's the only function that is mandatory in your scripts. Within the scriptblock supplied to the `Server` is where you place all of your main server logic - routes, timers, middleware, etc.

!!! warning
    You can only have one `Server` declared within your script

## Examples

### Example 1

The following example will run the scriptblock once, printing out `Hello, world!`, and then exit:

```powershell
Server {
    Write-Host 'Hello, world!'
}
```

### Example 2

The following will start a server that repeats the scriptblock every 5 seconds:

```powershell
Server -Interval 5 {
    Write-Host 'Hey!'
}
```

### Example 3

The following server will accept web requests, and handle them across 2 threads rather than 1:

```powershell
Server -Thread 2 {
    # route logic
}
```

### Example 4

The following server will restart when it detects a file has been changed. Ie, if you start the server and then alter a web page, or change a dot-sourced script, then the server will restart:

```powershell
Server -FileMonitor {
    # route logic
}
```

## Parameters

| Name | Type | Required | Description | Default |
| ---- | ---- | -------- | ----------- | ------- |
| ScriptBlock | scriptblock | true | The main closure that contains the core server logic | null |
| Interval | int | false | Specifies, in seconds, the time to sleep before looping the ScriptBlock logic | 0 |
| Threads | int | false | Specifies the number of runspaces used to handle incoming requests | 1 |
| DisableTermination | switch | false | Toggles the ability to allow using `Ctrl+C` to terminate the server | false |
| DisableLogging | switch | false | Toggles any logging that has been setup. When `true` all logging is disabled | false |
| FileMonitor | switch | false | When passed, any file changes will cause the server to restart | false |
