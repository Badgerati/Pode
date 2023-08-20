# Overview

Authentication can either be sessionless (requiring validation on every request), or session-persistent (only requiring validation once, and then checks against a session signed-cookie/header).

!!! info
    To use session-persistent authentication you will also need to use [Session Middleware](../../Middleware/Types/Sessions).

To setup and use authentication in Pode you need to use the [`New-PodeAuthScheme`](../../../Functions/Authentication/New-PodeAuthScheme) and [`Add-PodeAuth`](../../../Functions/Authentication/Add-PodeAuth) functions.

You can also setup [Authorisation](../../Authorisation/Overview) for use with Authentication as well.

## Usage

### Schemes

The [`New-PodeAuthScheme`](../../../Functions/Authentication/New-PodeAuthScheme) function allows you to create and configure authentication schemes, or you can create your own Custom authentication schemes. These schemes can then be piped into [`Add-PodeAuth`](../../../Functions/Authentication/Add-PodeAuth). The role of a scheme is to parse the request for any user credentials, or other information, that is required for a user to be authenticated.

The following schemes are supported:

* [API Key](../Methods/ApiKey)
* [Azure AD](../Methods/AzureAD)
* [Basic](../Methods/Basic)
* [Bearer](../Methods/Bearer)
* [Client Certificate](../Methods/ClientCertificate)
* [Digest](../Methods/Digest)
* [Form](../Methods/Form)
* [JWT](../Methods/JWT) (Done using [Bearer](../Methods/Bearer) or [API Key](../Methods/ApiKey))
* [OAuth2](../Methods/OAuth2)

Or you can define a custom scheme:

* [Custom](../Methods/Custom)

### Validators

The [`Add-PodeAuth`](../../../Functions/Authentication/Add-PodeAuth) function allows you to add authentication validators to your server. You can have many methods configured, defining which one to validate against using the `-Authentication` parameter on Routes. Their job is to validate the information parsed from the supplied scheme to ensure a user is valid.

An example of using [`Add-PodeAuth`](../../../Functions/Authentication/Add-PodeAuth) for Basic sessionless authentication is as follows:

```powershell
Start-PodeServer {
    New-PodeAuthScheme -Basic | Add-PodeAuth -Name 'Login' -Sessionless -ScriptBlock {
        param($username, $pass)
        # logic to check user
        return @{ 'user' = $user }
    }
}
```

The `-Name` of the authentication method must be unique. The `-Scheme` comes from the object returned via the [`New-PodeAuthScheme`](../../../Functions/Authentication/New-PodeAuthScheme) function, and can also be piped in.

The `-ScriptBlock` is used to validate a user, checking if they exist and the password is correct (or checking if they exist in some data store). If the ScriptBlock succeeds, then a `User` object needs to be returned from the script as `@{ User = $user }`. If `$null`, or a null user, is returned then the script is assumed to have failed - meaning the user will have failed authentication, and a 401 response is returned.

#### Custom Status and Headers

When authenticating a user in Pode, any failures will return a 401 response with a generic message. You can inform Pode to return a custom message/status from [`Add-PodeAuth`](../../../Functions/Authentication/Add-PodeAuth) by returning the relevant hashtable values.

You can return a custom status code as follows:

```powershell
New-PodeAuthScheme -Basic | Add-PodeAuth -Name 'Login' -Sessionless -ScriptBlock {
    return @{ Code = 403 }
}
```

or a custom message (the status description) as follows, which can be used with a custom status code or on its own:

```powershell
New-PodeAuthScheme -Basic | Add-PodeAuth -Name 'Login' -Sessionless -ScriptBlock {
    return @{ Message = 'Custom authentication failed message' }
}
```

You can also set custom headers on the response; these will be set regardless if authentication fails or succeeds:

```powershell
New-PodeAuthScheme -Basic | Add-PodeAuth -Name 'Login' -Sessionless -ScriptBlock {
    return @{
        Headers = @{
            HeaderName = 'HeaderValue'
        }
    }
}
```

If you're defining an authenticator that needs to send back a Challenge, then you can also do this by setting the response Code property to 401, and/or by also supplying a Challenge property.
This Challenge property is a string, and will be automatically appended onto the `WWW-Authenticate` Header. It *does not* need to include the Authentication Type or Realm (these will be added for you).

For example, in Digest you could return:

```powershell
return @{
    Code = 401
    Challenge = 'qop="auth", nonce="<some-random-guid>"'
}
```

