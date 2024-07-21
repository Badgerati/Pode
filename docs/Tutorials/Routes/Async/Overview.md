
# Async Routes Documentation

## 1. Overview

Pode now supports asynchronous routes, allowing you to handle requests asynchronously. This feature is designed to enhance the responsiveness, scalability, security, and flexibility of your Pode applications. With Async Routes, you can manage multiple requests concurrently, handle complex tasks efficiently, and ensure secure operations.

### Benefits:
- **Improved Responsiveness**: Handle multiple requests concurrently, reducing response times and improving overall system responsiveness.
- **Scalability**: Efficiently manage resources and scale your application to handle increased loads or complex tasks by creating independent runspace pools.
- **Enhanced Security**: Ensure that only authorized users have access to sensitive information and operations with integrated Pode security features.
- **Flexible Task Management**: Easily create, stop, query, or callback on running tasks using a unified interface for managing asynchronous tasks.


## 2. Usage

### Creating an Async Route

The `Set-PodeAsyncRoute` function enables you to define routes in Pode that execute asynchronously, leveraging runspace management for non-blocking operation. This function allows you to specify response types (JSON, XML, YAML) and manage asynchronous task parameters such as timeout and unique ID generation. It supports the use of arguments, `$using` variables, and state variables.

#### How It Works

Creating an async route in Pode is almost like creating a standard route with a few key differences:
1. `Set-PodeAsyncRoute` has to process the output of `Add-PodeRoute`.
2. The route's script block cannot use any response functions like `Write-PodeJsonResponse`.
3. The route's script block must return the result, if any.

### Example 1: Using ArgumentList

```powershell
Add-PodeRoute -PassThru -Method Put -Path '/asyncParam' -ScriptBlock {
    param($sleepTime2, $Message)
    Write-PodeHost "sleepTime2=$sleepTime2"
    Write-PodeHost "Message=$Message"
    for ($i = 0; $i -lt 20; $i++) {
        Start-Sleep $sleepTime2
    }
    return @{ InnerValue = $Message }
} -ArgumentList @{sleepTime2 = 2; Message = 'coming as argument' } | Set-PodeAsyncRoute -ResponseContentType 'application/json', 'application/xml'
```

### Example 2: Using `$using` Variables

```powershell
$uSleepTime = 5
$uMessage = 'coming from using'

Add-PodeRoute -PassThru -Method Put -Path '/asyncUsing' -ScriptBlock {
    Write-PodeHost "sleepTime=$($using:uSleepTime)"
    Write-PodeHost "Message=$($using:uMessage)"
    Start-Sleep $using:uSleepTime
    return @{ InnerValue = $using:uMessage }
} | Set-PodeAsyncRoute -ResponseContentType 'application/json', 'application/yaml'
```

### Example 3: Using `$state` Variables

```powershell
Set-PodeState -Name 'data' -Value @{
    sleepTime = 5
    Message   = 'coming from a PodeState'
}

Add-PodeRoute -PassThru -Method Put -Path '/asyncState' -ScriptBlock {
    Write-PodeHost "state:sleepTime=$($state:data.sleepTime)"
    Write-PodeHost "state:MessageTest=$($state:data.Message)"
    Start-Sleep $state:data.sleepTime
    return @{ InnerValue = $state:data.Message }
} | Set-PodeAsyncRoute -ResponseContentType 'application/json', 'application/yaml'
```

### Route Response

When a route is invoked, it automatically creates a runspace to execute the scriptblock associated with the route. It then returns an `AsyncTask` object that includes information related to the task just sent for execution.

#### `AsyncTask` Object Definition

- **User** - The async operation owner.

- **CompletedTime** - The async operation completion time.

- **State*** - The async operation status.
  - Possible values: `NotStarted`, `Running`, `Failed`, `Completed`

- **CallbackInfo** - The Callback operation result.
  - **State** - Operation status.
    - Possible values: `NotStarted`, `Running`, `Failed`, `Completed`
  - **Tentative** - Number of tentatives.
  - **Url** - The callback URL.

- **StartingTime** - The async operation starting time.

- **Cancelable*** - The async operation can be forcefully terminated.

- **CreationTime*** - The async operation creation time.

- **Id*** - The async operation unique identifier.

- **Permission** - The permission governing the async operation.
  - **Write** - Write permission
    - **Users**
    - **Groups**
    - **Roles**
    - **Scopes**
  - **Read** - Read permission
    - **Users**
    - **Groups**
    - **Roles**
    - **Scopes**

