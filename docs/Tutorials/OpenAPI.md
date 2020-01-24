# OpenAPI

Pode has inbuilt support for converting your routes into OpenAPI 3.0 definitions. There is also support for a enabling simple Swagger and/or ReDoc viewers.

You can simply enable OpenAPI in Pode, and a very simple definition will be generated. However, to get a more complex definition with request bodies, parameters and response payloads, you'll need to use the relevant OpenAPI functions detailed below.

## Enabling OpenAPI

To enable support for generating OpenAPI definitions you'll need to use the [`Enable-PodeOpenApi`](../../Functions/OpenApi/Enable-PodeOpenApi) function. This will allow you to set a title and version for your API, as well as a custom path to fetch the definition - the default is at `/openapi`.

You can also set a route filter (such as `/api/*`, the default is `/*` for everything), so only those routes are included in the definition.

An example of enabling OpenAPI is a follows:

```powershell
Enable-PodeOpenApi -Title 'My Awesome API' -Version 9.0.0.1 -Route '/api/*'
```

### Default Setup

In the very simplest of scenarios, just enabling OpenAPI will generate a minimal definition. It can be viewed in Swagger/ReDoc etc, but won't be usable for trying calls.

When you enable OpenAPI, and don't set any other OpenAPI data, the following is the minimal data that is included:

* Every route will have a 200 and Default response
* Although routes will be included, no request bodies, parameters or response payloads will be defined
* If you have multiple endpoints, then the servers section will be included
* Any authentication will be included, but won't be bound to any routes

## Authentication

If your API requires the same authentication on every route, then the quickest way to define global authentication is to use the [`Set-PodeOAGlobalAuth`](../../Functions/OpenApi/Set-PodeOAGlobalAuth) function. This takes an array of authentication names:

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

This will set the `security` section of the OpenAPI definition.

## Routes

To extend the definition of a route, you can use the `-PassThru` switch on the [`Add-PodeRoute`](../../Functions/Routes/Add-PodeRoute) function. This will cause the route that was created to be returned, so you can pass it down the pipe into more OpenAPI functions.

To add metadata to a route's definition you can use the [`Set-PodeOARouteInfo`](../../Functions/OpenApi/Set-PodeOARouteInfo) function. This will allow you to define a summary/description for the route, as well as tags for grouping:

```powershell
Add-PodeRoute -Method Get -Path "/api/resources" -ScriptBlock {
    Set-PodeResponseStatus -Code 200
} -PassThru |
    Set-PodeOARouteInfo -Summary 'Retrieve some resources' -Tags 'Resources'
```

Each of the following OpenAPI functions have a `-PassThru` switch, allowing you to chain many of them together.

### Responses

You can define multiple responses for a route, but only one of each status code, using the [`Add-PodeOAResponse`](../../Functions/OpenApi/Add-PodeOAResponse) function. You can either just define the response and status code; with a custom description; or with a schema defining the payload of the response.

The following is an example of defining simple 200 and 404 responses on a route:

```powershell
Add-PodeRoute -Method Get -Path "/api/user/:userId" -ScriptBlock {
    # logic
} -PassThru |
    Add-PodeOAResponse -StatusCode 200 -PassThru |
    Add-PodeOAResponse -StatusCode 404 -Description 'User not found'
```

Whereas the following is a more complex definition, which also defines the responses JSON payload. This payload is defined as an object with a string Name, and integer UserId:

```powershell
Add-PodeRoute -Method Get -Path '/api/users/:userId' -ScriptBlock {
    param($e)
    Write-PodeJsonResponse -Value @{
        Name = 'Rick'
        UserId = $e.Parameters['userId']
    }
} -PassThru |
    Add-PodeOAResponse -StatusCode 200 -Description 'A user object' -ContentSchemas @{
        'application/json' = (New-PodeOAObjectProperty -Properties @(
            (New-PodeOAStringProperty -Name 'Name'),
            (New-PodeOAIntProperty -Name 'UserId')
        ))
    }
```

the JSON response payload defined is as follows:

```json
{
    "Name": [string],
    "UserId": [integer]
}
```

### Requests

#### Parameters

You can set route parameter definitions, such as parameters passed in the path/query, by using the [`Set-PodeOARequest`](../../Functions/OpenApi/Set-PodeOARequest) function with the `-Parameters` parameter. The parameter takes an array of properties converted into parameters, using the [`ConvertTo-PodeOAParameter`](../../Functions/OpenApi/ConvertTo-PodeOAParameter) function.

For example, to create some integer `userId` parameter that is supplied in the path of the request, the following will work:

```powershell
Add-PodeRoute -Method Get -Path '/api/users/:userId' -ScriptBlock {
    param($e)
    Write-PodeJsonResponse -Value @{
        Name = 'Rick'
        UserId = $e.Parameters['userId']
    }
} -PassThru |
    Set-PodeOARequest -Parameters @(
        (New-PodeOAIntProperty -Name 'userId' -Required | ConvertTo-PodeOAParameter -In Path)
    )
```

Whereas you could use the next example to define 2 query parameters, both strings:

```powershell
Add-PodeRoute -Method Get -Path '/api/users' -ScriptBlock {
    param($e)
    Write-PodeJsonResponse -Value @{
        Name = 'Rick'
        UserId = $e.Query['name']
    }
} -PassThru |
    Set-PodeOARequest -Parameters @(
        (New-PodeOAStringProperty -Name 'name' -Required | ConvertTo-PodeOAParameter -In Query),
        (New-PodeOAStringProperty -Name 'city' -Required | ConvertTo-PodeOAParameter -In Query)
    )
```

