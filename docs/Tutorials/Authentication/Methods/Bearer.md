# Bearer

Bearer authentication lets you authenticate a user based on a token, with optional support for scopes:

```plain
Authorization: Bearer <token>
```

!!! note
    **`New-PodeAuthScheme -Bearer` is deprecated.** Please use **`New-PodeAuthBearerScheme`**.

## Setup

To start using Bearer authentication in Pode, call **`New-PodeAuthBearerScheme`**, and then pipe the returned object into [`Add-PodeAuth`](../../../../Functions/Authentication/Add-PodeAuth). The parameter supplied to the [`Add-PodeAuth`](../../../../Functions/Authentication/Add-PodeAuth) function's **ScriptBlock** is the `$token` from the Authorization header.

```powershell
Start-PodeServer {
    New-PodeAuthBearerScheme | Add-PodeAuth -Name 'Authenticate' -Sessionless -ScriptBlock {
        param($token)

        # check if the token is valid, and get user

        return @{ User = $user }
    }
}
```

By default, Pode will look for a token in the **`Authorization`** header, verifying that it starts with the **`Bearer`** tag. You can customize this tag via **`-HeaderTag`**. You can also change the token extraction location to the **query string** using **`-Location Query`**. For the **`-Location query`** the standard tag is **`access_token`**:

```powershell
Start-PodeServer {
    New-PodeAuthBearerScheme -Location Query | Add-PodeAuth -Name 'Authenticate' -Sessionless -ScriptBlock {
        param($token)

        # check if the token is valid, and get user

        return @{ User = $user }
    }
}
```

