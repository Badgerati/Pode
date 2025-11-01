# Responses

Pode has support for sending back compressed Responses, if enabled, and if a client sends an appropriate `Accept-Encoding` header.

The following compression methods are supported:

* gzip
* deflate
* br (Brotli, supported when running under PowerShell Core)

## Enabling Response Compression with Add-PodeRouteCompression

The recommended way to enable response compression is to use the `Add-PodeRouteCompression` function when defining your routes. This allows you to enable or disable compression for specific routes and specify which encodings are supported.

```powershell
Add-PodeRoute -Method Get -Path '/data' -ScriptBlock { ... } -PassThru |
    Add-PodeRouteCompression -Enable -Encoding gzip,deflate,br -Direction Response
```

**Parameters for `Add-PodeRouteCompression`:**

* `-Enable` : Enables compression for the specified route(s).
* `-Disable` : Disables compression for the specified route(s).
* `-Encoding <string[]>` : Specifies one or more compression algorithms to allow. Valid values are: `gzip`, `deflate`, and `br` (Brotli, PowerShell Core only).
* `-Direction <string>` : Sets the direction of compression. Use `Response` to compress outgoing responses (default).
* `-PassThru` : Returns the updated route object(s) to the pipeline for further processing.

This will ensure that outgoing responses from `/data` are compressed if the client sends an `Accept-Encoding` header with a supported encoding.

## Headers

For your Pode server to compress the response, the client must send an `Accept-Encoding` header with `gzip`, `deflate`, or `br` (PowerShell Core only):

```text
Accept-Encoding: gzip
Accept-Encoding: deflate
Accept-Encoding: br
Accept-Encoding: identity
Accept-Encoding: *
```

Or any valid combination:

```text
Accept-Encoding: gzip,deflate,br
```

If multiple encodings are sent, Pode will use the first supported value. There is also support for quality values as well, so you can weight encodings or fully disable non-compression (if no q-value is on an encoding it is assumed to be 1)

```text
Accept-Encoding: gzip,deflate,br,identity;q=0
```

In a scenario where no encodings are supported, and identity (no-compression) is disabled, Pode will respond with a 406.

If an encoding is used to compress the response, then Pode will set the `Content-Encoding` on the response.

## Legacy Approach: Configuration File

By default, response compression is disabled in Pode. The legacy way to enable compression is to set the following value in your server's `server.psd1` [configuration](../../Configuration) file:

```powershell
@{
    Web = @{
        Compression = @{
            Enable = $true
        }
    }
}
```

Once enabled, compression will be used if a valid `Accept-Encoding` header is sent in the request.
