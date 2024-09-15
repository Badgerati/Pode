# Headers

The following is an example of using values supplied in a request's headers. To retrieve values from the headers, you can use the `Headers` property from the `$WebEvent.Request` variable. Alternatively, you can use the `Get-PodeHeader` function to retrieve the header data.

This example will get the Authorization header and validate the token, returning a success message:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address * -Port 8080 -Protocol Http

    Add-PodeRoute -Method Get -Path '/validate' -ScriptBlock {
        # get the token
        $token = $WebEvent.Request.Headers['Authorization']

        # validate the token
        $isValid = Test-PodeJwt -payload $token

        # return the result
        Write-PodeJsonResponse -Value @{
            Success = $isValid
        }
    }
}
```

The following request will invoke the above route:

```powershell
Invoke-WebRequest -Uri 'http://localhost:8080/validate' -Method Get -Headers @{ Authorization = 'Bearer some_token' }
```

## Using Get-PodeHeader

Alternatively, you can use the `Get-PodeHeader` function to retrieve the header data. This function works similarly to the `Headers` property on `$WebEvent.Request`.

Here is the same example using `Get-PodeHeader`:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address * -Port 8080 -Protocol Http

    Add-PodeRoute -Method Get -Path '/validate' -ScriptBlock {
        # get the token
        $token = Get-PodeHeader -Name 'Authorization'

        # validate the token
        $isValid = Test-PodeJwt -payload $token

        # return the result
        Write-PodeJsonResponse -Value @{
            Success = $isValid
        }
    }
}
```

### Deserialization with Get-PodeHeader

The `Get-PodeHeader` function can also deserialize header values, enabling more advanced handling of serialized data sent in headers. This feature is useful when dealing with complex data structures or when headers contain encoded or serialized content.

To enable deserialization, use the `-Deserialize` switch along with the following options:

- **`-Explode`**: Specifies whether the deserialization process should explode arrays in the header value. This is useful when handling comma-separated values within the header.
- **`-Deserialize`**: Indicates that the retrieved header value should be deserialized, interpreting the content based on the deserialization style and options.

#### Supported Deserialization Styles

| Style   | Explode | URI Template | Primitive Value (X-MyHeader = 5) | Array (X-MyHeader = [3, 4, 5]) | Object (X-MyHeader = {"role": "admin", "firstName": "Alex"}) |
|---------|---------|--------------|----------------------------------|--------------------------------|--------------------------------------------------------------|
| simple* | false*  | {id}         | X-MyHeader: 5                    | X-MyHeader: 3,4,5              | X-MyHeader: role,admin,firstName,Alex                        |
| simple  | true    | {id*}        | X-MyHeader: 5                    | X-MyHeader: 3,4,5              | X-MyHeader: role=admin,firstName=Alex                        |

\* Default serialization method

### Example with Deserialization

This example demonstrates deserialization of a header value:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address * -Port 8080 -Protocol Http

    Add-PodeRoute -Method Get -Path '/deserialize' -ScriptBlock {
        # retrieve and deserialize the 'X-SerializedHeader' header
        $headerData = Get-PodeHeader -Name 'X-SerializedHeader' -Deserialize -Explode

        # process the deserialized header data
        # (example processing logic here)

        # return the processed header data
        Write-PodeJsonResponse -Value @{
            HeaderData = $headerData
        }
    }
}
```

In this example, `Get-PodeHeader` is used to deserialize the `X-SerializedHeader` header, interpreting it according to the provided deserialization options. The `-Explode` switch ensures that any arrays within the header value are properly expanded during deserialization.

For further information regarding serialization, please refer to the [RFC6570](https://tools.ietf.org/html/rfc6570).

For further information on general usage and retrieving headers, please refer to the [Headers Documentation](Headers.md).
