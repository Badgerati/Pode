# Content Caching

Pode supports caching of both static and non-static content to improve performance and reduce server load. Caching is only available for HTTP `GET` requests; `POST` and `PUT` methods are not supported for caching.

Caching can be configured using two main approaches:

- **Legacy configuration via `server.psd1`**
- **Modern, route-specific configuration using `Add-PodeRouteCache`** (recommended for new projects)

---

## 1. Route-Specific Caching with `Add-PodeRouteCache` (Recommended)

The `Add-PodeRouteCache` function allows you to enable and fine-tune caching for individual static routes. This provides greater flexibility and control compared to global configuration.

### Example Usage

```powershell
Add-PodeStaticRoute -Path '/cache' -Source $using:TestFolder -FileBrowser -PassThru |
    Add-PodeRouteCache -Enable -MaxAge 10 -Visibility public -ETagMode mtime -MustRevalidate
```

#### Parameter Details (RFC Cache Settings)

- `-Enable`: **Turns on caching for the route.**
  - When enabled, Pode will add HTTP cache headers to responses for this route, allowing browsers and proxies to cache the content according to the specified settings.

- `-MaxAge <seconds>`: **Sets the cache duration in seconds.**
  - This sets the `max-age` directive in the `Cache-Control` header, telling clients and intermediaries how long (in seconds) the content is considered fresh before it must be revalidated.
  - Example: `Cache-Control: max-age=10`

- `-Visibility <public|private|no-cache|no-store>`: **Sets the cache visibility and behavior.**
  - `public`: The response may be cached by any cache (browser, proxy, CDN).
  - `private`: The response is intended for a single user and should not be stored by shared caches (proxies, CDNs).
  - `no-cache`: Forces caches to submit the request to the origin server for validation before releasing a cached copy.
  - `no-store`: Prevents caches from storing any part of the request or response.
  - Example: `Cache-Control: public` or `Cache-Control: private`

- `-ETagMode <none|auto|hash|mtime|manual>`: **Controls how the ETag is generated.**
  - `none`: Disables ETag generation.
  - `auto`: Uses `mtime` for static routes and `hash` for dynamic routes (default behavior).
  - `hash`: ETag is based on a hash of the file/content, useful for dynamic or API responses.
  - `mtime`: ETag is based on the file's last modification time (recommended for static files).
  - `manual`: Allows manual ETag setting via the `ETag` parameter of `Write-PodeTextResponse`, `Write-PodeYamlResponse`, `Write-PodeJsonResponse`, `Write-PodeCsvResponse`, `Write-PodeHtmlResponse`, and `Write-PodeXmlResponse` cmdlets.
  - Example: `Write-PodeJsonResponse -Value $data -ETag 'my-custom-etag'`

- `-MustRevalidate`: **Adds the `must-revalidate` directive to the cache headers.**
  - This instructs caches that once the content becomes stale (after `max-age`), it must be revalidated with the server before being served again. This ensures clients always get up-to-date content after expiration.
  - Example: `Cache-Control: must-revalidate`

- `-Immutable`: **Adds the `immutable` directive to the cache headers.**
  - Indicates that the resource will not change, so clients can use the cached version without revalidation for the duration of `max-age`.
  - Example: `Cache-Control: immutable`

- `-SharedMaxAge <seconds>`: **Sets the `s-maxage` directive for shared (proxy) caches.**
  - Controls how long shared caches (like CDNs or proxies) can cache the response, overriding `max-age` for those caches.
  - Example: `Cache-Control: s-maxage=3600`

- `-WeakValidation`: **Returns the ETag in weak form (prefixed with W/).**
  - Indicates that the ETag is a weak validator, suitable for semantically equivalent but not byte-for-byte identical resources.
  - Example: `ETag: W/"<hash>"`

You can chain `Add-PodeRouteCache` after any static route (or other supported routes) using the pipeline. This allows you to:

