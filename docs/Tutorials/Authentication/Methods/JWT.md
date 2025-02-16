
## Create a JWT

Pode provides a [`ConvertTo-PodeJwt`](../../../../Functions/Authentication/ConvertTo-PodeJwt) command that builds and signs a JWT for you. You can provide:

- **`-Header`**: A hashtable defining fields like `alg`, `typ`, etc.
- **`-Payload`**: A hashtable for JWT claims (e.g., `sub`, `exp`, `nbf`, and other custom claims).
- **`-Secret`**/**`-Certificate`**/**`-CertificateThumbprint`**, etc.: If you want to sign the JWT (for HS*, RS*, ES*, PS* algorithms).
- **`-IgnoreSignature`**: If you want a token with no signature (alg = none).
- **`-Authentication`**: To reference an existing named authentication scheme, automatically pulling its parameters (algorithm, secret, certificate, etc.) so the generated JWT is recognized by that scheme.

### Using `-Authentication`

If you have already set up an authentication scheme, for instance:

```powershell
New-PodeAuthBearerScheme -AsJWT -Algorithm 'RS256' -Certificate 'C:\path\to\cert.pfx' -CertificatePassword (ConvertTo-SecureString "CertPass" -AsPlainText -Force) |
    Add-PodeAuth -Name 'ExampleApiKeyCert'
```

then you can **reuse** this scheme’s configuration when creating a token by calling:

```powershell
$jwt = ConvertTo-PodeJwt -Authentication 'ExampleApiKeyCert'

# e.g., return the new JWT to a client
Write-PodeJsonResponse -StatusCode 200 -Value @{ jwt_token = $jwt }
```

Pode automatically looks up the **`ExampleApiKeyCert`** auth scheme, retrieves its signing algorithm and key/certificate, and uses those to generate a valid JWT. This ensures that the JWT you create can later be **decoded and verified** by the same auth scheme without having to re-specify all parameters (secret, certificate, etc.).

### Example

Below is a short example of how you might implement a **login** route that returns a signed JWT:

```powershell
Add-PodeRoute -Method Post -Path '/user/login' -ScriptBlock {
    param()

    # In a real scenario, you'd validate the incoming credentials from $WebEvent.data
    $username = $WebEvent.Data['username']
    $password = $WebEvent.Data['password']

    # If valid, generate a JWT that matches the 'ExampleApiKeyCert' scheme
    $jwt = ConvertTo-PodeJwt -Authentication 'ExampleApiKeyCert'

    Write-PodeJsonResponse -StatusCode 200 -Value @{ jwt_token = $jwt }
}
```

In this example, the **`-Authentication`** parameter ensures Pode uses the RS256 certificate-based configuration already defined by the `ExampleApiKeyCert` auth scheme, producing a token that is verifiable by that same scheme on future requests.

---

### Customizing the Header/Payload

When generating a JWT using **`ConvertTo-PodeJwt`**, you can specify parameters that either:

1. **Manually** define the header/payload using `-Header` and `-Payload`, or
2. **Automatically** set standard claims via shortcut parameters like `-Expiration`, `-Issuer`, `-Audience`, etc.

You can also combine these approaches—Pode merges everything into the final token unless you use **`-NoStandardClaims`** to disable automatic claims.

Below are the **primary parameters** you can pass to **`ConvertTo-PodeJwt`**:

#### Header and Payload

- **`-Header`**: A hashtable for JWT header fields (e.g., `alg`, `typ`).
- **`-Payload`**: A hashtable for arbitrary/custom claims (e.g., `role`, `scope`, etc.).
- **`-NoStandardClaims`**: If specified, **no** standard claims are auto-generated (e.g., no `exp`, `nbf`, `iat`, etc.). This is useful if you want full control over claims in `-Payload`.

#### Standard Claims Parameters

These automatically populate or override common JWT claims:

- **`-Expiration`** (`int`, default 3600)
  - Sets the `exp` (expiration time) to the current time + `Expiration` (in seconds).
  - For example, **3600** means `exp` = now + 1 hour.

- **`-NotBefore`** (`int`, default 0)
  - Sets the `nbf` (not-before) to current time + `NotBefore` (in seconds).
  - **0** = immediate validity; **60** = valid 1 minute from now, etc.

- **`-IssuedAt`** (`int`, default 0)
  - Sets the `iat` (issued-at) time.
  - **0** means “use current time.” Any other integer is added to the current time as seconds.

- **`-Issuer`** (`string`)
  - Sets the `iss` (issuer) claim, e.g. `"auth.example.com"`.

- **`-Subject`** (`string`)
  - Sets the `sub` (subject) claim, e.g. `"user123"`.

- **`-Audience`** (`string`)
  - Sets the `aud` (audience) claim, e.g. `"myapi.example.com"`.

- **`-JwtId`** (`string`)
  - Sets the `jti` (JWT ID) claim, a unique identifier for the token.

If you **also** supply the same claims in your `-Payload` hashtable, Pode typically defers to your explicit claim unless **`-NoStandardClaims`** is omitted, in which case these parameters can overwrite the payload-based claims.

---

### Example Usage

Below is an example that **automatically** sets standard claims for expiration (1 hour from now), not-before (starts immediately), and an issuer, while also providing a custom header/payload:

```powershell
$header = @{
    alg = 'HS256'
    typ = 'JWT'
}

$payload = @{
    role = 'admin'
    customClaim = 'someValue'
}

$jwt = ConvertTo-PodeJwt `
    -Header $header `
    -Payload $payload `
    -Secret 'SuperSecretKey' `
    -Expiration 3600 `
    -NotBefore 0 `
    -Issuer 'auth.example.com' `
    -Subject 'user123' `
    -Audience 'myapi.example.com' `
    -JwtId 'unique-token-id'

Write-PodeJsonResponse -Value @{ token = $jwt }
```

This produces a JWT that includes:

- A header with `alg = HS256`, `typ = JWT`.
- Standard claims: `exp`, `nbf`, `iat`, `iss`, `sub`, `aud`, `jti`.
- Custom claims: `role`, `customClaim`.

If you **don’t** want Pode to generate any standard claims at all (perhaps you want to define everything in `-Payload` yourself), include **`-NoStandardClaims`**:

```powershell
$jwt = ConvertTo-PodeJwt -NoStandardClaims -Payload @{ sub='user123'; customKey='abc' } -Secret 'SuperSecretKey'
```

No `exp`, `nbf`, or `iat` will be automatically added.

Similarly, if you have a named scheme:

```powershell
New-PodeAuthBearerScheme -AsJWT -Algorithm 'RS256' -Certificate 'C:\cert.pfx' -CertificatePassword (ConvertTo-SecureString "CertPass" -AsPlainText -Force) |
    Add-PodeAuth -Name 'ExampleApiKeyCert'

Add-PodeRoute -Method Post -Path '/login' -ScriptBlock {
    $jwt = ConvertTo-PodeJwt `
        -Authentication 'ExampleApiKeyCert' `
        -Issuer 'auth.example.com' `
        -Expiration 3600 `
        -Subject 'user123'

    Write-PodeJsonResponse -Value @{ token = $jwt }
}
```

Here, Pode automatically applies the RS256 certificate from **`ExampleApiKeyCert`** and merges your standard-claims parameters, producing a token recognized by that same scheme upon verification.
