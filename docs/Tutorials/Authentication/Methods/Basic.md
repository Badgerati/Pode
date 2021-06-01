# Basic

Basic authentication is when you pass an encoded `username:password` value in the Authorization header of your requests:

```plain
Authorization: Basic <base64 encoded username:password>
```

## Setup

To start using Basic authentication in Pode you can use `New-PodeAuthScheme -Basic`, and then pipe the object returned into [`Add-PodeAuth`](../../../../Functions/Authentication/Add-PodeAuth). The [`Add-PodeAuth`](../../../../Functions/Authentication/Add-PodeAuth) function's ScriptBlock is supplied the username and password parsed from the Authorization header:

```powershell
Start-PodeServer {
    New-PodeAuthScheme -Basic | Add-PodeAuth -Name 'Login' -Sessionless -ScriptBlock {
        param($username, $password)

        # check if the user is valid

        return @{ User = $user }
    }
}
```

By default, Pode will check if the request's headers contains an `Authorization` key, and whether the value of that key starts with `Basic` tag. The `New-PodeAuthScheme -Basic` function can be supplied parameters to customise the tag using `-HeaderTag`, as well as the `-Encoding`.

For example, to use `ASCII` encoding rather than the default `ISO-8859-1` you could do:

```powershell
Start-PodeServer {
    New-PodeAuthScheme -Basic -Encoding 'ASCII' | Add-PodeAuth -Name 'Login' -Sessionless -ScriptBlock {}
}
```

The credentials supplied to [`Add-PodeAuth`](../../../../Functions/Authentication/Add-PodeAuth)'s scriptblock are, by default, the username and password. This can be changed to a pscredential object instead by suppling `-AsCredential` on [`New-PodeAuthScheme`](../../../../Functions/Authentication/New-PodeAuthScheme):

```powershell
Start-PodeServer {
    New-PodeAuthScheme -Basic -AsCredential | Add-PodeAuth -Name 'Login' -Sessionless -ScriptBlock {
        param($creds)

        # check if the user is valid

        return @{ User = $user }
    }
}
```

## Middleware

Once configured you can start using Basic authentication to validate incoming requests. You can either configure the validation to happen on every Route as global Middleware, or as custom Route Middleware.

The following will use Basic authentication to validate every request on every Route:

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
