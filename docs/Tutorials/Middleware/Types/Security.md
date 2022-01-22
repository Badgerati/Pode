# Security Headers

The security headers middleware runs at the beginning of every request, and if any security headers are defined they will be added onto the response.

The following headers are currently supported, but you can add custom header values:

* Access-Control-Max-Age
* Access-Control-Allow-Methods
* Access-Control-Allow-Origin
* Access-Control-Allow-Headers
* Cross-Origin-Embedder-Policy
* Cross-Origin-Resource-Policy
* Cross-Origin-Opener-Policy
* Strict-Transport-Security
* Content-Security-Policy
* X-XSS-Protection
* Permissions-Policy
* X-Frame-Options
* X-Content-Type-Options
* Referrer-Policy

## Types

Pode has an inbuilt wrapper to easily toggle all headers with default values: [`Set-PodeSecurity`](../../../../Functions/Security/Set-PodeSecurity). This function lets you specify a `-Type` of either `Simple` or `Strict`. The specified value will setup the headers with the default values defined below. You can also force `X-XSS-Protection` to use blocking mode if you want to support older browsers, or enable `Strict-Transport-Security` via `-UseHsts`.

For example, to configure Simple security with Strict Transport:

```powershell
Set-PodeSecurity -Type Simple -UseHsts
```

To remove all configured values, use [`Remove-PodeSecurity`](../../../../Functions/Security/Remove-PodeSecurity).

### Simple

The following values are used for each header when the `Simple` type is supplied:

| Name | Value |
| ---- | ----- |
| Access-Control-Max-Age | 7200 |
| Access-Control-Allow-Origin | * |
| Access-Control-Allow-Methods | * |
| Access-Control-Allow-Headers | * |
| Cross-Origin-Embedder-Policy | require-corp |
| Cross-Origin-Resource-Policy | same-origin |
| Cross-Origin-Opener-Policy | same-origin |
| Content-Security-Policy | default-src 'self' |
| X-XSS-Protection | 0 |
| Permissions-Policy | layout-animations=(), oversized-images=(), sync-xhr=(), unoptimized-images=(), unsized-media=() |
| X-Frame-Options | SAMEORIGIN |
| X-Content-Type-Options | nosniff |
| Referred-Policy | strict-origin |

### Strict

The following values are used for each header when the `Strict` type is supplied:

| Name | Value |
| ---- | ----- |
| Access-Control-Max-Age | 7200 |
| Access-Control-Allow-Methods | * |
| Access-Control-Allow-Origin | * |
| Access-Control-Allow-Headers | * |
| Cross-Origin-Embedder-Policy | require-corp |
| Cross-Origin-Resource-Policy | same-origin |
| Cross-Origin-Opener-Policy | same-origin |
| Strict-Transport-Security | max-age=31536000; includeSubDomains |
| Content-Security-Policy | default-src 'self' |
| X-XSS-Protection | 0 |
| Permissions-Policy | layout-animations=(), oversized-images=(), sync-xhr=(), unoptimized-images=(), unsized-media=() |
| X-Frame-Options | DENY |
| X-Content-Type-Options | nosniff |
| Referred-Policy | no-referrer |

## Headers

You can setup the values of headers individually by using their relevant functions.

You can also use [`Set-PodeSecurity`](../../../../Functions/Security/Set-PodeSecurity) to configure all the defaults, and then set/add custom values for a single header. For example, you can configure Simple values, and then add `*.twitter.com` to the `default-src` of the `Content-Security-Policy` header using [`Add-PodeSecurityContentSecurityPolicy`](../../../../Functions/Security/Add-PodeSecurityContentSecurityPolicy):

```powershell
Set-PodeSecurity -Type Simple
Add-PodeSecurityContentSecurityPolicy -Default '*.twitter.com'
```

This will make the 'default-src' value: `'self' *.twitter.com`.

Conversely, you could remove the header completely using [`Remove-PodeSecurityContentSecurityPolicy`](../../../../Functions/Security/Remove-PodeSecurityContentSecurityPolicy), or override the whole value using [`Set-PodeSecurityContentSecurityPolicy`](../../../../Functions/Security/Set-PodeSecurityContentSecurityPolicy).

### Access Control

The following functions exist:

* [`Set-PodeSecurityAccessControl`](../../../../Functions/Security/Set-PodeSecurityAccessControl)
* [`Remove-PodeSecurityAccessControl`](../../../../Functions/Security/Remove-PodeSecurityAccessControl)

Specifies the values for the following headers:

