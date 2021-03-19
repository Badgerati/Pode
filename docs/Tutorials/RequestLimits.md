# Request Limits

When making requests to the server, there are some limits that will cause the request to fail. These limits mostly cover web requests, and can be altered in the [`server.psd1`](../Configuration) configuration file.

## Timeout

There is a default request timeout of 30 seconds, exceeding this will force the connection to close. In the case of a web request, a 408 HTTP status code will be returned.

You can edit the timeout in the `server.psd1` file:

```powershell
@{
    Server = @{
        Request = @{
            Timeout = 30
        }
    }
}
```

The value supplied should be in seconds.

## Body Size

On web requests there is a default max request body size of 100MB, exceeding this will cause a 413 HTTP status code to be returned.

You can edit the max body size in the `server.psd1` file:

```powershell
@{
    Server = @{
        Request = @{
            BodySize = 100MB
        }
    }
}
```

The value supplied should be in bytes, or using the PowerShell notation `100MB`.
