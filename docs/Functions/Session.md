# Session

## Description

The `session` function creates and returns a middleware that enables session cookies.

Session middleware attaches onto web requests/responses, and uses signed-cookies and server-side data storage. When configured, the middleware will check for a session-cookie on the request; if a cookie is not found on the request, or the session is not in the store, then a new session is created and attached to the response. If there is a session, then the appropriate data is loaded from the store.

The age of the session-cookie can be specified (and whether to extend the duration each time), as well as a secret-key to sign cookies, and the ability to specify custom data stores - the default is in-memory, so custom stores could be anything like redis/mongo.

## Examples

### Example 1

The following example sets up basic `session` middleware, using a secret key and a 5min fixed duration:

```powershell
Server {
    middleware (session @{
        'Secret' = 'schwifty';
        'Duration' = 300;
    })
}
```

### Example 2

The following example sets up `session` middleware with a non-default cookie name, and a sliding 5min duration:

```powershell
Server {
    middleware (session @{
        'Secret' = 'schwifty';
        'Duration' = 300;
        'Extend' = $true;
        'Name' = 'session.id';
    })
}
```

### Example 3

The following example sets up `session` middleware with a custom SessionId script generator; to use a random filename instead of a guid:

```powershell
Server {
    middleware (session @{
        'Secret' = 'schwifty';
        'Duration' = 300;
        'GenerateId' = {
            return [System.IO.Path]::GetRandomFileName()
        }
    })
}
```

### Example 4

The following example sets up basic `session` middleware, and defines a `route` that adds data to the session. Each subsequent call to the route will increment the `views` counter:

```powershell
Server {
    listen *:8080 http

    middleware (session @{
        'Secret' = 'schwifty';
        'Duration' = 300;
    })

    route get '/' {
        $param($s)
        $s.Session.Data.Views++
        json @{ 'Views' = $s.Session.Data.Views }
    }
}
```

## Parameters

!!! note
    The `session` function takes a single `hashtable` as its parameter. The below parameters are the expected keys that should be present within the supplied parameter

| Name | Type | Required | Description | Default |
| ---- | ---- | -------- | ----------- | ------- |
| Secret | string | true | The secret key used to sign the cookies | empty |
| Name | string | false | The name of the session cookie | pode.sid |
| Duration | int | false | The duration of which the cookie lasts, in seconds (>=0) | 0 |
| Extend | bool | false | If true, the duration of the cookie will be extended each time a request is made using the session | false |
| Discard | bool | false | If true, informs the enduser's browser to discard the cookie on expiry | false |
| Secure | bool | false | If true, informs the enduser's browser to only send the cookie on secure connections | false |
| GenerateId | scriptblock | false | A script that should return a valid string. The string itself should be a random unique value, that can be used as a session identifier | guid |
| Store | psobject | false | An object that defines specific functions to communicate with a custom data store | null |

## Notes

A store should be a `psobject` that requires the following functions:

```powershell
[hashtable] Get([string] $sessionId)
[void]      Set([string] $sessionId, [hashtable] $data, [datetime] $expiry)
[void]      Delete([string] $sessionId)
```