- **Error** - The error message, if any.

- **CallbackSettings** - Callback Configuration.
  - **UrlField**
  - **Method** - HTTP Method.
    - Possible values: `Post`, `Put`
  - **SendResult** - Send the result.

- **Result** - The result of the async operation.

- **Name*** - The async operation name.

- **Progress** - Represents the task activity progress.

**Note**: Properties marked with `*` are always available.

## Features

- **Timeout**: By default, a timeout of 600 minutes (10 hours) is set for asynchronous tasks, but this can be customized to suit your needs. To remove any timeout, set the value to -1.

- **Response Types**: You can specify multiple response types for the route. Valid values include `application/json`, `application/xml`, and `application/yaml`. The default is `application/json`.

- **Runspace Management**: Each async route creates an independent runspace pool that is configurable with a minimum and maximum number of simultaneous runspaces, allowing for efficient resource management and scalability.
  - **MaxRunspaces**: The maximum number of Runspaces that can exist in this route. The default is 2.
  - **MinRunspaces**: The minimum number of Runspaces that exist in this route. The default is 1.

- **Callbacks**: Supports including callback functionality for routes. You can specify the callback URL, content type, HTTP method, and header fields. Callbacks can also send the result of the asynchronous operation.
  - **Callback URL**: You can define the URL to which the callback should be sent. The default is `'$request.body#/callbackUrl'`.
  - **Callback Content Type**: Specify the content type of the callback. The default is `'application/json'`.
  - **Callback Method**: Define the HTTP method for the callback. The default is `'Post'`.
  - **Callback Header Fields**: Include custom header fields for the callback in the form of a hashtable.

- **Security**: All async route operations are subject to Pode security, ensuring that any task operation complies with defined authentication and authorization rules.
  - **Permissions**: You can specify read and write permissions for each route. This can include specific users, groups, roles, and scopes.
  - **Read Access**: Define which users, groups, roles, and scopes have read access.
  - **Write Access**: Define which users, groups, roles, and scopes have write access.

- **Server-Sent Events (SSE)**: Enables real-time updates and seamless async communication through SSE support.
  - **Enable SSE**: You can enable SSE for async routes to provide real-time updates.
  - **SSE Group**: Optionally group SSE connections to broadcast events to all connections in a specified group.

- **NotCancelable**: If specified, the async operation cannot be forcefully terminated. This ensures that critical tasks are not interrupted.

- **AsyncIdGenerator**: Specifies the function to generate unique IDs for asynchronous tasks. The default is `New-PodeGuid`.

- **Automatic OpenAPI Definition**: Routes defined with `Set-PodeAsyncRoute` can automatically generate OpenAPI documentation. This includes response types and callback details, making it easier to document and share your API.

## Utility Functions for Managing Async Tasks

### Add-PodeAsyncGetRoute

The `Add-PodeAsyncGetRoute` function creates a route in Pode that allows retrieving the status and details of an asynchronous task. This function supports different methods for task ID retrieval (Cookie, Header, Path, Query) and various response types (JSON, XML, YAML). It integrates with OpenAPI documentation, providing detailed route information and response schemas.

Unless the `-NoOpenAPI` switch is used, the OpenAPI section will be automatically created.

The task ID name can be changed using the `TaskIdName` parameter. The default name is `taskId`.

This function accepts almost any parameter applicable to a standard Pode Route.

#### Example

```powershell
Add-PodeRoute -PassThru -Method Put -Path '/asyncWait' -ScriptBlock {
    Start-Sleep 20
} | Set-PodeAsyncRoute -ResponseContentType 'application/json', 'application/yaml' -Timeout 300

Add-PodeAsyncGetRoute -Path '/task' -ResponseContentType 'application/json', 'application/yaml' -In Path
```

#### Usage as a User

```powershell
$response_asyncWait = Invoke-RestMethod -Uri 'http://localhost:8080/asyncWait' -Method Put

Invoke-RestMethod -Uri "http://localhost:8080/task?taskId=$($response_asyncWait.Id)" -Method Get
```
### Add-PodeAsyncStopRoute

The `Add-PodeAsyncStopRoute` function creates a route in Pode that allows stopping an asynchronous task. This function supports different methods for task ID retrieval (Cookie, Header, Path, Query) and various response types (JSON, XML, YAML). It integrates with OpenAPI documentation, providing detailed route information and response schemas.