- Enable/disable caching per route
- Set custom cache durations
- Control cache headers and validation
- Combine with compression (see below)

#### Chaining with Compression

You can also combine caching and compression:

```powershell
Add-PodeStaticRoute -Path '/cache' -Source $using:TestFolder -FileBrowser -PassThru |
    Add-PodeRouteCache -Enable -MaxAge 10 -Visibility public -ETagMode mtime -MustRevalidate -PassThru |
    Add-PodeRouteCompression -Enable -Encoding gzip
```

## 2. Cache Control Headers

Pode sets standard HTTP cache headers based on your configuration, such as:

- `Cache-Control`
- `ETag`
- `Last-Modified`
- `Expires`

These headers help browsers and proxies cache content efficiently and validate freshness.

### Example: Full Server Reply Header with Caching

Below is an example of a typical HTTP response header from Pode when caching is enabled for a static route:

``` text
HTTP/1.1 200 OK
Content-Type: text/plain; charset=utf-8
Content-Length: 12345
Cache-Control: public, max-age=600, must-revalidate
ETag: "20250629-abcdef123456"
Last-Modified: Sat, 29 Jun 2025 10:00:00 GMT
Expires: Sat, 29 Jun 2025 10:10:00 GMT
Date: Sat, 29 Jun 2025 10:00:00 GMT
Vary: Accept-Encoding
```

- `Cache-Control`: Shows the cache policy (visibility, max-age, must-revalidate, etc.)
- `ETag`: Unique identifier for the file version (here based on modification time)
- `Last-Modified`: Timestamp of the file's last modification
- `Expires`: When the content should be considered stale
- `Vary`: Indicates which request headers affect the response (e.g., for compression)

#### Conditional Requests and 304 Not Modified

Pode supports conditional requests for efficient caching:

- If the client sends an `If-None-Match` header with an ETag value that matches the current resource, the server responds with `304 Not Modified` and no body.
- If the client sends an `If-Modified-Since` header with a date that is equal to or newer than the resource's `Last-Modified` value, the server responds with `304 Not Modified` and no body.

This allows clients and proxies to avoid downloading unchanged content, saving bandwidth and improving performance.

## 3. Legacy Caching via `server.psd1` Configuration

Pode also supports global static content caching via the `server.psd1` configuration file. This method applies cache settings to all static content unless overridden by route-specific settings.

### Example Configuration

```powershell
@{
    Web = @{
        Static = @{
            Cache = @{
                Enable = $true
                MaxAge = 1800  # 30 minutes
                Include = @(
                    "/images/*",
                    "/assets/*.js"
                )
                Exclude = @(
                    "*.exe"
                )
            }
        }
    }
}
```

- `Enable`: Turns on caching globally for static content.
- `MaxAge`: Sets the default cache duration (in seconds).
- `Include`: Only cache the specified paths/patterns.
- `Exclude`: Do not cache the specified paths/patterns.

> **Note:** If you use both the configuration file and `Add-PodeRouteCache`, the route-specific settings take precedence for that route.

## 4. More Examples

### Basic Caching for a Static Route

```powershell
Add-PodeStaticRoute -Path '/static' -Source './public' -PassThru |
    Add-PodeRouteCache -Enable -MaxAge 600
```

### Advanced Caching with Public Visibility and ETag

```powershell
Add-PodeStaticRoute -Path '/assets' -Source './assets' -PassThru |
    Add-PodeRouteCache -Enable -MaxAge 3600 -Visibility public -ETagMode mtime -MustRevalidate
```

---

**Tip:** Use `Add-PodeRouteCache` for fine-grained, per-route caching control. The global configuration file is suitable if all routes share the same, non-configurable cache settings. For more flexibility, you can apply caching to multiple routes programmatically, for example:

```powershell
Get-PodeRoute | Add-PodeRouteCache -Enable -MaxAge 3600 -Visibility public -ETagMode mtime -MustRevalidate
```

This approach allows you to set or override cache settings for all or selected routes as needed.