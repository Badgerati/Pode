# Create a JWT

Pode provides a [`ConvertTo-PodeJwt`](../../../../Functions/Authentication/ConvertTo-PodeJwt) command that builds and signs a JWT for you. You can provide:

- **`-Header`**: A hashtable defining fields like `alg`, `typ`, etc.
- **`-Payload`**: A hashtable for JWT claims (e.g., `sub`, `exp`, `nbf`, and other custom claims).
- **`-Secret`**/**`-Certificate`**/**`-CertificateThumbprint`**, etc.: If you want to sign the JWT (for HS*, RS*, ES*, PS* algorithms).
- **`-IgnoreSignature`**: If you want a token with no signature (alg = none).
- **`-Authentication`**: To reference an existing named authentication scheme, automatically pulling its parameters (algorithm, secret, certificate, etc.) so the generated JWT is recognized by that scheme.

## Customizing the Header/Payload

When generating a JWT using **`ConvertTo-PodeJwt`**, you can specify parameters that either:

1. **Manually** define the header/payload using `-Header` and `-Payload`, or
2. **Automatically** set standard claims via shortcut parameters like `-Expiration`, `-Issuer`, `-Audience`, etc.

You can also combine these approaches—Pode merges everything into the final token unless you use **`-NoStandardClaims`** to disable automatic claims.

Below are the **primary parameters** you can pass to **`ConvertTo-PodeJwt`**:

### Header and Payload

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

## Using `-Authentication`

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


Below is an **updated JWT Lifecycle guide** for Pode, clarifying that **Pode automatically validates the token** when you attach `-Authentication` to a route, and that **`ConvertFrom-PodeJwt`** is generally used for **inspecting** or **debugging** token contents.


## Managing the JWT Lifecycle in Pode

In many scenarios, you need more than just generating JWTs—you also need endpoints or logic for **renewing** and **inspecting** tokens. Pode’s built-in commands and authentication features enable these patterns quickly:

