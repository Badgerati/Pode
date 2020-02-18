# Bearer

Bearer Authentication lets you authenticate a user based on a token, with optional support for scopes.

## Setup

To setup and start using Bearer Authentication in Pode you use the `New-PodeAuthType -Bearer` function, and then pipe this into the [`Add-PodeAuth`](../../../../Functions/Authentication/Add-PodeAuth) function. The parameter supplied to the [`Add-PodeAuth`](../../../../Functions/Authentication/Add-PodeAuth) function's ScriptBlock is the `$token`:

```powershell
Start-PodeServer {
    New-PodeAuthType -Bearer | Add-PodeAuth -Name 'Authenticate' -ScriptBlock {
        param($token)

        # check if the token is valid, and get user

        return @{ User = $user }
    }
}
```

By default, Pode will check if the Request's header contains an `Authorization` key, and whether the value of that key starts with `Bearer`.

You can also optionally return a `Scope` property alongside the `User`. If you specify any scopes with [`New-PodeAuthType`](../../../../Functions/Authentication/New-PodeAuthType) then it will be validated in the Bearer's post validator - a 403 will be returned if the scope is invalid.

```powershell
Start-PodeServer {
    New-PodeAuthType -Bearer -Scope 'write' | Add-PodeAuth -Name 'Authenticate' -ScriptBlock {
        param($token)

        # check if the token is valid, and get user

        return @{ User = $user; Scope = 'read' }
    }
}
```

## Middleware

Once configured you can start using Bearer Authentication to validate incoming Requests. You can either configure the validation to happen on every Route as global Middleware, or as custom Route Middleware.

The following will use Bearer Authentication to validate every request on every Route:

```powershell
Start-PodeServer {
    Get-PodeAuthMiddleware -Name 'Authenticate' | Add-PodeMiddleware -Name 'GlobalAuthValidation'
}
```

Whereas the following example will use Bearer authentication to only validate requests on specific a Route:

```powershell
Start-PodeServer {
    Add-PodeRoute -Method Get -Path '/info' -Middleware (Get-PodeAuthMiddleware -Name 'Authenticate') -ScriptBlock {
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
    New-PodeAuthType -Bearer | Add-PodeAuth -Name 'Authenticate' -ScriptBlock {
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
    Add-PodeRoute -Method Get -Path '/cpu' -Middleware (Get-PodeAuthMiddleware -Name 'Authenticate') -ScriptBlock {
        Write-PodeJsonResponse -Value @{ 'cpu' = 82 }
    }

    # this route will not be validated against the authentication
    Add-PodeRoute -Method Get -Path '/memory' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ 'memory' = 14 }
    }
}
```
