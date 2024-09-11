
# Cookies

The following is an example of using values supplied in a request's cookies. To retrieve values from the cookies, you can use the `Cookies` property from the `$WebEvent` variable.

Alternatively, you can use the `Get-PodeCookie` function to retrieve the cookie data, with additional support for deserialization and secure handling.

This example will get the `SessionId` cookie and use it to authenticate the user, returning a success message:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address * -Port 8080 -Protocol Http

    Add-PodeRoute -Method Get -Path '/authenticate' -ScriptBlock {
        # get the session ID from the cookie
        $sessionId = $WebEvent.Cookies['SessionId']

        # authenticate the session
        $isAuthenticated = Authenticate-Session -SessionId $sessionId

        # return the result
        Write-PodeJsonResponse -Value @{
            Authenticated = $isAuthenticated
        }
    }
}
```

The following request will invoke the above route:

```powershell
Invoke-WebRequest -Uri 'http://localhost:8080/authenticate' -Method Get -Headers @{ Cookie = 'SessionId=abc123' }
```

## Using Get-PodeCookie

Alternatively, you can use the `Get-PodeCookie` function to retrieve the cookie data. This function works similarly to the `Cookies` property on `$WebEvent`, but it provides additional options for deserialization and secure cookie handling.

Here is the same example using `Get-PodeCookie`:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address * -Port 8080 -Protocol Http

    Add-PodeRoute -Method Get -Path '/authenticate' -ScriptBlock {
        # get the session ID from the cookie
        $sessionId = Get-PodeCookie -Name 'SessionId'

        # authenticate the session
        $isAuthenticated = Authenticate-Session -SessionId $sessionId

        # return the result
        Write-PodeJsonResponse -Value @{
            Authenticated = $isAuthenticated
        }
    }
}
```

### Deserialization with Get-PodeCookie

The `Get-PodeCookie` function can also deserialize cookie values, allowing for more complex handling of serialized data sent in cookies. This feature is particularly useful when cookies contain encoded or structured content that needs specific parsing.

To enable deserialization, use the `-Deserialize` switch along with the following options:

- **`-NoExplode`**: Prevents deserialization from exploding arrays in the cookie value. This is useful when handling comma-separated values where array expansion is not desired.
- **`-Deserialize`**: Indicates that the retrieved cookie value should be deserialized, interpreting the content based on the provided deserialization style and options.



#### Supported Deserialization Styles

| Style | Explode | URI Template | Primitive Value (id = 5) | Array (id = [3, 4, 5]) | Object (id = {"role": "admin", "firstName": "Alex"}) |
|-------|---------|--------------|--------------------------|------------------------|------------------------------------------------------|
| form* | true*   |              | Cookie: id=5             |                        |                                                      |
| form  | false   | id={id}      | Cookie: id=5             | Cookie: id=3,4,5       | Cookie: id=role,admin,firstName,Alex                 |

\* Default serialization method

### Example with Deserialization

This example demonstrates deserialization of a cookie value:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address * -Port 8080 -Protocol Http

    Add-PodeRoute -Method Get -Path '/deserialize-cookie' -ScriptBlock {
        # retrieve and deserialize the 'Session' cookie
        $sessionData = Get-PodeCookie -Name 'Session' -Deserialize -NoExplode

        # process the deserialized cookie data
        # (example processing logic here)

        # return the processed cookie data
        Write-PodeJsonResponse -Value @{
            SessionData = $sessionData
        }
    }
}
```

In this example, `Get-PodeCookie` is used to deserialize the `Session` cookie, interpreting it according to the provided deserialization options. The `-NoExplode` switch ensures that any arrays within the cookie value are not expanded during deserialization.

For further information on general usage and retrieving cookies, please refer to the [Headers Documentation](Cookies.md).