
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

| Name                            | Type    | Description                                                                                 |
|---------------------------------|---------|---------------------------------------------------------------------------------------------|
| **User**                        | string  | The async operation owner.                                                                  |
| **CompletedTime**               | date    | The async operation completion time.                                                        |
| **State***                      | string  | The async operation status. Possible values: `NotStarted`, `Running`, `Failed`, `Completed` |
| **CallbackInfo**                | object  | The Callback operation result.                                                              |
| **CallbackInfo.State**          | string  | Operation status. Possible values: `NotStarted`, `Running`, `Failed`, `Completed`           |
| **CallbackInfo.Tentative**      | integer | Number of tentatives.                                                                       |
| **CallbackInfo.Url**            | string  | The callback URL.                                                                           |
| **StartingTime**                | date    | The async operation starting time.                                                          |
| **Cancellable***                | boolean | The async operation can be forcefully terminated.                                           |
| **CreationTime***               | string  | The async operation creation time.                                                          |
| **Id***                         | string  | The async operation unique identifier.                                                      |
| **Permission**                  | object  | The permission governing the async operation.                                               |
| **Permission.Write**            | object  | Write permission.                                                                           |
| **Permission.Write.Users**      | array   | Users with write permission.                                                                |
| **Permission.Write.Groups**     | array   | Groups with write permission.                                                               |
| **Permission.Write.Roles**      | array   | Roles with write permission.                                                                |
| **Permission.Write.Scopes**     | array   | Scopes with write permission.                                                               |
| **Permission.Read**             | object  | Read permission.                                                                            |
| **Permission.Read.Users**       | array   | Users with read permission.                                                                 |
| **Permission.Read.Groups**      | array   | Groups with read permission.                                                                |
| **Permission.Read.Roles**       | array   | Roles with read permission.                                                                 |
| **Permission.Read.Scopes**      | array   | Scopes with read permission.                                                                |
| **Error**                       | string  | The error message, if any.                                                                  |
| **CallbackSettings**            | object  | Callback Configuration.                                                                     |
| **CallbackSettings.UrlField**   | string  | The URL Field.                                                                              |
| **CallbackSettings.Method**     | string  | HTTP Method. Possible values: `Post`, `Put`                                                 |
| **CallbackSettings.SendResult** | boolean | Send the result.                                                                            |
| **Result**                      | string  | The result of the async operation.                                                          |
| **Name***                       | string  | The async operation name.                                                                   |
| **Progress**                    | number  | Represents the task activity progress.                                                      |

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

- **NotCancellable**: If specified, the async operation cannot be forcefully terminated. This ensures that critical tasks are not interrupted.

- **IdGenerator**: A custom ScriptBlock to generate a random unique IDs for asynchronous tasks. The default is `{ return (New-PodeGuid) }`.

- **Automatic OpenAPI Definition**: Routes defined with `Set-PodeAsyncRoute` can automatically generate OpenAPI documentation. This includes response types and callback details, making it easier to document and share your API.

## Functions for Managing Async Route Tasks

### Add-PodeAsyncRouteGet

The `Add-PodeAsyncRouteGet` function creates a route in Pode that allows retrieving the status and details of an asynchronous task. This function supports different methods for task ID retrieval (Cookie, Header, Path, Query) and various response types (JSON, XML, YAML). It integrates with OpenAPI documentation, providing detailed route information and response schemas.

The task ID name can be changed using the `TaskIdName` parameter. The default name is `taskId`.

This function accepts almost any parameter applicable to a standard Pode Route.

#### Example

```powershell
Add-PodeRoute -PassThru -Method Put -Path '/asyncWait' -ScriptBlock {
    Start-Sleep 20
} | Set-PodeAsyncRoute -ResponseContentType 'application/json', 'application/yaml' -Timeout 300

Add-PodeAsyncRouteGet -Path '/task' -ResponseContentType 'application/json', 'application/yaml' -In Path |
Set-PodeOARouteInfo -Summary 'Query an Async Route Task'  # Set-PodeOARouteInfo is required to get the OpenApi documentation
```

#### Usage as a User

```powershell
$response_asyncWait = Invoke-RestMethod -Uri 'http://localhost:8080/asyncWait' -Method Put

Invoke-RestMethod -Uri "http://localhost:8080/task?taskId=$($response_asyncWait.Id)" -Method Get
```
### Add-PodeAsyncRouteStop

The `Add-PodeAsyncRouteStop` function creates a route in Pode that allows stopping an asynchronous task. This function supports different methods for task ID retrieval (Cookie, Header, Path, Query) and various response types (JSON, XML, YAML). It integrates with OpenAPI documentation, providing detailed route information and response schemas.

The task ID can be passed as a cookie, header, path, or query, and the name itself can be changed using `Set-PodeAsyncRouteOASchemaName` and the `TaskIdName` parameter. The default name is `id`.

This function accepts almost any parameter applicable to a standard Pode Route.

Stopping an asynchronous task sets its state to 'Aborted' and disposes of the associated runspace.

#### Example

```powershell
Add-PodeRoute -PassThru -Method Put -Path '/asyncWait' -ScriptBlock {
    Start-Sleep 20
} | Set-PodeAsyncRoute -ResponseContentType 'application/json', 'application/yaml' -Timeout 300

Add-PodeAsyncRouteStop -Path '/task' -ResponseContentType 'application/json', 'application/yaml' -In Path -PassThru |
Set-PodeOARouteInfo -Summary 'Stop an Async Route Task'  # Set-PodeOARouteInfo is required to get the OpenApi documentation
```

#### Usage as a User

```powershell
$response_asyncWait = Invoke-RestMethod -Uri 'http://localhost:8080/asyncWait' -Method Put

Invoke-RestMethod -Uri "http://localhost:8080/task?taskId=$($response_asyncWait.Id)" -Method Delete
```


### Add-PodeAsyncRouteQuery

The `Add-PodeAsyncRouteQuery` function creates a route in Pode for querying task information based on specified parameters. This function supports multiple content types for both requests and responses, and can generate OpenAPI documentation.

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
- `Cancellable`
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

Add-PodeAsyncRouteQuery -Path '/tasks/query' -ResponseContentType 'application/json', 'application/yaml' -In Body|
Set-PodeOARouteInfo -Summary 'Query an Async Route Task'  # Set-PodeOARouteInfo is required to get the OpenApi documentation
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
    Cancellable = @{
        value = $true
        op = "EQ"
    }
}

Invoke-RestMethod -Uri "http://localhost:8080/tasks/query" -Method Post -Body ($queryBody | ConvertTo-Json) -ContentType "application/json"
```


