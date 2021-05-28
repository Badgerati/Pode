# Bearer

Bearer authentication lets you authenticate a user based on a token, with optional support for scopes.

## Setup

To setup and start using Bearer authentication in Pode you use the `New-PodeAuthScheme -Bearer` function, and then pipe this into the [`Add-PodeAuth`](../../../../Functions/Authentication/Add-PodeAuth) function. The parameter supplied to the [`Add-PodeAuth`](../../../../Functions/Authentication/Add-PodeAuth) function's ScriptBlock is the `$token`:

```powershell
Start-PodeServer {
    New-PodeAuthScheme -Bearer | Add-PodeAuth -Name 'Authenticate' -ScriptBlock {
        param($token)

        # check if the token is valid, and get user

        return @{ User = $user }
    }
}
```

By default, Pode will check if the Request's header contains an `Authorization` key, and whether the value of that key starts with `Bearer` tag. The `New-PodeAuthScheme -Bearer` function can be supplied parameters to customise the tag using `-HeaderTag`.

You can also optionally return a `Scope` property alongside the `User`. If you specify any scopes with [`New-PodeAuthScheme`](../../../../Functions/Authentication/New-PodeAuthScheme) then it will be validated in the Bearer's post validator - a 403 will be returned if the scope is invalid.

```powershell
Start-PodeServer {
    New-PodeAuthScheme -Bearer -Scope 'write' | Add-PodeAuth -Name 'Authenticate' -ScriptBlock {
        param($token)

        # check if the token is valid, and get user

        return @{ User = $user; Scope = 'read' }
    }
}
```

## Middleware

Once configured you can start using Bearer authentication to validate incoming Requests. You can either configure the validation to happen on every Route as global Middleware, or as custom Route Middleware.

The following will use Bearer authentication to validate every request on every Route:

```powershell
Start-PodeServer {
    Add-PodeAuthMiddleware -Name 'GlobalAuthValidation' -Authentication 'Authenticate'
}
```

Whereas the following example will use Bearer authentication to only validate requests on specific a Route:

```powershell
Start-PodeServer {
    Add-PodeRoute -Method Get -Path '/info' -Authentication 'Authenticate' -ScriptBlock {
        # logic
    }
}
```

## Full Example

The following full example of Bearer authentication will setup and configure authentication, validate the token, and then validate on a specific Route:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address * -Port 8080 -Protocol Http

    # setup bearer authentication to validate a user
    New-PodeAuthScheme -Bearer | Add-PodeAuth -Name 'Authenticate' -Sessionless -ScriptBlock {
        param($token)

        # here you'd check a real storage, this is just for example
        if ($token -eq 'test-token') {
            return @{
                User = @{
                    'ID' ='M0R7Y302'
                    'Name' = 'Morty'
                    'Type' = 'Human'
                }
                # Scope = 'read'
            }
        }

        # authentication failed
        return $null
    }

    # check the request on this route against the authentication
    Add-PodeRoute -Method Get -Path '/cpu' -Authentication 'Authenticate' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ 'cpu' = 82 }
    }

    # this route will not be validated against the authentication
    Add-PodeRoute -Method Get -Path '/memory' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ 'memory' = 14 }
    }
}
```
