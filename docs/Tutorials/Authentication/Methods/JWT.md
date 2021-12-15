# JWT

Pode has inbuilt JWT parsing for either [Bearer](../Bearer) or [API Key](../ApiKey) authentications. Pode will attempt to validate and parse the token/key as a JWT, and if successful the JWT's payload will be passed as the parameter to [`Add-PodeAuth`](../../../../Functions/Authentication/Add-PodeAuth), instead of the token/key.

For more information on JWTs, see the [official website](https://jwt.io).

## Setup

To start using JWT authentication, you can supply the `-AsJWT` switch with either the `-Bearer` or `-ApiKey` switch on [`New-PodeAuthScheme`](../../../../Functions/Authentication/New-PodeAuthScheme). You can also supply an optional `-Secret` that the JWT signature uses so Pode can validate the JWT:

```powershell
# jwt with no signature:
New-PodeAuthScheme -Bearer -AsJWT | Add-PodeAuth -Name 'Example' -Sessionless -ScriptBlock {
    param($payload)
}

# jwt with signature, signed with secret "abc":
New-PodeAuthScheme -ApiKey -AsJWT -Secret 'abc' | Add-PodeAuth -Name 'Example' -Sessionless -ScriptBlock {
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

Pode supports the following algorithms for JWT signatures:

* None
* HS256
* HS384
* HS512

For `none`, Pode expects there to be no signature with the JWT. For other algorithms, a `-Secret` is required, and a signature must be supplied with the JWT in requests.

### Payload

If the payload of the JWT contains a expiry (`exp`) or a not before (`nbf`) timestamp, Pode will validate it and return a 400 if the JWT is expired/not started.

## Usage

To send the JWT in a request, the JWT should be sent in place of where the usual bearer token/API key would have been. For example, for bearer it would be in the Authorization header:

```plain
Authorization: Bearer <jwt>
```

and for API keys, it would be in the location defined (header, cookie, or query string). For example, in the X-API-KEY header:

```plain
X-API-KEY: <jwt>
```

## Create JWT

Pode has a simple [`ConvertTo-PodeJwt`](../../../../Functions/Authentication/ConvertTo-PodeJwt) that will build a JWT for you. It accepts a hashtable for `-Header` and `-Payload`, as well as an optional `-Secret`.

The function will run some simple validation, and them build the JWT for you.

For example:

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

Pode has a [`ConvertFrom-PodeJwt`](../../../../Functions/Authentication/ConvertFrom-PodeJwt) that can be used to parse a valid JWT. Only the algorithms at the top of this page are supported for verifying the signature. You can skip signature verification by passing `-IgnoreSignature`. On success, the payload of the JWT is returned.

For example, if the created JWT was supplied:

```powershell
ConvertFrom-PodeJwt -Token 'eyJ0eXAiOiJKV1QiLCJhbGciOiJoczI1NiJ9.eyJleHAiOjE2MjI1NTMyMTQsIm5hbWUiOiJKb2huIERvZSIsInN1YiI6IjEyMyJ9.LP-O8OKwix91a-SZwVK35gEClLZQmsORbW0un2Z4RkY' -Secret 'abc'
```

then the following would be returned:

```powershell
@{
    sub = '123'
    name = 'John Doe'
    exp = 1636657408
}
```
