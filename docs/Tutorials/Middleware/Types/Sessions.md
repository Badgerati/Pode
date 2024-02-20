# Sessions

Session Middleware is supported on web requests and responses in the form of signed a cookie/header and server-side data storage. When configured the middleware will check for a session cookie/header (usually called `pode.sid`) on the request; if a cookie/header is not found on the request, or the session is not in storage, then a new session is created and attached to the response. If there is a session, then the appropriate data for that session is loaded from storage.

The duration of the session cookie/header can be specified, as well as whether to extend the duration each time on each request. A secret key to sign sessions can be supplied (default is a random GUID), as well as the ability to specify custom data stores - the default is in-memory, but custom storage could be anything like Redis/MongoDB/etc.

!!! note
    Using sessions via headers is best used with REST APIs and the CLI. It's not advised to use them for normal websites, as browsers don't send back response headers in new requests - unlike cookies.

!!! tip
    Sessions are typically used in conjunction with Authentication, but you can use them standalone as well!

## Usage

To initialise sessions in Pode you'll need to call [`Enable-PodeSessionMiddleware`](../../../../Functions/Sessions/Enable-PodeSessionMiddleware). This function will configure and automatically create the Middleware needed to enable sessions. By default, sessions are set to use cookies, but support is also available for headers.

Sessions are automatically signed using a random GUID. For Pode running on a single server using the default in-memory storage this is OK, however if you're running Pode on multiple servers, or if you're defining a custom storage then a `-Secret` is required - this is so that sessions from different servers, or after a server restart, don't become corrupt and unusable.

### Cookies

The following is an example of how to set up session middleware using cookies. The duration of each session is defined as a total number of seconds via the `-Duration` parameter; here we set the duration to 120, so each session created will expire after 2mins, but the expiry time will be extended each time the session is used:

```powershell
Start-PodeServer {
    Enable-PodeSessionMiddleware -Duration 120 -Extend
}
```

The default name of the session cookie is `pode.sid`, but this can be customised using the `-Name` parameter.

### Headers

Sessions are also supported using headers - useful for CLI requests. The following example will enable sessions to use headers instead of cookies, and will also set each session created to have a `-Duration` of 120 seconds:

```powershell
Start-PodeServer {
    Enable-PodeSessionMiddleware -Duration 120 -Extend -UseHeaders
}
```

When using headers, the default name of the session header in the request/response is `pode.sid` - this can be customised using the `-Name` parameter. When you make an initial request to authenticate some user, the `pode.sid` header will be returned in the response. You can then use the value of this header in subsequent requests for the authenticated user, and then make a call using the session one last time against some route to expire the session - or just let it automatically expire.

## Scope

Sessions have two different Scopes: Browser and Tab. You can specify the scope using the `-Scope` parameter on [`Enable-PodeSessionMiddleware`](../../../../Functions/Sessions/Enable-PodeSessionMiddleware).

!!! important
    Using the Tabs scope requires additional frontend logic, and doesn't work out-of-the-box like the Browser scope. See more [below](#tabs).

The default Scope is Browser, where any authentication and general session data is shared across all tabs in a browser. If you have a site with a view counter and you log in to your site on one tab, and then open another tab and navigate to your site, you'll be automatically logged in and see the same view counter results in both tabs.

The Tabs scope still shares authentication data, so if you log in to your site in one tab and open it again in a different tab, you'll still be logged in. However, general data is separated; taking the view counter example above, both tabs will show different results for the view counter.

### Tabs

Unlike the Browser scope which works out-of-the-box when enabled, the Tabs scope requires additional frontend logic.

For session data to be split across different tabs, you need to inform Pode about what the "TabId" is for each tab. This is done by supplying an `X-PODE-SESSION-TAB-ID` HTTP header in the request. From a browser on a normal page request, there's no way to supply this header, and the normal base session will be supplied instead - hence why authentication data remains shared across tabs. However, if you load the content of your site asynchronously, or via any other means, you can supply this header and it will let you split general session data across tabs.