* Access-Control-Max-Age
* Access-Control-Allow-Methods
* Access-Control-Allow-Origin
* Access-Control-Allow-Headers

For example:

```powershell
Set-PodeSecurityAccessControl -Origin '*' -Methods '*' -Headers '*' -Duration 7200
```

### Cross Origin

The following functions exist:

* [`Set-PodeSecurityCrossOrigin`](../../../../Functions/Security/Set-PodeSecurityCrossOrigin)
* [`Remove-PodeSecurityCrossOrigin`](../../../../Functions/Security/Remove-PodeSecurityCrossOrigin)

Specifies the values for the following headers:

* Cross-Origin-Embedder-Policy
* Cross-Origin-Resource-Policy
* Cross-Origin-Opener-Policy

For example:

```powershell
Set-PodeSecurityCrossOrigin -Embed Require-Corp -Open Same-Origin -Resource Same-Origin
```

### Strict Transport

The following functions exist:

* [`Set-PodeSecurityStrictTransportSecurity`](../../../../Functions/Security/Set-PodeSecurityStrictTransportSecurity)
* [`Remove-PodeSecurityStrictTransportSecurity`](../../../../Functions/Security/Remove-PodeSecurityStrictTransportSecurity)

The `Strict-Transport-Security` header enforces the use of HTTPS from the browser. For example:

```powershell
Set-PodeSecurityStrictTransportSecurity -Duration 31536000 -IncludeSubDomains
```

### Content Security

The following functions exist:

* [`Add-PodeSecurityContentSecurityPolicy`](../../../../Functions/Security/Add-PodeSecurityContentSecurityPolicy)
* [`Set-PodeSecurityContentSecurityPolicy`](../../../../Functions/Security/Set-PodeSecurityContentSecurityPolicy)
* [`Remove-PodeSecurityContentSecurityPolicy`](../../../../Functions/Security/Remove-PodeSecurityContentSecurityPolicy)

The `Content-Security-Policy` header controls a whitelist of approved sourced from which the browser can load resoures. For example:

```powershell
Set-PodeSecurityContentSecurityPolicy -Default 'self' -Image 'self', 'data'
```

### Permissions Policy

The following functions exist:

* [`Set-PodeSecurityPermissionsPolicy`](../../../../Functions/Security/Set-PodeSecurityPermissionsPolicy)
* [`Remove-PodeSecurityPermissionsPolicy`](../../../../Functions/Security/Remove-PodeSecurityPermissionsPolicy)

The `Permissions-Policy` header controls which features/APIs a site can use in the browser. For example:

```powershell
Set-PodeSecurityPermissionsPolicy -LayoutAnimations 'none' -UnoptimisedImages 'none' -OversizedImages 'none' -SyncXhr 'none' -UnsizedMedia 'none'
```

### Frame Options

The following functions exist:

* [`Set-PodeSecurityFrameOptions`](../../../../Functions/Security/Set-PodeSecurityFrameOptions)
* [`Remove-PodeSecurityFrameOptions`](../../../../Functions/Security/Remove-PodeSecurityFrameOptions)

The `X-Frame-Options` header tells the browser whether your site support framing or not. For example:

```powershell
Set-PodeSecurityFrameOptions -Type SameOrigin
```

### ContentType Options

The following functions exist:

* [`Set-PodeSecurityContentTypeOptions`](../../../../Functions/Security/Set-PodeSecurityContentTypeOptions)
* [`Remove-PodeSecurityContentTypeOptions`](../../../../Functions/Security/Remove-PodeSecurityContentTypeOptions)

The `Content-Type-Options` header only has one value: `nosniff`. So you enable, you just need to call the Set function, for example:

```powershell
Set-PodeSecurityContentTypeOptions
```

### Referrer Policy

The following functions exist:

* [`Set-PodeSecurityReferrerPolicy`](../../../../Functions/Security/Set-PodeSecurityReferrerPolicy)
* [`Remove-PodeSecurityReferrerPolicy`](../../../../Functions/Security/Remove-PodeSecurityReferrerPolicy)

The `Referrer-Policy` header tells the browser how much information to include in the `Referer` header. For example:

```powershell
Set-PodeSecurityReferrerPolicy -Type Strict-Origin
```

## Custom

There could be some headers for security that Pode doesn't support, but that you need. In this case you can use [`Add-PodeSecurityHeader`](../../../../Functions/Security/Add-PodeSecurityHeader) to specify a custom header and value that will be added:

```powershell
Add-PodeSecurityHeader -Name 'X-Security-Header' -Value 'Value'
```
