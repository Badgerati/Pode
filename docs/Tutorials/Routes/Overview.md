# Route Overview

Routes in Pode allow you to bind logic that should be invoked when a user calls a certain path on a URL, for a specific HTTP method, against your server. Routes allow you to host REST APIs and Web Pages, as well as using custom middleware for things like authentication.

You can also specify static routes, that redirect requests to static content to internal directories.

Routes can also be bound against a specific protocol or endpoint. This allows you to bind multiple root (`/`) routes against different endpoints - if you're listening to multiple endpoints.

!!! info
    The following HTTP methods are supported by routes in Pode:
    DELETE, GET, HEAD, MERGE, OPTIONS, PATCH, POST, PUT, TRACE, and STATIC (for static file routing).

## Usage

To setup and use routes in Pode you should use the [`route`](../../../Function/Core/Route) function. The general make-up of the `route` function is as follows - the former is for HTTP requests, where as the latter is for static content:

```powershell
route <method> <route> [<middleware>] <scriptblock> [-protocol <string>] [-endpoint <string>] [-remove]
route static <route> <path> [<defaults>] [-protocol <string>] [-endpoint <string>] [-remove]

# or shorthand:
route <method> <route> [<middleware>] <scriptblock> [-p <string>] [-e <string>] [-rm]
route static <route> <path> [<defaults>] [-p <string>] [-e <string>] [-rm]
```

For example, let's say you want a basic `GET /ping` endpoint to just return `pong` as a JSON response:

```powershell
Server {
    listen *:8080 http

    route get '/ping' {
        json @{ 'value' = 'pong'; }
    }
}
```

Here, anyone who calls `http://localhost:8080/ping` will receive the following response:

```json
{
    "value": "pong"
}
```

The scriptblock for the route will be supplied with a single argument that contains information about the current web event. This argument will contain the `Request` and `Response` objects, `Data` (from POST), and the `Query` (from the query string of the URL), as well as any `Parameters` from the route itself (eg: `/:accountId`).

## Payloads

The following is an example of using data from a request's payload - ie, the data in the body of POST request. To retrieve values from the payload you can use the `.Data` hashtable on the supplied web-session to a route's logic. This example will get the `userId` and "find" user, returning the users data:

```powershell
Server {
    listen *:8080 http

    route post '/users' {
        param($s)

        # get the user
        $user = Get-DummyUser -UserId $s.Data['userId']

        # return the user
        json @{
            'Username' = $user.username;
            'Age' = $user.age;
        }
    }
}
```

The following request will invoke the above route:

```powershell
Invoke-WebRequest -Uri 'http://localhost:8080/users' -Method Post -Body '{ "userId": 12345 }' -ContentType 'application/json'
```

!!! important
    The `ContentType` is required as it tells allows Pode how to parse the requests payload.

## Query Strings

The following is an example of using data from a request's query string. To retrieve values from the query string you can use the `.Query` hashtable on the supplied web-session to a route's logic. This example will return a user based on the `userId` supplied:

```powershell
Server {
    listen *:8080 http

    route get '/users' {
        param($s)

        # get the user
        $user = Get-DummyUser -UserId $s.Query['userId']

        # return the user
        json @{
            'Username' = $user.username;
            'Age' = $user.age;
        }
    }
}
```

The following request will invoke the above route:

```powershell
Invoke-WebRequest -Uri 'http://localhost:8080/users?userId=12345' -Method Get
```

## Parameters

The following is an example of using values supplied on a request's URL using parameters. To retrieve values that match a request's URL parameters you can use the `.Parameters` hashtable on the supplied web-session to a route's logic. This example will get the `:userId` and "find" user, returning the users data:

```powershell
Server {
    listen *:8080 http

    route get '/users/:userId' {
        param($s)

        # get the user
        $user = Get-DummyUser -UserId $s.Parameters['userId']

        # return the user
        json @{
            'Username' = $user.username;
            'Age' = $user.age;
        }
    }
}
```

The following request will invoke the above route:

```powershell
Invoke-WebRequest -Uri 'http://localhost:8080/users/12345' -Method Get
```

## Static Content

The following is an example of using the `route` function to define routes to static content, that allow you to specify where to get static files from for certain routes. This example will define a static route for `/assets`, and will point to the route at the internal directory `./content/assets`:

```powershell
Server {
    listen *:8080 http
    route static '/assets' './content/assets'
}
```

The following request will retrieve an image from the `./content/assets/images` directory:

```powershell
Invoke-WebRequest -Uri 'http://localhost:8080/assets/images/icon.png' -Method Get
```

### Default Pages

Furthermore, for static content, Pode also supports returning default pages when a static content directory is requested. The inbuilt default pages are:

```plain
index.html
index.htm
default.html
default.htm
```

These pages are checked in order, and if one is found then its content is returned. Using the above static server script, if the `./content/assets/home` directory contained an `index.html` page, then the following request would return the content for the `index.html` page:

```powershell
Invoke-WebRequest -Uri 'http://localhost:8080/assets/images/home' -Method Get
```

The default pages can be configured in two ways; either by using the `-Defaults` parameter on the `route`, or by setting the list in the `pode.json` [configuration file](../../Configuration). To set the defaults to be only a `home.html` page, both ways would work as follows:

*Defaults Parameter*
```powershell
route static '/assets' './content/assets' -d @('home.html')
```

*Configuration File*
```json
{
    "web": {
        "static": {
            "defaults": [ "home.html" ]
        }
    }
}
```