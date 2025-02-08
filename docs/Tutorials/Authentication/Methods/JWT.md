# JWT

Pode has inbuilt JWT parsing for either [Bearer](../Bearer) or [API Key](../ApiKey) authentications. Pode will attempt to validate and parse the token/key as a JWT, and if successful, the JWT's payload will be passed as the parameter to [`Add-PodeAuth`](../../../../Functions/Authentication/Add-PodeAuth) instead of the token/key.

For more information on JWTs, see the [official website](https://jwt.io).

## Setup

To start using JWT authentication, you can supply the `-AsJWT` switch with either the `-Bearer` or `-ApiKey` switch on [`New-PodeAuthScheme`](../../../../Functions/Authentication/New-PodeAuthScheme). You can also supply an optional `-Secret` or `-PrivateKey` that the JWT signature uses so Pode can validate the JWT:

```powershell
# JWT with no signature:
New-PodeAuthScheme -Bearer -AsJWT | Add-PodeAuth -Name 'Example' -Sessionless -ScriptBlock {
    param($payload)
}

# JWT with HMAC signature, signed with secret "abc":
New-PodeAuthScheme -ApiKey -AsJWT -Secret 'abc' | Add-PodeAuth -Name 'Example' -Sessionless -ScriptBlock {
    param($payload)
}

# JWT with RSA signature, using a private key:
$privateKey = Get-Content 'C:\path\to\private-key.pem' -Raw | ConvertTo-SecureString -AsPlainText -Force
New-PodeAuthScheme -Bearer -AsJWT -PrivateKey $privateKey | Add-PodeAuth -Name 'Example' -Sessionless -ScriptBlock {
    param($payload)
}
```

The `$payload` will be a PSCustomObject of the converted JSON payload. For example, sending the following unsigned JWT in a request:

```plain
eyJhbGciOiJub25lIn0.eyJ1c2VybmFtZSI6Im1vcnR5Iiwic3ViIjoiMTIzIn0.
```

would produce a payload of:

```plain
sub:        123
username:   morty
```

### Algorithms

Pode now fully supports RFC 7518 and the following JWT signing algorithms:

* NONE
* HS256, HS384, HS512 (HMAC)
* RS256, RS384, RS512 (RSA)
* PS256, PS384, PS512 (RSA-PSS)
* ES256, ES384, ES512 (ECDSA)

For `NONE`, Pode expects there to be no signature with the JWT. For HMAC algorithms, a `-Secret` is required, while RSA and ECDSA algorithms require a `-PrivateKey`.

### Payload

If the payload of the JWT contains an expiry (`exp`) or a not before (`nbf`) timestamp, Pode will validate it and return a 400 error if the JWT is expired or not yet valid.

## Usage

To send the JWT in a request, it should replace the usual bearer token or API key. For bearer authentication, the JWT can be included in the header (recommended) or the query string:

```plain
Authorization: Bearer <jwt>
```

For API keys, it would be in the location defined (header, cookie, or query string). For example, in the X-API-KEY header:

```plain
X-API-KEY: <jwt>
```

## Create JWT

Pode has a simple [`ConvertTo-PodeJwt`](../../../../Functions/Authentication/ConvertTo-PodeJwt) function that will build a JWT for you. It accepts a hashtable for `-Header` and `-Payload`, as well as an optional `-Secret` or `-PrivateKey`.

The function will run simple validation checks and then build the JWT.

Example for Algorithm RS256:

```powershell
$header = @{
    alg = 'RS256'
    typ = 'JWT'
}

$payload = @{
    sub = '123'
    name = 'John Doe'
    exp = ([System.DateTimeOffset]::Now.AddDays(1).ToUnixTimeSeconds())
}

$privateKey = Get-Content 'C:\path\to\private-key.pem' -Raw | ConvertTo-SecureString -AsPlainText -Force
ConvertTo-PodeJwt -Header $header -Payload $payload -PrivateKey $privateKey
```

This will return a signed JWT.

```plain
eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VybmFtZSI6Im1vcnR5Iiwic3ViIjoiMTIzNDU2Nzg5MCIsIm5hbWUiOiJKb2huIERvZSIsImFkbWluIjp0cnVlLCJpYXQiOjE1MTYyMzkwMjJ9.BHd2VyTJ5MBK5RYN85ZKIsRYQEfA5V1FEUop3NsrRy_bO3f2K3nk22gq9JzCD9TLDsonaxQ6Y-kFkK5_aQIkQR5-PQfAf-4WDr1QTq6gte2SboVF7LqWcuEGZWkRibx7KWTztGz2ar_5iMvsB8-_jDQN6IfRum0fGJhhmZgV8aazl_korps28RCKMS4JXo_CIoL5BGCH5nQJoqKcjPT79GuNqxZi04UBwcLoStl4Idm0Rfc8CFpzsWqwQcWAYS-J2gGtRUGSlbotifuxqG2aUh_PLAegAgUh-px_O_c_U3L79Pr8RFM1SLo4pYSdwr3VDy-NhUw2YMB1s3gKEtGQGg
```

Example for Algorithm HS256:

```powershell
$header = @{
    alg = 'hs256'
    typ = 'JWT'
}

$payload = @{
    sub = '123'
    name = 'John Doe'
    exp = ([System.DateTimeOffset]::Now.AddDays(1).ToUnixTimeSeconds())
}

ConvertTo-PodeJwt -Header $header -Payload $payload -Secret 'abc'
```

This return the following JWT:

```plain
eyJ0eXAiOiJKV1QiLCJhbGciOiJoczI1NiJ9.eyJleHAiOjE2MjI1NTMyMTQsIm5hbWUiOiJKb2huIERvZSIsInN1YiI6IjEyMyJ9.LP-O8OKwix91a-SZwVK35gEClLZQmsORbW0un2Z4RkY
```

## Parse JWT

Pode has a [`ConvertFrom-PodeJwt`](../../../../Functions/Authentication/ConvertFrom-PodeJwt) function that can be used to parse a valid JWT. Only the algorithms listed above are supported for verifying the signature. You can skip signature verification by passing `-IgnoreSignature`. On success, the payload of the JWT is returned.

For example, if the created JWT was supplied:

```powershell
ConvertFrom-PodeJwt -Token 'eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJleHAiOjE2MjI1NTMyMTQsIm5hbWUiOiJKb2huIERvZSIsInN1YiI6IjEyMyJ9.LP-O8OKwix91a-SZwVK35gEClLZQmsORbW0un2Z4RkY' -Secret 'abc'
```

then the following would be returned:

```powershell
@{
    sub = '123'
    name = 'John Doe'
    exp = 1636657408
}
```
