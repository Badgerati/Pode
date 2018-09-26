# Sessions

Session `middleware` is supported on web requests and responses, in the form of signed-cookies and server-side data storage. When configured, the middleware will check for a session-cookie on the request; if a cookie is not found on the request, or the session is not in the store, then a new session is created and attached to the response. If there is a session, then the appropriate data is loaded from the store.

The age of the session-cookie can be specified, as well as whether to extend the duration each time on each request. A secret-key to sign cookies can be supplied, as well as the ability to specify custom data stores - the default is in-mem, custom could be anything like redis/mongo.

## Usage

To setup and configure the using sessions in Pode, you can use the [`session`](../../../Functions/Middleware/Session) function. This function will return valid middleware that can be supplied to the [`middleware`](../../../Functions/Core/Middleware) function.

To use the `session` function you must supply a `hashtable` that defines options to configure sessions, and the way they work.

The following is an example of how to setup session middleware, with a `hashtable` that defines all possible options that could be supplied:

```powershell
Server {
    middleware (session @{
        'Secret' = 'schwifty';      # secret-key used to sign session cookie
        'Name' = 'pode.sid';        # session cookie name (def: pode.sid)
        'Duration' = 120;           # duration of the cookie, in seconds
        'Extend' = $true;           # extend the duration of the cookie on each call
        'GenerateId' = {            # custom SessionId generator (def: guid)
            return [System.IO.Path]::GetRandomFileName()
        };
        'Store' = $null;            # custom object with required methods (def: in-mem)
    })
}
```

### GenerateId

If supplied, the `GenerateId` script must be a `scriptblock` that returns a valid string. The string itself should be a random unique value, that can be used as a unique session identifier. If no `GenerateId` script is supplied, then the default `sessionId` is a `guid`.

### Store

If supplied, the `Store` must be a valid object with the following required functions:

```powershell
[hashtable] Get([string] $sessionId)
[void]      Set([string] $sessionId, [hashtable] $data, [datetime] $expiry)
[void]      Delete([string] $sessionId)
```

If no store is supplied, then a default in-memory store is used - with auto-cleanup for expired sessions.

To add data to a session you can utilise the `.Session.Data` object within the parameter supplied to a `route` - or other middleware. The data will be saved at the end of the route logic automatically using [`endware`](../../../Functions/Core/Endware). When a request comes in using the same session, the data is loaded from the store.

An example of using a `session` in a `route` to increment a views counter could be as follows (the counter will continue to increment on each call to the route until the session expires):

```powershell
Server {
    middleware (session @{ 'secret' = 'schwifty'; 'duration' = 120; })

    route 'get' '/' {
        param($s)
        $s.Session.Data.Views++
        json @{ 'Views' = $s.Session.Data.Views }
    }
}
```