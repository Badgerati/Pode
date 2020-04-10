# Requests

You can send Requests to your Pode server that use compression on the payload, such as a JSON payload compressed via GZip.

Pode supports the following compression methods:

* gzip
* deflate

There are a number of ways you can specify the compression type, and these are defined below. When your request uses compression, Pode will first decompress the payload, and then attempt to parse it if needed.

## Request

The most common way is to define the a request's compression type in the request's headers. The header to use depends on which web-server type you're using:

| Server Type | Header |
| ----------- | ------ |
| HttpListener | X-Transfer-Encoding |
| Pode | Transfer-Encoding |

HttpListener is the default web server, unless you specify `-Type Pode` on `Start-PodeServer`. The reason for HttpListener using a slightly different header to the normal, is because HttpListener doesn't properly support compression; it will error with a 501 if you set the `Transfer-Encoding` header to either `gzip` or `deflate`.

!!! note
    The Pode server does also support `X-Transfer-Encoding`, but it will check `Transfer-Encoding` first.

An example of the header in the request is as follows:

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

Using the `server.psd1` configuration file, you can define a default transfer encoding to use for every route, or you can define patterns to match multiple route paths to set transfer encodings on mass.

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

## Precedence

The transfer encoding that will be used is determined by the following order:

1. Being defined on the Route.
2. The Route matches a pattern defined in the configuration file.
3. A default transfer encoding is defined in the configuration file.
4. The transfer encoding is supplied on the web request.

## Example

The following is an example of sending a `gzip` encoded payload to some `/ping` route:

```powershell
# get the JSON message in bytes
$data = @{
    Name = "Deepthought"
    Age = 42
}

$message = ($data | ConvertTo-Json)
$bytes = [System.Text.Encoding]::UTF8.GetBytes($message)

# compress the message using gzip
$ms = New-Object -TypeName System.IO.MemoryStream
$gzip = New-Object System.IO.Compression.GZipStream($ms, [IO.Compression.CompressionMode]::Compress, $true)
$gzip.Write($bytes, 0, $bytes.Length)
$gzip.Close()
$ms.Position = 0

# Pode Server
Invoke-RestMethod `
    -Method Post `
    -Uri 'http://localhost:8080/ping' `
    -Body $ms.ToArray() `
    -TransferEncoding gzip `
    -ContentType application/json

# HttpListener Server
Invoke-RestMethod `
    -Method Post `
    -Uri 'http://localhost:8080/ping' `
    -Body $ms.ToArray() `
    -ContentType application/json `
    -Headers @{'X-Transfer-Encoding' = 'gzip'}
```
