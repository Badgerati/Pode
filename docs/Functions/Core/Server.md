# Server

## Description

The `server` function is the most important function throughout all of Pode, as it's the only function that is mandatory in your scripts. The scriptblock you supply to the `server` is where you place all of your main server logic - routes, timers, middleware, etc.

!!! warning
    You can only have one `server` declared within your script

## Examples

### Example 1

The following example will run the scriptblock once, printing out `Hello, world!`, and then exit:

```powershell
Start-PodeServer {
    Write-Host 'Hello, world!'
}
```

### Example 2

The following will start a server that repeats the scriptblock every 5 seconds:

```powershell
Start-PodeServer -Interval 5 {
    Write-Host 'Hey!'
}
```

### Example 3

The following server will accept web requests, and handle them across 2 threads rather than 1:

```powershell
Start-PodeServer -Thread 2 {
    Add-PodeEndpoint -Endpoint localhost:8080 -Protocol HTTP
}
```

### Example 4

The following server will start-up in a serverless context - such as Lambda or Functions. When running in this context you need to supply the request data passed to your serverless script:

```powershell
Start-PodeServer -Request $TriggerMetaData -Type 'azure-functions' {
    # route logic
}
```

## Parameters

| Name | Type | Required | Description | Default |
| ---- | ---- | -------- | ----------- | ------- |
| ScriptBlock | scriptblock | true | The main closure that contains the core server logic | null |
| Interval | int | false | Specifies, in seconds, the time to sleep before looping the ScriptBlock logic | 0 |
| Threads | int | false | Specifies the number of runspaces used to handle incoming requests | 1 |
| RootPath | string | false | Specifies a custom root path for the server (can be literal or relative to the invocation path) | null |
| Request | object | false | This is the request data that is required for running in serverless, such as the `$TriggerMetaData` from Azure Functions, or the `$LambdaInput` from AWS Lambda | null |
| Type | string | false | The type of server to run, leave empty for normal functionality. (Values: Azure-Functions, Aws-Lambda) | empty |
| DisableTermination | switch | false | Toggles the ability to allow using `Ctrl+C` to terminate the server | false |
| DisableLogging | switch | false | Toggles any logging that has been setup. When `true` all logging is disabled | false |
| FileMonitor | switch | false | When passed, any file changes will cause the server to restart | false |
| Browse | switch | false | When passed, and running as a web server, on server start Pode will open the first endpoint in your browser | false |
