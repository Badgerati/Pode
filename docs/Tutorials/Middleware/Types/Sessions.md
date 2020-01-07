# Sessions

Session Middleware is supported on web requests and responses in the form of signed-cookies/headers and server-side data storage. When configured, the middleware will check for a session-cookie/header on the request; if a cookie/header is not found on the request, or the session is not in the store, then a new session is created and attached to the response. If there is a session, then the appropriate data is loaded from the store.

The duration of the session-cookie/header can be specified, as well as whether to extend the duration each time on each request. A secret-key to sign sessions can be supplied, as well as the ability to specify custom data stores - the default is in-mem, custom could be anything like Redis/MongoDB.

!!! note
    Using sessions via headers is best used with REST APIs and the CLI. It's not advised to use them for normal websites, as browsers don't send back response headers in new requests - unlike cookies.

## Usage

To initialise sessions in Pode you use the [`Enable-PodeSessionMiddleware`](../../../../Functions/Middleware/Enable-PodeSessionMiddleware) function. This function will configure and automatically create Middleware to enable sessions. By default sessions are set using cookies, but support is also available for headers.

### Cookies

The following is an example of how to setup session middleware using cookies:

```powershell
Start-PodeServer {
    Enable-PodeSessionMiddleware -Secret 'schwifty' -Duration 120 -Extend -Generator {
        return [System.IO.Path]::GetRandomFileName()
    }
}
```

The default name of the session cookie is `pode.sid`, but this can be customised using the `-Name` parameter.

### Headers

Sessions are also supported using headers - useful for CLI requests. The following example will enable sessions use headers instead of cookies:

```powershell
Start-PodeServer {
    Enable-PodeSessionMiddleware -Secret 'schwifty' -Duration 120 -Extend -UseHeaders
}
```

When using headers, the default name of the session header in the request/response is `pode.sid` - this can be customised using the `-Name` parameter. When you make an initial request to authenticate some user, the `pode.sid` header will be returned in the response. You can then use the value of this header in subsequent requests for the authenticated user, and then make a call using the session one last time against some route to expire the session - or just let it automatically expire.

## SessionIds

The inbuilt SessionId generator used for sessions is a GUID, but you can supply a custom generator using the `-Generator` parameter.

If supplied, the `-Generator` is a `scriptblock` that must return a valid string. The string itself should be a random unique value, that can be used as a unique session identifier.

Within a route, or middleware, you can get the current authenticated sessionId using [`Get-PodeSessionId`](../../../../Functions/Middleware/Get-PodeSessionId). If there is no session, or the session is not authenticated, then `$null` is returned. This function can also returned the fully signed sessionId as well.

### Strict

You can flag sessions as being strict using the `-Strict` switch. Strict sessions will extend the signing process by also using the client's UserAgent and RemoteIPAddress, to help prevent session sharing on different browsers/consoles.

You can supply the secret value as normal, Pode will automatically extend it for you.

## Storage

The inbuilt storage for sessions is a simple In-Memory store - with auto-cleanup for expired sessions.

If supplied, the `-Storage` parameter is a `psobject` with the following required `ScriptMethod` members:

```powershell
[hashtable] Get([string] $sessionId)
[void]      Set([string] $sessionId, [hashtable] $data, [datetime] $expiry)
[void]      Delete([string] $sessionId)
```

For example, the `Delete` method could be done as follows:

```powershell
$store = New-Object -TypeName psobject

$store | Add-Member -MemberType ScriptMethod -Name Delete -Value {
    param($sessionId)
    Remove-RedisKey $sessionId | Out-Null
}
```

## Session Data

To add data to a session you can utilise the `.Session.Data` object within the web event object supplied to a Route - or other Middleware. The data will be saved at the end of the route automatically using Endware. When a request is made using the same sessionId, the data is loaded from the store.

### Example

An example of using sessions in a Route to increment a views counter could be done as follows (the counter will continue to increment on each call to the route until the session expires after 2mins):

```powershell
Start-PodeServer {
    Enable-PodeSessionMiddleware -Secret 'schwifty' -Duration 120

    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        param($s)
        $s.Session.Data.Views++
        Write-PodeJsonResponse -Value @{ 'Views' = $s.Session.Data.Views }
    }
}
```
