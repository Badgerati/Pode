# Sessions

Session Middleware is supported on web requests and responses in the form of signed-cookies and server-side data storage. When configured, the middleware will check for a session-cookie on the request; if a cookie is not found on the request, or the session is not in the store, then a new session is created and attached to the response. If there is a session, then the appropriate data is loaded from the store.

The age of the session-cookie can be specified, as well as whether to extend the duration each time on each request. A secret-key to sign cookies can be supplied, as well as the ability to specify custom data stores - the default is in-mem, custom could be anything like Redis/MongoDB.

## Usage

To intialise sessions in Pode you use the `Enable-PodeSessionMiddleware` function. This function will configure and automatically create Middleware to enable sessions.

The following is an example of how to setup session middleware:

```powershell
Start-PodeServer {
    Enable-PodeSessionMiddleware -Secret 'schwifty' -Duration 120 -Extend -Generator {
        return [System.IO.Path]::GetRandomFileName()
    }
}
```

### Generate SessionIds

If supplied, the `-Generator` is a `scriptblock` that must return a valid string. The string itself should be a random unique value, that can be used as a unique session identifier. If no `-Generator` script is supplied, then the default `SessionId` is a `GUID`.

### Storage

If supplied, the `-Storage` parameter is a `psobject` with the following required `ScriptMethod` members:

```powershell
[hashtable] Get([string] $sessionId)
[void]      Set([string] $sessionId, [hashtable] $data, [datetime] $expiry)
[void]      Delete([string] $sessionId)
```

If no `-Storage` is supplied, then a default in-memory store is used - with auto-cleanup for expired sessions.

For example, the `Delete` method could be done as follows:

```powershell
$store = New-Object -TypeName psobject

$store | Add-Member -MemberType ScriptMethod -Name Delete -Value {
    param($sessionId)
    Remove-RedisKey $sessionId | Out-Null
}

return $store
```

## Session Data

To add data to a session you can utilise the `.Session.Data` object within the web event object supplied to a Route - or other Middleware. The data will be saved at the end of the route logic automatically using Endware. When a request comes in using the same session, the data is loaded from the store.

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