**Note:** Per [RFC 6750](https://datatracker.ietf.org/doc/html/rfc6750), using the Authorization header is recommended for sending bearer tokens. Query parameters should only be used when headers are not feasible, as query strings may be logged in URLs, potentially exposing sensitive information.

## JWT Support

`New-PodeAuthBearerScheme` supports **JWT authentication** with various security levels and algorithms. Set **`-AsJWT`** to enable JWT validation. Depending on the chosen algorithm, you can specify:

- **HMAC**-based secret keys (`-Secret`)
- **Certificate**-based parameters (`-Certificate`, `-CertificateThumbprint`, `-CertificateName`, `-X509Certificate`, `-SelfSigned`)
- The **RSA padding scheme** (`-RsaPaddingScheme`)
- The **JWT verification mode** (`-JwtVerificationMode`)

### JwtVerificationMode

Defines how aggressively JWT claims should be checked:

- **Strict**: Requires all standard claims:
  - `exp` (Expiration Time)
  - `nbf` (Not Before)
  - `iat` (Issued At)
  - `iss` (Issuer)
  - `aud` (Audience)
  - `jti` (JWT ID)

- **Moderate**: Allows missing `iss` (Issuer) and `aud` (Audience) but still checks expiration (`exp`).
- **Lenient**: Ignores missing `iss` and `aud`, only verifies expiration (`exp`), not-before (`nbf`), and issued-at (`iat`).

### HMAC Example

Here’s an example using **HMAC** (HS256) JWT validation:

```powershell
Start-PodeServer {
    New-PodeAuthBearerScheme `
        -AsJWT `
        -Algorithm 'HS256' `
        -Secret (ConvertTo-SecureString "MySecretKey" -AsPlainText -Force) `
        -JwtVerificationMode 'Strict' |
    Add-PodeAuth -Name 'Authenticate' -Sessionless -ScriptBlock {
        param($token)

        # validate and decode JWT, then extract user details

        return @{ User = $user }
    }
}
```

### Certificate-Based Example

For **RSA/ECDSA** JWT validation, you can specify a **certificate** or **thumbprint** instead of a secret key. Pode will infer the appropriate signing algorithms (e.g., RS256, ES256) from the certificate. For instance, using a local **PFX** certificate file:

```powershell
Start-PodeServer {
    New-PodeAuthBearerScheme `
        -AsJWT `
        -Algorithm 'RS256' `
        -Certificate "C:\path\to\cert.pfx" `
        -CertificatePassword (ConvertTo-SecureString "CertPass" -AsPlainText -Force) `
        -JwtVerificationMode 'Moderate' |
    Add-PodeAuth -Name 'Authenticate' -Sessionless -ScriptBlock {
        param($token)

        # validate JWT and extract user

        return @{ User = $user }
    }
}
```

### Self-Signed Certificate Example

For testing purposes or internal deployments, you can use the **`-SelfSigned`** parameter, which automatically generates an **ephemeral self-signed ECDSA certificate** (ES384) for JWT signing. This avoids the need to manually create and manage certificate files.

#### Example:

```powershell
Start-PodeServer {
    New-PodeAuthBearerScheme `
        -AsJWT `
        -SelfSigned |
    Add-PodeAuth -Name 'Authenticate' -Sessionless -ScriptBlock {
        param($token)

        # validate JWT and extract user

        return @{ User = $user }
    }
}
```

This is equivalent to manually generating a self-signed ECDSA certificate and passing it via `-X509Certificate`:

```powershell
Start-PodeServer {
    $x509Certificate = New-PodeSelfSignedCertificate `
        -CommonName 'JWT Signing Certificate' `
        -KeyType ECDSA `
        -KeyLength 384 `
        -CertificatePurpose CodeSigning `
        -Ephemeral

    New-PodeAuthBearerScheme `
        -AsJWT `
        -X509Certificate $x509Certificate |
    Add-PodeAuth -Name 'Authenticate' -Sessionless -ScriptBlock {
        param($token)

        # validate JWT and extract user

        return @{ User = $user }
    }
}
```

Using `-SelfSigned` simplifies setup by automatically handling certificate creation and disposal, making it a convenient choice for local development and testing scenarios.

## Scope Validation

You can optionally include `-Scope` when creating the scheme. Pode will validate any returned `Scope` from your auth **ScriptBlock** against the scheme’s required scopes. If the scope is invalid, Pode will return 403 (Forbidden).

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

Once configured, you can instruct Pode to validate every request with Bearer authentication by using **Global Middleware**, or you can require it on individual Routes.

**Global Middleware Example** – Validate **every** incoming request:

```powershell
Start-PodeServer {
    Add-PodeAuthMiddleware -Name 'GlobalAuthValidation' -Authentication 'Authenticate'
}
```

**Route-Specific Example** – Validate only on a certain Route:

```powershell
Start-PodeServer {
    Add-PodeRoute -Method Get -Path '/info' -Authentication 'Authenticate' -ScriptBlock {
        # logic
    }
}
```

## Full Example

Below is a complete example demonstrating Bearer authentication with JWT. It configures a server, sets up JWT validation with a shared secret, and validates requests on one route (`/cpu`) while leaving another (`/memory`) open:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address * -Port 8080 -Protocol Http

    # Setup Bearer authentication to validate a user via JWT
    New-PodeAuthBearerScheme -AsJWT -Algorithm 'HS256' -Secret (ConvertTo-SecureString "MySecretKey" -AsPlainText -Force) -JwtVerificationMode 'Lenient' |
        Add-PodeAuth -Name 'Authenticate' -Sessionless -ScriptBlock {
            param($token)

            # Example: in real usage, you would decode/verify the JWT fully
            if ($token -eq 'test-token') {
                return @{
                    User = @{
                        'ID'   = 'M0R7Y302'
                        'Name' = 'Morty'
                        'Type' = 'Human'
                    }
                    # Scope = 'read'
                }
            }

            # authentication failed
            return $null
        }

    # Validate against the authentication on this route
    Add-PodeRoute -Method Get -Path '/cpu' -Authentication 'Authenticate' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ 'cpu' = 82 }
    }

    # Open route, no auth required
    Add-PodeRoute -Method Get -Path '/memory' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ 'memory' = 14 }
    }
}