#### Payload

You can set request payload schemas by using the [`Set-PodeOARequest`](../../Functions/OpenApi/Set-PodeOARequest) function, with the `-RequestBody` parameter. The request body can be defined using the [`New-PodeOARequestBody`](../../Functions/OpenApi/New-PodeOARequestBody) function, and supplying schema definitions for content types - this works in very much a similar way to defining responses above.

For example, to define a request JSON payload of some `userId` and `name` you could use the following:

```powershell
Add-PodeRoute -Method Patch -Path '/api/users' -ScriptBlock {
    param($e)
    Write-PodeJsonResponse -Value @{
        Name = $e.Data.name
        UserId = $e.Data.userId
    }
} -PassThru |
    Set-PodeOARequest -RequestBody (
        New-PodeOARequestBody -Required -ContentSchemas @{
            'application/json' = (New-PodeOAObjectProperty -Properties @(
                (New-PodeOAStringProperty -Name 'name'),
                (New-PodeOAIntProperty -Name 'userId')
            ))
        }
    )
```

The expected payload would look as follows:

```json
{
    "name": [string],
    "userId": [integer]
}
```

### Authentication

To add the authentication used on a route's definition you can pipe the route into the [`Set-PodeOAAuth`](../../Functions/OpenApi/Set-PodeOAAuth) function. This function takes the name of an authentication type being used on the route.

```powershell
# add the auth type
New-PodeAuthType -Basic | Add-PodeAuth -Name 'Validate' -ScriptBlock {
    return @{ User = @{} }
}

$auth = (Get-PodeAuthMiddleware -Name 'Validate' -Sessionless)

# define a route that uses the auth type
Add-PodeRoute -Method Get -Path "/api/resources" -Middleware $auth -ScriptBlock {
    Set-PodeResponseStatus -Code 200
} -PassThru |
    Set-PodeOAAuth -Name 'Validate'
```

## Components

You can define reusable OpenAPI components in Pode. Currently supported are Schemas, Parameters, Request Bodies, and Responses.

### Schemas

To define a reusable schema that can be used in request bodies, and responses, you can use the [`Add-PodeOAComponentSchema`](../../Functions/OpenApi/Add-PodeOAComponentSchema) function. You'll need to supply a Name, and a Schema that can be reused.

The following is an example of defining a schema which is a object of Name, UserId, and Age:

```powershell
# define a reusable schema user object
Add-PodeOAComponentSchema -Name 'UserSchema' -Schema (
    New-PodeOAObjectProperty -Properties @(
        (New-PodeOAStringProperty -Name 'Name'),
        (New-PodeOAIntProperty -Name 'UserId'),
        (New-PodeOAIntProperty -Name 'Age')
    )
)

# reuse the above schema in a response
Add-PodeRoute -Method Get -Path '/api/users/:userId' -ScriptBlock {
    param($e)
    Write-PodeJsonResponse -Value @{
        Name = 'Rick'
        UserId = $e.Parameters['userId']
        Age = 42
    }
} -PassThru |
    Add-PodeOAResponse -StatusCode 200 -Description 'A list of users' -ContentSchemas @{
        'application/json' = 'UserSchema'
    }
```

### Request Bodies

To define a reusable request bodies you can use the [`Add-PodeOAComponentRequestBody`](../../Functions/OpenApi/Add-PodeOAComponentRequestBody) function. You'll need to supply a Name, as well as the needed schemas for each content type.

The following is an example of defining a JSON object that a Name, UserId, and an Enable flag:

```powershell
# define a reusable request body
Add-PodeOAComponentRequestBody -Name 'UserBody' -Required -ContentSchemas @{
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

To define reusable parameters that are used on requests, you can use the [`Add-PodeOAComponentParameter`](../../Functions/OpenApi/Add-PodeOAComponentParameter) function. You'll need to supply a Name and the Parameter definition.

The following is an example of defining an integer path parameter for a `userId`, and then using that parameter on a route.

```powershell
# define a reusable {userid} path parameter
New-PodeOAIntProperty -Name 'userId' -Required | ConvertTo-PodeOAParameter -In Path |Add-PodeOAComponentParameter -Name 'UserId'

# use this parameter in a route
Add-PodeRoute -Method Get -Path '/api/users/:userId' -ScriptBlock {
    param($e)
    Write-PodeJsonResponse -Value @{
        Name = 'Rick'
        UserId = $e.Parameters['userId']
    }
} -PassThru |
    Set-PodeOARequest -Parameters @(ConvertTo-PodeOAParameter -Reference 'UserId')
```

### Responses

To define a reusable response definition you can use the [`Add-PodeOAComponentResponse`](../../Functions/OpenApi/Add-PodeOAComponentResponse) function. You'll need to supply a Name, and optionally any Content/Header schemas that define the responses payload.

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

To enable Swagger you can use the [`Enable-PodeSwagger`](../../Functions/OpenApi/Enable-PodeSwagger) function:

```powershell
Enable-PodeSwagger -Path '/docs/swagger' -DarkMode
```

And to enable ReDoc you can use the [`Enable-PodeReDoc`](../../Functions/OpenApi/Enable-PodeReDoc) function:

```powershell
Enable-PodeReDoc -Path '/docs/redoc' -OpenApi '/custom_openapi.yml'
```
