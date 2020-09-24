# Client Certificate

Client Certificate Authentication is when the server requires the client to supply a certificate on the request, to verify themselves with the server. This only works over HTTPS connections.

## Setup

To setup and start using Client Certificate Authentication in Pode you use the `New-PodeAuthScheme -ClientCertificate` function, and then pipe this into the [`Add-PodeAuth`](../../../../Functions/Authentication/Add-PodeAuth) function. The [`Add-PodeAuth`](../../../../Functions/Authentication/Add-PodeAuth) function's ScriptBlock is supplied the client's certificate, and any SSL errors that may have occurred (like chain issues, etc).

You will also need to supply `-AllowClientCertificate` to [`Add-PodeEndpoint`], and ensure the `-Protocol` is HTTPS:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address * -Port 8443 -Protocol Https -SelfSigned -AllowClientCertificate

    New-PodeAuthScheme -ClientCertificate | Add-PodeAuth -Name 'Login' -Sessionless -ScriptBlock {
        param($cert, $errors)

        # check if the client's cert is valid

        return @{ User = $user }
    }
}
```

By default, Pode will ensure a certificate was supplied, and also ensure the certificate's Before/After dates are valid - if not, a 401 response will be returned.

## Middleware

Once configured you can start using Client Certificate Authentication to validate incoming Requests. You can either configure the validation to happen on every Route as global Middleware, or as custom Route Middleware.

The following will use Client Certificate Authentication to validate every request on every Route:

```powershell
Start-PodeServer {
    Add-PodeAuthMiddleware -Name 'GlobalAuthValidation' -Authentication 'Login'
}
```

Whereas the following example will use Client Certificate authentication to only validate requests on specific a Route:

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
    Add-PodeEndpoint -Address * -Port 8443 -Protocol Https -SelfSigned -AllowClientCertificate

    # setup client cert authentication to validate a user
    New-PodeAuthScheme -ClientCertificate | Add-PodeAuth -Name 'Login' -Sessionless -ScriptBlock {
        param($cert, $errors)

        # validate the thumbprint - here you would check a real cert store, or database
        if ($cert.Thumbprint -ieq '3571B3BE3CA202FA56F73691FC258E653D0874C1') {
            return @{
                User = @{
                    ID ='M0R7Y302'
                    Name = 'Morty'
                    Type = 'Human'
                }
            }
        }

        # an invalid cert
        return @{ Message = 'Invalid certificate supplied' }
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
