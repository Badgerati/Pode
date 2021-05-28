# API Key

API key authentication lets you authenticate a user based on an API key in either the header, a cookie, or in the query string.

Depending on the location, Pode looks for an API key in the default location names:

* Header: `X-API-KEY`
* Cookie: `X-API-KEY`
* Query:  `api_key`

Pode looks for the Header by default, and these can be changed as shown below.

## Setup

To setup and start using API key authentication in Pode you can use `New-PodeAuthScheme -ApiKey`, and then pipe the returned object into [`Add-PodeAuth`](../../../../Functions/Authentication/Add-PodeAuth). The parameter supplied to the [`Add-PodeAuth`](../../../../Functions/Authentication/Add-PodeAuth) function's ScriptBlock is the `$key` that Pode found in either the header, cookie or query string:

```powershell
Start-PodeServer {
    New-PodeAuthScheme -ApiKey | Add-PodeAuth -Name 'Authenticate' -ScriptBlock {
        param($key)

        # check if the key is valid, and get user

        return @{ User = $user }
    }
}
```

By default, Pode will look for an `X-API-KEY` header in the request. You can change this to Cookie or Query by using the `-Location` parameter. To change the name of what Pode looks for, you can use `-LocationName`.

For example, to look for an `appId` query value:

```powershell
Start-PodeServer {
    New-PodeAuthScheme -ApiKey -Location Query -LocationName 'appId' | Add-PodeAuth -Name 'Authenticate' -ScriptBlock {
        param($key)

        # check if the key is valid, and get user

        return @{ User = $user }
    }
}
```

If the API key can't be found, then a 401 response will be returned.

## Middleware

Once configured you can start using API key authentication to validate incoming requests. You can either configure the validation to happen on every Route as global Middleware, or as custom Route Middleware.

The following will use API key authentication to validate every request on every Route:

```powershell
Start-PodeServer {
    Add-PodeAuthMiddleware -Name 'GlobalAuthValidation' -Authentication 'Authenticate'
}
```

Whereas the following example will use API key authentication to only validate requests on specific a Route:

```powershell
Start-PodeServer {
    Add-PodeRoute -Method Get -Path '/info' -Authentication 'Authenticate' -ScriptBlock {
        # logic
    }
}
```

## Full Example

The following full example of API key authentication will setup and configure authentication, validate the key from the `X-API-KEY` header, and then validate on a specific Route:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address * -Port 8080 -Protocol Http

    # setup apikey authentication to validate a user
    New-PodeAuthScheme -ApiKey | Add-PodeAuth -Name 'Authenticate' -Sessionless -ScriptBlock {
        param($key)

        # here you'd check a real storage, this is just for example
        if ($key -eq 'test-key') {
            return @{
                User = @{
                    'ID' ='M0R7Y302'
                    'Name' = 'Morty'
                    'Type' = 'Human'
                }
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