In websites, the TabId is typically generated via JavaScript, and stored in `window.sessionStorage`. However, you have to be careful with this approach, as it does make tab sessions susceptible to XSS attacks. The following is a similar approach as used by Pode.Web:

```javascript
// set TabId
if (window.sessionStorage.TabId) {
    window.TabId = window.sessionStorage.TabId;
    window.sessionStorage.removeItem("TabId");
}
else {
    window.TabId = Math.floor(Math.random() * 1000000);
}

// binding to persist TabId on refresh
window.addEventListener("beforeunload", function(e) {
    window.sessionStorage.TabId = window.TabId;
    return null;
});
```

The TabId could then be sent as an HTTP header using AJAX. There are other approaches available online as well.

## SessionIds

The built-in SessionId generator used for sessions is a GUID, but you can supply a custom generator using the `-Generator` parameter.

If supplied, the `-Generator` is a scriptblock that must return a valid string. The string itself should be a random unique value, that can be used as a unique session identifier.

Within a route, or middleware, you can get the currently authenticated session's ID using [`Get-PodeSessionId`](../../../../Functions/Sessions/Get-PodeSessionId). If there is no session, or the session is not authenticated, then `$null` is returned. This function can also return the fully signed sessionId as well. If you want the sessionId even if it's not authenticated, then you can supply `-Force` to get the current SessionId back.

!!! note
    If you're using the Tab `-Scope`, then the SessionId will include the TabId as well, if one was supplied.

### Strict

You can flag sessions as being strict using the `-Strict` switch. Strict sessions will extend the signing process by also using the client's UserAgent and RemoteIPAddress, to help prevent session sharing on different browsers/consoles.

Pode will automatically extend the Secret used for signing for you, whether you're using the default GUID, or supplying a specific `-Secret` value.

## Storage

The inbuilt storage for sessions is a simple in-memory store - with auto-cleanup for expired sessions.

You can define a custom storage by supplying a `psobject` to the `-Storage` parameter, and also note that a `-Secret` will be required. The `psobject` supplied should have the following `NoteProperty` scriptblock members:

```powershell
[hashtable] Get([string] $sessionId)
[void]      Set([string] $sessionId, [hashtable] $data, [datetime] $expiry)
[void]      Delete([string] $sessionId)
```

For example, the following is a mock-up of a Storage for Redis (note that the functions are fake):

```powershell
# create the object
$store = New-Object -TypeName psobject

# add a Get property for retreiving a session's data by SessionId
$store | Add-Member -MemberType NoteProperty -Name Get -Value {
    param($sessionId)
    $data = Get-RedisKey -Key $sessionId
    return ($data | ConvertFrom-Json -AsHashtable)
}

# add a Set property to save a session's data
$store | Add-Member -MemberType NoteProperty -Name Set -Value {
    param($sessionId, $data, $expiry)
    Set-RedisKey -Key $sessionId -Value ($data | ConvertTo-Json -Compress) -TimeToLive $expiry
}

# add a Delete property to delete a session's data by SessionId
$store | Add-Member -MemberType NoteProperty -Name Delete -Value {
    param($sessionId)
    Remove-RedisKey -Key $sessionId
}

# enable session middleware - a secret is required
Enable-PodeSessionMiddleware -Duration 120 -Storage $store -Secret 'schwifty'
```

## Session Data

To add data to a session you can use the `.Session.Data` property within the [web event](../../../WebEvent) object, which is accessible in a Route or other Middleware. The data will be saved to some storage at the end of the request automatically using Endware. When a request is made using the same SessionId, the data is loaded from the store. For example, incrementing some view counter:

```powershell
Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
    $WebEvent.Session.Data.Views++
}
```

