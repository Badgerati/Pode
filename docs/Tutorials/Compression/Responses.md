# Responses

Pode has support for sending back compressed Responses, if enabled, and if a client sends an appropriate `Accept-Encoding` header.

The followings compression methods are supported:

* gzip
* deflate

When enabled, Pode will compress the response's bytes prior to sending the response; the `Content-Encoding` header will also be sent appropriately on the response.

## Enable

By default response compression is disabled in Pode. To enable compression you can set the following value in your server's `server.psd1` [configuration](../../Configuration) file:

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

## Headers

For your Pode server to compress the response, the client must send an `Accept-Encoding` header for with `gzip` or `deflate`:

```text
Accept-Encoding: gzip
Accept-Encoding: deflate
Accept-Encoding: identity
Accept-Encoding: *
```

Or any valid combination:

```text
Accept-Encoding: gzip,deflate
```

If multiple encodings are sent, then Pode will use the first supported value. There is also support for quality values as well, so you can weight encodings or fully disable non-compression (if no q-value is on an encoding it is assumed to be 1)

```text
Accept-Encoding: gzip,deflate,identity;q=0
```

In a scenario where no encodings are supported, and identity (no-compression) is disabled, then Pode will respond with a 406.

If an encoding is used to compress the response, then Pode will set the `Content-Encoding` on the response.