#### Authenticate Type/Realm

When authentication fails, and a 401 response is returned, then Pode will also attempt to Response back to the client with a `WWW-Authenticate` header (if you've manually set this header using the custom headers from above, then the custom header will be used instead). For the inbuilt types, such as Basic, this Header will always be returned on a 401 response.

You can set the `-Name` and `-Realm` of the header using the [`New-PodeAuthScheme`](../../../Functions/Authentication/New-PodeAuthScheme) function. If no Name is supplied, then the header will not be returned - also if there is no Realm, then this will not be added onto the header.

For example, if you setup Basic authenticate with a custom Realm as follows:

```powershell
New-PodeAuthScheme -Basic -Realm 'Enter creds to access site'
```

Then on a 401 response the `WWW-Authenticate` header will look as follows:

```plain
WWW-Authenticate: Basic realm="Enter creds to access site"
```

!!! note
    If no Realm was set then it would just look as follows: `WWW-Authenticate: Basic`

#### Redirecting

When building custom authenticators, it might be required that you have to redirect mid-auth and stop processing the current request. To achieve this you can return the following from the scriptblock of `New-PodeAuthScheme` or `Add-PodeAuth`:

```powershell
return @{ IsRedirected = $true }
```

### Routes/Middleware

To use an authentication on a specific route, you can use the `-Authentication` parameter on the [`Add-PodeRoute`](../../../Functions/Routes/Add-PodeRoute) function; this takes the Name supplied to the `-Name` parameter on [`Add-PodeAuth`](../../../Functions/Authentication/Add-PodeAuth). This will set the authentication up to run before other route middleware.

An example of using some Basic authentication on a REST API route is as follows:

```powershell
Start-PodeServer {
    Add-PodeRoute -Method Get -Path '/api/users' -Authentication 'BasicAuth' -ScriptBlock {
        # route logic
    }
}
```

The [`Add-PodeAuthMiddleware`](../../../Functions/Authentication/Add-PodeAuthMiddleware) function lets you setup authentication as global middleware - so it will run against all routes.

An example of using some Basic authentication on all REST API routes is as follows:

```powershell
Start-PodeServer {
    Add-PodeAuthMiddleware -Name 'GlobalAuth' -Authentication 'BasicAuth' -Route '/api/*'
}
```

If any of the authentication middleware fails, then a 401 response is returned for the route. On success, it will allow the Route logic to be invoked. If Session Middleware has been configured then an authenticated session is also created for future requests, using a signed session cookie/header.

When the user makes another call using the same authenticated session and that cookie/header is present, then the authentication middleware will detect the already authenticated session and skip validation. If you're using sessions and you don't want to check the session, or store the user against a session, then use the `-Sessionless` switch on [`Add-PodeAuth`](../../../Functions/Authentication/Add-PodeAuth).

## Users

After successful validation, an `Auth` object will be created for use against the current [web event](../../WebEvent). This `Auth` object will be accessible via the argument supplied to Routes and Middleware.

The `Auth` object will also contain:

| Name | Description |
| ---- | ----------- |
| User | Details about the authenticated user |
| IsAuthenticated | States if the request is for an authenticated user, can be `$true`, `$false` or `$null` |
| Store | States whether the authentication is for a session, and will be stored as a cookie |
| IsAuthorised | If using [Authorisation](../../Authorisation/Overview), this value will be `$true` or `$false` depending on whether or not the authenticated user is authorised to access the Route. If not using Authorisation this value will just be `$true` |
| Access | If using [Authorisation](../../Authorisation/Overview), this property will contain the access values for the User per Access method. If not using Authorisation this value will just be an empty hashtable |

The following example get the user's name from the `Auth` object:

```powershell
Add-PodeRoute -Method Get -Path '/' -Authentication 'Login' -Login -ScriptBlock {
    Write-PodeViewResponse -Path 'index' -Data @{
        'Username' = $WebEvent.Auth.User.Name
    }
}
```

## Inbuilt Authenticators

Overtime Pode will start to support inbuilt authentication methods - such as [Windows Active Directory](../Inbuilt/WindowsAD). More information can be found in the Inbuilt section.

For example, the below would use the inbuilt Windows AD authentication method:

```powershell
Start-PodeServer {
    New-PodeAuthScheme -Basic | Add-PodeAuthWindowsAd -Name 'Login'
}
```
