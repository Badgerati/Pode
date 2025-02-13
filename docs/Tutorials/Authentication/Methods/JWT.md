# Bearer

Bearer authentication lets you authenticate a user based on a token, with optional support for scopes:

```plain
Authorization: Bearer <token>
```

!!! note
     `New-PodeAuthScheme` with the param `-Bearer` has been deprecated. Please use `New-PodeAuthBearerScheme`.

## Setup

To start using Bearer authentication in Pode, use `New-PodeAuthBearerScheme`, and then pipe the returned object into [`Add-PodeAuth`](../../../../Functions/Authentication/Add-PodeAuth). The parameter supplied to the [`Add-PodeAuth`](../../../../Functions/Authentication/Add-PodeAuth) function's ScriptBlock is the `$token` from the Authorization token:

```powershell
Start-PodeServer {
    New-PodeAuthBearerScheme | Add-PodeAuth -Name 'Authenticate' -Sessionless -ScriptBlock {
        param($token)

        # check if the token is valid, and get user

        return @{ User = $user }
    }
}
```

By default, Pode will check if the request's header contains an `Authorization` key, and whether the value of that key starts with the `Bearer` tag. The `New-PodeAuthBearerScheme` function can be supplied parameters to customize the tag using `-HeaderTag`. You can also change the location to Query by using the `-Location` parameter.

For example, to look for a bearer token in a query parameter:

```powershell
Start-PodeServer {
    New-PodeAuthBearerScheme -Location Query | Add-PodeAuth -Name 'Authenticate' -Sessionless -ScriptBlock {
        param($token)

        # check if the token is valid, and get user

        return @{ User = $user }
    }
}
```

**Note:** Per [RFC 6750](https://datatracker.ietf.org/doc/html/rfc6750), using the Authorization header is the recommended method for sending bearer tokens. Query parameters should only be used when headers are not feasible, as query strings may be logged in URLs, potentially exposing sensitive information.

### JWT Support

`New-PodeAuthBearerScheme` now includes support for JWT authentication with various security levels and algorithms. You can configure JWT validation using parameters such as `-AsJWT`, `-Algorithm`, `-Secret`, `-PublicKey`, and `-JwtVerificationMode`.

#### JwtVerificationMode

The `-JwtVerificationMode` parameter defines how aggressively JWT claims should be checked:

- `Strict`: Requires all standard claims to be valid (`exp`, `nbf`, `iat`, `iss`, `aud`, `jti`).
- `Moderate`: Allows missing `iss` and `aud` but still checks expiration.
- `Lenient`: Ignores missing `iss` and `aud`, only verifies `exp`, `nbf`, and `iat`.

Example using an HMAC JWT validation:

```powershell
Start-PodeServer {
    New-PodeAuthBearerScheme -AsJWT -Algorithm 'HS256' -Secret (ConvertTo-SecureString "MySecretKey" -AsPlainText -Force) -JwtVerificationMode 'Strict' |
        Add-PodeAuth -Name 'Authenticate' -Sessionless -ScriptBlock {
            param($token)

            # validate and decode JWT, then extract user details

            return @{ User = $user }
        }
}
```

Example using RSA for JWT validation:

```powershell
Start-PodeServer {
    $privateKey = Get-Content "private.pem" -Raw | ConvertTo-SecureString -AsPlainText -Force
    $publicKey = Get-Content "public.pem" -Raw

    New-PodeAuthBearerScheme -AsJWT -Algorithm 'RS256' -PrivateKey $privateKey -PublicKey $publicKey -JwtVerificationMode 'Moderate' |
        Add-PodeAuth -Name 'Authenticate' -Sessionless -ScriptBlock {
            param($token)

            # validate JWT and extract user

            return @{ User = $user }
        }
}
```

### Scope Validation

You can optionally return a `Scope` property alongside the `User`. If you specify any scopes with `New-PodeAuthBearerScheme`, they will be validated in the Bearer's post validator. A 403 will be returned if the scope is invalid.

```powershell
Start-PodeServer {
    New-PodeAuthBearerScheme -Scope 'write' | Add-PodeAuth -Name 'Authenticate' -Sessionless -ScriptBlock {
        param($token)

        # check if the token is valid, and get user

        return @{ User = $user; Scope = 'read' }
    }
}
```

## Middleware

Once configured, you can start using Bearer authentication to validate incoming requests. You can either configure the validation to happen on every Route as global Middleware or as custom Route Middleware.

The following will use Bearer authentication to validate every request on every Route:

```powershell
Start-PodeServer {
    Add-PodeAuthMiddleware -Name 'GlobalAuthValidation' -Authentication 'Authenticate'
}
```

Whereas the following example will use Bearer authentication to only validate requests on a specific Route:

```powershell
Start-PodeServer {
    Add-PodeRoute -Method Get -Path '/info' -Authentication 'Authenticate' -ScriptBlock {
        # logic
    }
}
```

## Full Example

The following full example of Bearer authentication will set up and configure authentication, validate the token, and then validate on a specific Route:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address * -Port 8080 -Protocol Http

    # setup bearer authentication to validate a user
    New-PodeAuthBearerScheme -AsJWT -Algorithm 'HS256' -Secret (ConvertTo-SecureString "MySecretKey" -AsPlainText -Force) -JwtVerificationMode 'Lenient' |
        Add-PodeAuth -Name 'Authenticate' -Sessionless -ScriptBlock {
            param($token)

            # here you'd check a real storage, this is just for example
            if ($token -eq 'test-token') {
                return @{
                    User = @{
                        'ID' = 'M0R7Y302'
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

