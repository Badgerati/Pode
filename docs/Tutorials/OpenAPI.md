# OpenAPI

Pode has inbuilt support for converting your routes into OpenAPI 3.0 definitions. There is also support for a enabling simple Swagger and/or ReDoc viewers.

You can simply enable OpenAPI in Pode, and a very simple definition will be generated. However, you get a more complex definition with request bodies, parameters and response payloads, you'll need to use the relevant OpenAPI functions detailed below.

## Enabling OpenAPI

To enable support for generating OpenAPI definitions you use the [`Enable-PodeOpenApi`] function. This will allow you to set a title and version for your API, as well as a custom path to fetch the definition - the default is at `/openapi`.

You can also set a route filter (such as `/api/`, the default is `/` for everything), so only though routes are included in the definition.

An example of enabling OpenAPI is a follows:

```powershell
Enable-PodeOpenApi -Title 'My Awesome API' -Version 9.0.0.1 -Route '/api/'
```

### Default Setup

In the very simplest of scenarios, just enabling OpenAPI will generate a minimal definition. It can be viewed in Swagger/ReDoc etc, but won't be usable for trying calls.

When you enable OpenAPI, and don't set any other OpenAPI data, the following is the minimal data that is included:

* Every route will have a 200 and Default response
* Although routes will be included, no request bodies, parameters or response payloads will be defined
* If you have multiple endpoints, then the servers section will be included
* Any authentication will be included, but won't be bound to any routes



## Authentication

If your API requires the same authentication on every route, then the quickest way to define global authentication is to use the [`Set-PodeOAGlobalAuth`] function. This takes an array of authentication names:

```powershell
# define the authentication
New-PodeAuthType -Basic | Add-PodeAuth -Name 'Validate' -ScriptBlock {
    return @{ User = @{} }
}

# set the auth as global middleware for all /api routes
Get-PodeAuthMiddleware -Name 'Validate' -Sessionless | Add-PodeMiddleware -Name 'AuthMiddleware' -Route '/api/*'

# set the OpenAPI global auth
Set-PodeOAGlobalAuth -Name 'Validate'
```







## Routes

lorem

### Responses

lorem

### Requests

lorem

### Authentication

lorem





## Components

You can define reusable OpenAPI components in Pode. Currently supported are Schemas, Parameters, Request Bodies, and Responses.

### Schemas

lorem

### Request Bodies

To define a reusable request bodies you can use the [`Add-PodeOAComponentRequestBody`] function. You'll need to supply a Name, as well as the needed schemas for each content type.

The following is an example of defining a JSON object that a Name, UserId, and an Enable flag:

```powershell
# define a reusable request body
Add-PodeOAComponentRequestBody -Name 'UserBody' -Required -Schemas @{
    'application/json' = (New-PodeOAObjectProperty -Properties @(
        (New-PodeOAStringProperty -Name 'Name'),
        (New-PodeOAIntProperty -Name 'UserId'),
        (New-PodeOABoolProperty -Name 'Enabled')
    ))
}

# use the request body in a route
Add-PodeRoute -Method Patch -Path '/api/users' -ScriptBlock {
    param($e)
    Set-PodeResponseStatus -StatusCode 200
} -PassThru |
    Set-PodeOARequest -RequestBody (New-PodeOARequestBody -Reference 'UserBody')
```

The JSON payload expected is of the format:

```json
{
    "Name": [string],
    "UserId": [integer],
    "Enabled": [boolean]
}
```

### Parameters

To define reusable parameters that are used on requests, you can use the [`Add-PodeOAComponentParameter`] function. You'll need to supply a Name and the Parameter definition.

The following is an example of defining an integer path parameter for a `userId`, and then using that parameter on a route.

```powershell
# define a reusable {userid} path parameter
New-PodeOAIntProperty -Name 'userId' -Required | New-PodeOARequestParameter -In Path |Add-PodeOAComponentParameter -Name 'UserId'

# use this parameter in a route
Add-PodeRoute -Method Get -Path '/api/users/:userId' -ScriptBlock {
    param($e)
    Write-PodeJsonResponse -Value @{
        Name = 'Rick'
        UserId = $e.Parameters['userId']
    }
} -PassThru |
    Set-PodeOARequest -Parameters @(New-PodeOARequestParameter -Reference 'UserId')
```

### Responses

To define a reusable response definition you can use the [`Add-PodeOAComponentResponse`] function. You'll need to supply a Name, and optionally any Content/Header schemas that define the responses payload.

The following is an example of defining a 200 response, that has a JSON payload of an array of objects for Name/UserId. This can then be used by name on a route:

```powershell
# defines a response with a json payload
Add-PodeOAComponentResponse -Name 'OK' -Description 'A user object' -ContentSchemas @{
    'application/json' = (New-PodeOAObjectProperty -Array -Properties @(
        (New-PodeOAStringProperty -Name 'Name'),
        (New-PodeOAIntProperty -Name 'UserId')
    ))
}

# reuses the above response on a route using its "OK" name
Add-PodeRoute -Method Get -Path "/api/users" -ScriptBlock {
    Write-PodeJsonResponse -Value @(
        @{ Name = 'Rick'; UserId = 123 },
        @{ Name = 'Geralt'; UserId = 124 }
    )
} -PassThru |
    Add-PodeOAResponse -StatusCode 200 -Reference 'OK'
```

the JSON response payload defined is as follows:

```json
[
    {
        "Name": [string],
        "UserId": [integer]
    }
]
```







## Swagger and ReDoc

If you're not using a custom OpenAPI viewer, then you can use one of the inbuilt ones with Pode - either Swagger and ReDoc, or both!

For both you can customise the path to access the page on, but by default Swagger is at `/swagger` and ReDoc is at `/redoc`. If you've written your own custom OpenAPI definition then you can also set a custom path to fetch the definition.

To enable Swagger you can use the [`Enable-PodeSwagger`] function:

```powershell
Enable-PodeSwagger -Path '/docs/swagger' -DarkMode
```

And to enable ReDoc you can use the [`Enable-PodeReDoc`] function:

```powershell
Enable-PodeReDoc -Path '/docs/redoc' -OpenApi '/custom_openapi.yml'
```