1. **Creating a JWT**: Use [`ConvertTo-PodeJwt`](https://github.com/Badgerati/Pode/blob/develop/Functions/Authentication/ConvertTo-PodeJwt.ps1) to build and sign a JWT.
2. **Automatic Validation**: Rely on Pode’s bearer auth if a route uses `-Authentication 'YourBearerScheme'`.
3. **Decoding/Inspecting a JWT**: Use `ConvertFrom-PodeJwt` if you want to explicitly decode the JWT for debugging or extracting claims.
4. **Renewing/Extending a JWT**: Use `Update-PodeJwt` to reissue a token with a new expiration.

## 1. Creating a JWT

See the [“Create a JWT” guide](#create-a-jwt) for details on using `ConvertTo-PodeJwt`. You can:

- Define a scheme in Pode (e.g., `Bearer_JWT_ES512`) that holds your algorithm and certificates/secrets.
- Generate tokens by referencing `-Authentication 'Bearer_JWT_ES512'`.
- Optionally set custom claims, expiration, issuer, etc.

This creation step often happens inside a **login** route, as shown in the example below:

```powershell
function Test-User {
    param($username, $password)
    if ($username -eq 'morty' -and $password -eq 'pickle') {
        return @{
            Id       = 'M0R7Y302'
            Username = 'morty.smith'
            Name     = 'Morty Smith'
            Groups   = 'Domain Users'
        }
    }
    throw 'Invalid credentials'
}

Add-PodeRoute -Method Post -Path '/auth/login' -ScriptBlock {
    try {
        $username = $WebEvent.Data.username
        $password = $WebEvent.Data.password
        $user = Test-User $username $password  # Validate credentials in some real store

        $payload = @{
            sub  = $user.Id
            name = $user.Name
            # ... more custom claims ...
        }

        # Generate JWT recognized by the scheme 'Bearer_JWT_ES512'
        $jwt = ConvertTo-PodeJwt -Payload $payload -Authentication 'Bearer_JWT_ES512' -Expiration 600

        Write-PodeJsonResponse -StatusCode 200 -Value @{
            success = $true
            user    = $user
            jwt     = $jwt
        }
    }
    catch {
        Write-PodeJsonResponse -StatusCode 401 -Value @{ error = 'Invalid credentials' }
    }
}
```

## 2. Automatic Validation

Once you have a named bearer scheme (e.g., `Bearer_JWT_ES512`), **any** route that includes `-Authentication 'Bearer_JWT_ES512'` is automatically protected. Pode will:

- Extract the JWT from the HTTP `Authorization` header (or another location if specified).
- Decode and verify the signature based on the scheme’s configuration.
- Reject the request if invalid; otherwise, set `$WebEvent.Auth.User` with any relevant user/claims data.

```powershell
Add-PodeRoute -Method Get -Path '/secure' -Authentication 'Bearer_JWT_ES512' -ScriptBlock {
    # If we get here, the token is valid
    $user = $WebEvent.Auth.User
    Write-PodeJsonResponse -Value @{ user = $user; message = 'Welcome!' }
}
```

No need to manually call `ConvertFrom-PodeJwt`—Pode handles validation behind the scenes.

## 3. Decoding/Inspecting a JWT

Sometimes you want to **inspect** a token or decode it for debugging. That’s where `ConvertFrom-PodeJwt` is handy. For example, you might have a route that **also** includes `-Authentication 'Bearer_JWT_ES512'` (so the user needs a valid token to get in), but within the route you call `ConvertFrom-PodeJwt` to see the raw contents or claims:

```powershell
Add-PodeRoute -Method Post -Path '/auth/bearer/jwt/info' -Authentication 'Bearer_JWT_ES512' -ScriptBlock {
    try {
        # Although Pode already validated the token, we can decode it ourselves for debugging
        $decoded = ConvertFrom-PodeJwt -Outputs 'Header,Payload,Signature' -HumanReadable
        Write-PodeJsonResponse -Value $decoded
    }
    catch {
        Write-PodeJsonResponse -StatusCode 401 -Value @{ error = 'Invalid JWT token supplied' }
    }
}
```

This route returns the **header, payload, and signature** in JSON, with timestamps (like `exp`, `nbf`, `iat`) converted to human-readable dates.

## 4. Renewing/Extending a JWT with `Update-PodeJwt`

Use `Update-PodeJwt` to **extend** an existing token’s lifetime. Typically, you create a `/renew` endpoint:

```powershell
Add-PodeRoute -Method Post -Path '/auth/bearer/jwt/renew' -Authentication 'Bearer_JWT_ES512' -ScriptBlock {
    try {
        # Reads the current valid JWT, reissues it with a fresh 'exp' claim
        $newToken = Update-PodeJwt
        Write-PodeJsonResponse -StatusCode 200 -Value @{ success = $true; jwt = $newToken }
    }
    catch {
        Write-PodeJsonResponse -StatusCode 401 -Value @{ error = 'Invalid JWT token supplied' }
    }
}
```

Pode fetches the token from `$WebEvent`, checks the original scheme (here, `Bearer_JWT_ES512`), and re-signs with updated expiration. The rest of the claims stay the same. The client can then discard the old token and use the newly returned token moving forward.

---

## Full Lifecycle Example

**1.** **Login** (create token)
**2.** **Make Authenticated Requests** (Pode automatically validates)
**3.** **Renew** (use `Update-PodeJwt` if needed)
**4.** **Debug** (optionally decode token with `ConvertFrom-PodeJwt`)

This covers a typical JWT flow in Pode:

- The user logs in at `/auth/login`, gets a JWT.
- They pass that JWT in subsequent requests, which are auto-validated by `-Authentication 'Bearer_JWT_ES512'`.
- If the token is about to expire, they can call `/auth/bearer/jwt/renew` to get a fresh one.
- If you need to debug claims, you can build an endpoint that calls `ConvertFrom-PodeJwt` or look at `$WebEvent.Auth.User`.

For more details, see the [Pode GitHub examples](https://github.com/Badgerati/Pode/tree/develop/examples/Authentication) or the relevant [`ConvertTo-PodeJwt`](https://github.com/Badgerati/Pode/blob/develop/Functions/Authentication/ConvertTo-PodeJwt.ps1) and [`Update-PodeJwt`](https://github.com/Badgerati/Pode/blob/develop/Functions/Authentication/Update-PodeJwt.ps1) source files.