You can also use the `$session:` variable scope, which will get/set data on the current session for the name supplied. You can use `$session:` anywhere a `$WebEvent` is available - such as Routes, Middleware, Authentication, and Endware. The same view counter example above would now be as follows:

```powershell
Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
    $session:Views++
}
```

A session's data will be automatically saved by Pode at the end of each request, but you can force the data of the current session to be saved by using [`Save-PodeSession`](../../../../Functions/Sessions/Save-PodeSession).

!!! important
    `$session:` can only be used in the main scriptblocks of Routes, etc. If you attempt to use it in a function of a custom module, it will fail; even if you're using the function in a route. Pode remaps `$session:` on server start, and can only do this to the main scriptblocks supplied to functions such as `Add-PodeRoute`. In these scenarios, you will have to use `$WebEvent.Session.Data`.

!!! note
    If using the Tab `-Scope`, any session data will be stored separately from other tabs. This allows you to have multiple tabs open for the same site/page but all with separate session data. Any authentication data will still be shared.

## Expiry

When you enable Sessions using [`Enable-PodeSessionMiddleware`](../../../../Functions/Sessions/Enable-PodeSessionMiddleware) you can define the duration of each session created, in seconds, using the `-Duration` parameter. When a session is created its expiry is set to `DateTime.UtcNow + Duration`, and by default, a session will automatically expire when the calculated DateTime is reached:

```powershell
Start-PodeServer {
    Enable-PodeSessionMiddleware -Duration 120
}
```

You can tell Pode to reset/extend each session's expiry on each request sent, that uses that SessionId, by supplying the `-Extend` switch. When a session's expiry is reset/extended, the DateTime/Duration calculation is re-calculated:

```powershell
Start-PodeServer {
    Enable-PodeSessionMiddleware -Duration 120 -Extend
}
```

### Retrieve

You can retrieve the expiry for the current session by using [`Get-PodeSessionExpiry`](../../../../Functions/Sessions/Get-PodeSessionExpiry). If you use this function without `-Extend` specified originally then this will return the explicit DateTime the current session will expire. However, if you did set up sessions to extend then this function will return the recalculated expiry for the current session on each call:

```powershell
Start-PodeServer {
    Enable-PodeSessionMiddleware -Duration 120 -Extend

    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        # this will return a DateTime that will always be 2mins in the future
        $expiry = Get-PodeSessionExpiry
    }
}
```

### Terminate

To terminate the current session you can call [`Remove-PodeSession`](../../../../Functions/Sessions/Remove-PodeSession). Calling this will immediately set the session to expire now - as if somebody had clicked "Log Out". The session's data will be removed, the cookie will be discarded, and any authentication information will be dropped.

```powershell
Start-PodeServer {
    Enable-PodeSessionMiddleware -Duration 120 -Extend

    Add-PodeRoute -Method Get -Path '/logout' -ScriptBlock {
        # this will terminate the current session
        Remove-PodeSession
    }
}
```

### Reset

For any session created when `-Extend` wasn't supplied to [`Enable-PodeSessionMiddleware`](../../../../Functions/Sessions/Enable-PodeSessionMiddleware) will always have an explicit DateTime set for expiring. However, you can reset this expiry date using [`Reset-PodeSessionExpiry`](../../../../Functions/Sessions/Reset-PodeSessionExpiry), and the current session's expiry will be recalculated from now plus the specified `-Duration`:

```powershell
Start-PodeServer {
    Enable-PodeSessionMiddleware -Duration 120 -Extend

    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        # this will reset the current session's expiry to be DateTime.Now + 2mins
        Reset-PodeSessionExpiry
    }
}
```

## Example

An example of using sessions in a Route to increment a views counter could be done as follows (the counter will continue to increment on each call to the route until the session expires after 2mins):

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address localhost -Port 8080 -Protocol Http
    Enable-PodeSessionMiddleware -Duration 120

    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        $session:Views++
        Write-PodeJsonResponse -Value @{ 'Views' = $session:Views }
    }
}
```
