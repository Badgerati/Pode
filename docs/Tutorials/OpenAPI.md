# OpenAPI

Pode has inbuilt support for converting your routes into OpenAPI 3.0 definitions. There is also support for a enabling simple Swagger and/or ReDoc viewers.

You can simply enable OpenAPI in Pode, and a very simple definition will be generated. However, to get a more complex definition with request bodies, parameters and response payloads, you'll need to use the relevant OpenAPI functions detailed below.

## Enabling OpenAPI

To enable support for generating OpenAPI definitions you'll need to use the [`Enable-PodeOpenApi`](../../Functions/OpenApi/Enable-PodeOpenApi) function. This will allow you to set a title and version for your API. You can also set a default route to retrieve the OpenAPI definition for tools like Swagger or ReDoc, the default is at `/openapi`.

You can also set a route filter (such as `/api/*`, the default is `/*` for everything), so only those routes are included in the definition.

An example of enabling OpenAPI is a follows:

```powershell
Enable-PodeOpenApi -Title 'My Awesome API' -Version 9.0.0.1
```

An example of setting the OpenAPI route is a follows. This will create a route accessible at `/docs/openapi`:

```powershell
Enable-PodeOpenApi -Path '/docs/openapi' -Title 'My Awesome API' -Version 9.0.0.1
```

### Default Setup

In the very simplest of scenarios, just enabling OpenAPI will generate a minimal definition. It can be viewed in Swagger/ReDoc etc, but won't be usable for trying calls.

When you enable OpenAPI, and don't set any other OpenAPI data, the following is the minimal data that is included:

* Every route will have a 200 and Default response
* Although routes will be included, no request bodies, parameters or response payloads will be defined
* If you have multiple endpoints, then the servers section will be included
* Any authentication will be included

### Get Definition

Instead of defining a route to return the definition, you can write the definition to the response whenever you want, and in any route, using the [`Get-PodeOpenApiDefinition`](../../Functions/OpenApi/Get-PodeOpenApiDefinition) function. This could be useful in certain scenarios like in Azure Functions, where you can enable OpenAPI, and then write the definition to the response of a GET request if some query parameter is set; eg: `?openapi=1`.

For example:

```powershell
Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
    if ($WebEvent.Query.openapi -eq 1) {
        Get-PodeOpenApiDefinition | Write-PodeJsonResponse
    }
}
```

## Authentication

Any authentication defined, either by [`Add-PodeAuthMiddleware`](../../Functions/Authentication/Add-PodeAuthMiddleware), or using the `-Authentication` parameter on Routes, will be automatically added to the `security` section of the OpenAPI definition.

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