Unless the `-NoOpenAPI` switch is used, the OpenAPI section will be automatically created.

The task ID can be passed as a cookie, header, path, or query, and the name itself can be changed using the `TaskIdName` parameter. The default name is `taskId`.

This function accepts almost any parameter applicable to a standard Pode Route.

Stopping an asynchronous task sets its state to 'Aborted' and disposes of the associated runspace.

#### Example

```powershell
Add-PodeRoute -PassThru -Method Put -Path '/asyncWait' -ScriptBlock {
    Start-Sleep 20
} | Set-PodeAsyncRoute -ResponseContentType 'application/json', 'application/yaml' -Timeout 300

Add-PodeAsyncStopRoute -Path '/task' -ResponseContentType 'application/json', 'application/yaml' -In Path
```

#### Usage as a User

```powershell
$response_asyncWait = Invoke-RestMethod -Uri 'http://localhost:8080/asyncWait' -Method Put

Invoke-RestMethod -Uri "http://localhost:8080/task?taskId=$($response_asyncWait.Id)" -Method Delete
```


### Add-PodeAsyncQueryRoute

The `Add-PodeAsyncQueryRoute` function creates a route in Pode for querying task information based on specified parameters. This function supports multiple content types for both requests and responses, and can generate OpenAPI documentation.

Unless the `-NoOpenAPI` switch is used, the OpenAPI section will be automatically created.

This function accepts almost any parameter applicable to a standard Pode Route.

#### Properties for Query

The following properties can be used for the query:
- `Id`
- `Name`
- `Runspace`
- `Output`
- `StartingTime`
- `CreationTime`
- `CompletedTime`
- `ExpireTime`
- `State`
- `Error`
- `CallbackSettings`
- `Cancelable`
- `EnableSse`
- `SseGroup`
- `Timeout`
- `User`
- `Url`
- `Method`
- `Progress`

#### Valid Operators

The following operators are valid for use in queries:
- `GT` (Greater Than)
- `LT` (Less Than)
- `GE` (Greater Than or Equal To)
- `LE` (Less Than or Equal To)
- `EQ` (Equal To)
- `NE` (Not Equal To)
- `LIKE`
- `NOTLIKE`

All conditions in the query are joined together by a logical AND.

Users can only query objects they are entitled to read.

#### Example

```powershell
Add-PodeRoute -PassThru -Method Put -Path '/asyncWait' -ScriptBlock {
    Start-Sleep 20
} | Set-PodeAsyncRoute -ResponseContentType 'application/json', 'application/yaml' -Timeout 300

Add-PodeAsyncQueryRoute -Path '/tasks/query' -ResponseContentType 'application/json', 'application/yaml' -In Body
```

#### Usage as a User

##### Example PowerShell Usage

```powershell
$response_asyncWait = Invoke-RestMethod -Uri 'http://localhost:8080/asyncWait' -Method Put

$queryBody = @{
    Id = @{
        value = $response_asyncWait.Id
        op = "EQ"
    }
    State = @{
        value = "Completed"
        op = "EQ"
    }
    CreationTime = @{
        value = "7/5/2024 1:20:00 PM"
        op = "LE"
    }
    StartingTime = @{
        value = "7/5/2024 1:20:00 PM"
        op = "GT"
    }
    Name = @{
        value = "Get"
        op = "LIKE"
    }
    Cancelable = @{
        value = $true
        op = "EQ"
    }
}

Invoke-RestMethod -Uri "http://localhost:8080/tasks/query" -Method Post -Body ($queryBody | ConvertTo-Json) -ContentType "application/json"
```

### Get-PodeQueryAsyncRouteOperation

Acts as a public interface for searching asynchronous Pode route operations based on specified query conditions.

### Get-PodeAsyncRouteOperation

Fetches details of an asynchronous Pode route operation by its ID.

### Stop-PodeAsyncRouteOperation

Aborts a specific asynchronous Pode route operation by its ID, setting its state to 'Aborted' and disposing of the associated runspace.

### Test-PodeAsyncRouteOperation

Checks if a specific asynchronous Pode route operation exists by its ID, returning a boolean value.

### Set-PodeAsyncProgress

Manages the progress of an asynchronous task within Pode routes.

### Get-PodeAsyncProgress

Retrieves the current progress of an asynchronous route in Pode.
