# Basic

Basic Authentication is when you pass an encoded `username:password` value on the header of your requests: `@{ 'Authorization' = 'Basic <base64 encoded username:password>' }`.

## Setup

To setup and start using Basic Authentication in Pode you use the `New-PodeAuthScheme -Basic` function, and then pipe this into the [`Add-PodeAuth`](../../../../Functions/Authentication/Add-PodeAuth) function. The [`Add-PodeAuth`](../../../../Functions/Authentication/Add-PodeAuth) function's ScriptBlock is supplied the username and password:

```powershell
Start-PodeServer {
    New-PodeAuthScheme -Basic | Add-PodeAuth -Name 'Login' -Sessionless -ScriptBlock {
        param($username, $password)

        # check if the user is valid

        return @{ User = $user }
    }
}
```

By default, Pode will check if the Request's header contains an `Authorization` key, and whether the value of that key starts with `Basic`. The `New-PodeAuthScheme -Basic` function can be supplied parameters to customise this name, as well as the encoding.

For example, to use `ASCII` encoding rather than the default `ISO-8859-1` you could do:

```powershell
Start-PodeServer {
    New-PodeAuthScheme -Basic -Encoding 'ASCII' | Add-PodeAuth -Name 'Login' -ScriptBlock {}
}
```

## Middleware

Once configured you can start using Basic Authentication to validate incoming Requests. You can either configure the validation to happen on every Route as global Middleware, or as custom Route Middleware.

The following will use Basic Authentication to validate every request on every Route:

```powershell
Start-PodeServer {
    Add-PodeAuthMiddleware -Name 'GlobalAuthValidation' -Authentication 'Login'
}
```

Whereas the following example will use Basic authentication to only validate requests on specific a Route:

```powershell
Start-PodeServer {
    Add-PodeRoute -Method Get -Path '/info' -Authentication 'Login' -ScriptBlock {
        # logic
    }
}
```

## Full Example

The following full example of Basic authentication will setup and configure authentication, validate that a users username/password is valid, and then validate on a specific Route:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address * -Port 8080 -Protocol Http

    # setup basic authentication to validate a user
    New-PodeAuthScheme -Basic | Add-PodeAuth -Name 'Login' -Sessionless -ScriptBlock {
        param($username, $password)

        # here you'd check a real user storage, this is just for example
        if ($username -eq 'morty' -and $password -eq 'pickle') {
            return @{
                User = @{
                    'ID' ='M0R7Y302'
                    'Name' = 'Morty';
                    'Type' = 'Human';
                }
            }
        }

        # authentication failed
        return $null
    }

    # check the request on this route against the authentication
    Add-PodeRoute -Method Get -Path '/cpu' -Authentication 'Login' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ 'cpu' = 82 }
    }

    # this route will not be validated against the authentication
    Add-PodeRoute -Method Get -Path '/memory' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ 'memory' = 14 }
    }
}
```