You can define multiple responses for a route, but only one of each status code, using the [`Add-PodeOAResponse`](../../Functions/OpenApi/Add-PodeOAResponse) function. You can either just define the response and status code, with a custom description, or with a schema defining the payload of the response.

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
    Write-PodeJsonResponse -Value @{
        Name = 'Rick'
        UserId = $WebEvent.Parameters['userId']
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

Internally, each route is created with an empty default 200 and 500 response. You can remove these, or other added responses, by using [`Remove-PodeOAResponse`](../../Functions/OpenApi/Add-PodeOAResponse):

```powershell
Add-PodeRoute -Method Get -Path "/api/user/:userId" -ScriptBlock {
    # logic
} -PassThru |
    Remove-PodeOAResponse -StatusCode 200
```

### Requests

#### Parameters

You can set route parameter definitions, such as parameters passed in the path/query, by using the [`Set-PodeOARequest`](../../Functions/OpenApi/Set-PodeOARequest) function with the `-Parameters` parameter. The parameter takes an array of properties converted into parameters, using the [`ConvertTo-PodeOAParameter`](../../Functions/OpenApi/ConvertTo-PodeOAParameter) function.

For example, to create some integer `userId` parameter that is supplied in the path of the request, the following will work:

```powershell
Add-PodeRoute -Method Get -Path '/api/users/:userId' -ScriptBlock {
    Write-PodeJsonResponse -Value @{
        Name = 'Rick'
        UserId = $WebEvent.Parameters['userId']
    }
} -PassThru |
    Set-PodeOARequest -Parameters @(
        (New-PodeOAIntProperty -Name 'userId' -Required | ConvertTo-PodeOAParameter -In Path)
    )
```

Whereas you could use the next example to define 2 query parameters, both strings:

```powershell
Add-PodeRoute -Method Get -Path '/api/users' -ScriptBlock {
    Write-PodeJsonResponse -Value @{
        Name = 'Rick'
        UserId = $WebEvent.Query['name']
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
    Write-PodeJsonResponse -Value @{
        Name = $WebEvent.Data.name
        UserId = $WebEvent.Data.userId
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
    Write-PodeJsonResponse -Value @{
        Name = 'Rick'
        UserId = $WebEvent.Parameters['userId']
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
    Write-PodeJsonResponse -Value @{
        Name = 'Rick'
        UserId = $WebEvent.Parameters['userId']
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

## Properties

Properties are used to create all Parameters and Schemas in OpenAPI. You can use the simple types on their own, or you can combine multiple of them together to form complex objects.

### Simple Types

There are 5 simple property types: Integers, Numbers, Strings, Booleans, and Schemas. Each of which can be created using the following functions:

* [`New-PodeOAIntProperty`](../../Functions/OpenApi/New-PodeOAIntProperty)
* [`New-PodeOANumberProperty`](../../Functions/OpenApi/New-PodeOANumberProperty)
* [`New-PodeOAStringProperty`](../../Functions/OpenApi/New-PodeOAStringProperty)
* [`New-PodeOABoolProperty`](../../Functions/OpenApi/New-PodeOABoolProperty)
* [`New-PodeOASchemaProperty`](../../Functions/OpenApi/New-PodeOASchemaProperty)

These properties can be created with a Name, and other flags such as Required and/or a Description:

```powershell
# simple integer
New-PodeOAIntProperty -Name 'userId'

# a float number with a max value of 100
New-PodeOANumberProperty -Name 'ratio' -Format Float -Maximum 100

# a string with a default value, and enum of options
New-PodeOAStringProperty -Name 'type' -Default 'admin' -Enum @('admin', 'user')

# a boolean that's required
New-PodeOABoolProperty -Name 'enabled' -Required

# a schema property that references another component schema
New-PodeOASchemaProperty -Name 'Config' -Reference 'ConfigSchema'
```

On their own, like above, the simple properties don't really do much. However, you can combine that together to make complex objects/arrays as defined below.

### Arrays

There isn't a dedicated function to create an array property, instead there is an `-Array` switch on each of the property functions - both Object and the above simple properties.

If you supply the `-Array` switch to any of the above simple properties, this will define an array of that type - the `-Name` parameter can also be omitted if only a simple array if required.

For example, the below will define an integer array:

```powershell
New-PodeOAIntProperty -Array
```

When used in a Response, this could return the following JSON example:

```json
[
    0,
    1,
    2
]
```

### Objects

An object property is a combination of multiple other properties - both simple, array of more objects.

There are two ways to define objects:

1. Similar to arrays, you can use the `-Object` switch on the simple properties.
2. You can use the [`New-PodeOAObjectProperty`](../../Functions/OpenApi/New-PodeOAObjectProperty) function to combine multiple properties.

#### Simple

If you use the `-Object` switch on the simple property function, this will automatically wrap the property as an object. The Name for this is required.

For example, the below will define a simple `userId` integer object:

```powershell
New-PodeOAIntProperty -Name 'userId' -Object
```

In a response as JSON, this could look as follows:

```json
{
    "userId": 0
}
```

Furthermore, you can also supply both `-Array` and `-Object` switches:

```powershell
New-PodeOAIntProperty -Name 'userId' -Object -Array
```

This wil result in something like the following JSON:

```json
{
    "userId": [ 0, 1, 2 ]
}
```

#### Complex

Unlike the `-Object` switch that simply converts a single property into an object, the [`New-PodeOAObjectProperty`](../../Functions/OpenApi/New-PodeOAObjectProperty) function can combine and convert multiple properties.

For example, the following will create an object using an Integer, String, and a Boolean:

```powershell
New-PodeOAObjectProperty -Properties @(
    (New-PodeOAIntProperty -Name 'userId'),
    (New-PodeOAStringProperty -Name 'name'),
    (New-PodeOABoolProperty -Name 'enabled')
)
```

As JSON, this could look as follows:

```json
{
    "userId": 0,
    "name": "Gary Goodspeed",
    "enabled": true
}
```

You can also supply the `-Array` switch to the [`New-PodeOAObjectProperty`](../../Functions/OpenApi/New-PodeOAObjectProperty) function. This will result in an array of objects. For example, if we took the above:

```powershell
New-PodeOAObjectProperty -Array -Properties @(
    (New-PodeOAIntProperty -Name 'userId'),
    (New-PodeOAStringProperty -Name 'name'),
    (New-PodeOABoolProperty -Name 'enabled')
)
```

As JSON, this could look as follows:

```json
[
    {
        "userId": 0,
        "name": "Gary Goodspeed",
        "enabled": true
    },
    {
        "userId": 1,
        "name": "Kevin",
        "enabled": false
    }
]
```

You can also combine objects into other objects:

```powershell
$usersArray = New-PodeOAObjectProperty -Name 'users' -Array -Properties @(
    (New-PodeOAIntProperty -Name 'userId'),
    (New-PodeOAStringProperty -Name 'name'),
    (New-PodeOABoolProperty -Name 'enabled')
)

New-PodeOAObjectProperty -Properties @(
    (New-PodeOAIntProperty -Name 'found'),
    $usersArray
)
```

As JSON, this could look as follows:

```json
{
    "found": 2,
    "users": [
        {
            "userId": 0,
            "name": "Gary Goodspeed",
            "enabled": true
        },
        {
            "userId": 1,
            "name": "Kevin",
            "enabled": false
        }
    ]
}
```

## Swagger and ReDoc

If you're not using a custom OpenAPI viewer, then you can use one of the inbuilt ones with Pode - either Swagger and ReDoc, or both!

For both you can customise the path to access the page on, but by default Swagger is at `/swagger` and ReDoc is at `/redoc`. If you've written your own custom OpenAPI definition then you can also set a custom path to fetch the definition.

To enable either you can use the [`Enable-PodeOpenApiViewer`](../../Functions/OpenApi/Enable-PodeOpenApiViewer) function:

```powershell
# for swagger at "/docs/swagger"
Enable-PodeOpenApiViewer -Type Swagger -Path '/docs/swagger' -DarkMode

# or ReDoc at the default "/redoc"
Enable-PodeOpenApiViewer -Type ReDoc
```
