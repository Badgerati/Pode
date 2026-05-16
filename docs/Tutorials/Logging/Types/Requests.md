# Requests

Pode has an inbuilt Request logging Type, which will parse and transform a valid log item for use with any supplied logging Method.

## Enabling

To enable and use the Request logging Type you use [`Enable-PodeRequestLogging`](../../../../Functions/Logging/Enable-PodeRequestLogging), supplying a logging Method - such as the [Terminal](../../Methods/Terminal) Method.

The Request logging Type will transform a supplied raw log item into a [Combined Log Format](https://httpd.apache.org/docs/1.3/logs.html#combined) string. This string is then supplied to the logging Method's scriptblock. If you're using a Custom logging method and want the raw log item instead, you can supply `-Raw` to [`Enable-PodeRequestLogging`](../../../../Functions/Logging/Enable-PodeRequestLogging).

## Examples

### Log to Terminal

The following example simply enables Request logging, and will output all items to the terminal:

```powershell
New-PodeLogTerminalMethod | Enable-PodeRequestLogging
```

### Using Raw Item

The following example uses a Custom logging Method, and sets Request logging Type to return and supply the raw log item to the Custom method's scriptblock instead of a transformed one. The Custom Method simply logs the Host and StatusCode to the terminal (but could be to something like an S3 bucket):

```powershell
$method = New-PodeLogCustomMethod -ScriptBlock {
    param($item)
    "$($item.Host) - $($item.Response.StatusCode)" | Out-Default
}

$method | Enable-PodeRequestLogging -Raw
```

### Username

If you're not using any Authentication then the "user" field in the log will always be "-". However, if you're using Authentication, and it passes, then the Username of the user accessing the Route will attempt to be retrieved from `$WebEvent.Auth.User`. The property within the authenticated user object by default is `Username`, but you can customise this using `-UsernameProperty`.

For example, if the username was actually user "ID":

```powershell
Enable-PodeRequestLogging -UsernameProperty 'ID'
```

Or if the username was inside another "Meta" property, and then within a "Username" property inside the Meta object:

```powershell
Enable-PodeRequestLogging -UsernameProperty 'Meta.Username'
```

## Raw Request

The raw log item that the Request log Type will supply to any Custom logging Methods will look as follows:

```powershell
@{
    Host = '10.10.0.3'
    RfcUserIdentity = '-'
    User = '-'
    Date = '14/Jun/2018:20:23:52 +01:00'
    Request = @{
        Method = 'GET'
        Resource = '/api/users'
        Protocol = "HTTP/1.1"
        Referrer = '-'
        Agent = '<user-agent>'
    }
    Response = @{
        StatusCode = '200'
        StatusDescription = 'OK'
        Size = '9001'
    }
}
```
