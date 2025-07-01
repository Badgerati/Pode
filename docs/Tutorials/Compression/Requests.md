# Requests

Pode supports sending requests with compressed payloads (such as JSON compressed with GZip), but it's important to use the correct approach for compression and decompression.

Pode supports the following compression methods:

* gzip
* deflate
* br (Brotli, supported when running under PowerShell Core)

## Important Note on Compression Headers

> **Note:** While Pode allows the use of the `Transfer-Encoding` header for compatibility with some clients, this is **not** the recommended way to compress request payloads. Pode does **not** decompress the payload on the fly using `Transfer-Encoding`. Instead, Pode expects compressed payloads to be indicated using the `Content-Encoding` header, which is the standard way for HTTP payload compression.

If you use `Transfer-Encoding`, Pode will not automatically decompress the request body. This option is only available for legacy or compatibility reasons.

## Recommended Approach: Content-Encoding Header

To ensure Pode correctly decompresses the payload, use the `Content-Encoding` header in your requests. For example:

```text
Content-Encoding: gzip
Content-Encoding: deflate
```

Pode will automatically decompress the payload if this header is present and matches a supported encoding.

## Enabling Compression on Routes

To configure how Pode handles compressed payloads, use the `Add-PodeRouteCompression` function. This allows you to enable or disable compression for specific routes and specify which encodings are supported. For example:

```powershell
Add-PodeRoute -Method Post -Path '/upload' -ScriptBlock { ... } -PassThru |
    Add-PodeRouteCompression -Enable -Encoding gzip,deflate -Direction Request
```

**Parameters for `Add-PodeRouteCompression`:**

- `-Enable` : Enables compression for the specified route(s).
- `-Disable` : Disables compression for the specified route(s).
- `-Encoding <string[]>` : Specifies one or more compression algorithms to allow. Valid values are: `gzip`, `deflate`, and `br` (Brotli, PowerShell Core only).
- `-Direction <string>` : Sets the direction of compression. Valid values are:
    - `Request` (decompress incoming requests)
    - `Response` (compress outgoing responses, default)
    - `Both` (enable for both requests and responses)
- `-PassThru` : Returns the updated route object(s) to the pipeline for further processing.

This will ensure that incoming requests to `/upload` are decompressed if they use `Content-Encoding: gzip`, `Content-Encoding: deflate`, or `Content-Encoding: br` (Brotli, PowerShell Core only).

## Legacy/Compatibility: Transfer-Encoding Header

Pode still supports the `Transfer-Encoding` header for compatibility with some clients, but this is not the preferred method. If you use this header, Pode will not decompress the payload automatically. Example:

```text
Transfer-Encoding: gzip
Transfer-Encoding: deflate
// or:
Transfer-Encoding: gzip,chunked
```

## Route

Like content types, you can force a Route to use a specific transfer encoding by using the `-TransferEncoding` parameter on [`Add-PodeRoute`](../../../Functions/Routes/Add-PodeRoute). If specified, Pode will use this compression type to decompress the payload regardless if the header is present or not.

```powershell
Add-PodeRoute -Method Get -Path '/' -TransferEncoding gzip -ScriptBlock {
    # logic
}
```

## Configuration

Pode also supports configuring default or pattern-based compression behavior in your `server.psd1` configuration file. This allows you to set a default transfer encoding for all routes, or define patterns to match multiple route paths and set transfer encodings in bulk.

### Default

To define a default transfer encoding for everything, you can use the following configuration:

```powershell
@{
    Web = @{
        TransferEncoding = @{
            Default = "gzip"
        }
    }
}
```

### Route Patterns

You can define patterns to match multiple route paths, and any route that matches (when created) will have the appropriate transfer encoding set.

For example, the following configuration in your `server.psd1` would bind all `/api` routes to `gzip`, and then all `/status` routes to `deflate`:

```powershell
@{
    Web = @{
        TransferEncoding = @{
            Routes = @{
                "/api/*" = "gzip"
                "/status/*" = "deflate"
            }
        }
    }
}
```

> **Note:** These configuration options are primarily for compatibility and legacy support. For new projects, prefer using `Add-PodeRouteCompression` and the `Content-Encoding` header as described above.

## Example: Sending a GZip Encoded Payload (Legacy)

The following is an example of sending a `gzip` encoded payload using the legacy `Transfer-Encoding` header:

```powershell
# get the JSON message in bytes
$data = @{
    Name = "Deepthought"
    Age = 42
}

$message = ($data | ConvertTo-Json)
$bytes = [System.Text.Encoding]::UTF8.GetBytes($message)

# compress the message using gzip
$ms = [System.IO.MemoryStream]::new()
$gzip = [System.IO.Compression.GZipStream]::new($ms, [IO.Compression.CompressionMode]::Compress, $true)
$gzip.Write($bytes, 0, $bytes.Length)
$gzip.Close()
$ms.Position = 0

# send request
Invoke-RestMethod `
    -Method Post `
    -Uri 'http://localhost:8080/ping' `
    -Body $ms.ToArray() `
    -TransferEncoding gzip `
    -ContentType application/json
```

This will ensure Pode correctly decompresses and processes the payload when using legacy `Transfer-Encoding` (not recommended for new projects).

# Example: Sending a GZip Encoded Payload (Recommended)

The following is an example of sending a `gzip` encoded payload using the recommended `Content-Encoding` header:

```powershell
# get the JSON message in bytes
$data = @{
    Name = "Deepthought"
    Age = 42
}

$message = ($data | ConvertTo-Json)
$bytes = [System.Text.Encoding]::UTF8.GetBytes($message)

# compress the message using gzip
$ms = [System.IO.MemoryStream]::new()
$gzip = [System.IO.Compression.GZipStream]::new($ms, [IO.Compression.CompressionMode]::Compress, $true)
$gzip.Write($bytes, 0, $bytes.Length)
$gzip.Close()
$ms.Position = 0

# send request
Invoke-RestMethod `
    -Method Post `
    -Uri 'http://localhost:8080/ping' `
    -Body $ms.ToArray() `
    -Headers @{ 'Content-Encoding' = 'gzip' } `
    -ContentType application/json
```

This will ensure Pode correctly decompresses and processes the payload using the modern and recommended approach.