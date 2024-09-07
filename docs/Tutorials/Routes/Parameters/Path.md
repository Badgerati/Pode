
# Path

The following is an example of using values supplied on a request's URL using parameters. To retrieve values that match a request's URL parameters, you can use the `Parameters` property from the `$WebEvent` variable.

Alternatively, you can use the `Get-PodePathParameter` function to retrieve the parameter data.

This example will get the `:userId` and "find" user, returning the user's data:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address * -Port 8080 -Protocol Http

    Add-PodeRoute -Method Get -Path '/users/:userId' -ScriptBlock {
        # get the user
        $user = Get-DummyUser -UserId $WebEvent.Parameters['userId']

        # return the user
        Write-PodeJsonResponse -Value @{
            Username = $user.username
            Age = $user.age
        }
    }
}
```

The following request will invoke the above route:

```powershell
Invoke-WebRequest -Uri 'http://localhost:8080/users/12345' -Method Get
```

### Using Get-PodePathParameter

Alternatively, you can use the `Get-PodePathParameter` function to retrieve the parameter data. This function works similarly to the `Parameters` property on `$WebEvent` but provides additional options for deserialization when needed.

Here is the same example using `Get-PodePathParameter`:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address * -Port 8080 -Protocol Http

    Add-PodeRoute -Method Get -Path '/users/:userId' -ScriptBlock {
        # get the parameter data
        $userId = Get-PodePathParameter -Name 'userId'

        # get the user
        $user = Get-DummyUser -UserId $userId

        # return the user
        Write-PodeJsonResponse -Value @{
            Username = $user.username
            Age = $user.age
        }
    }
}
```

#### Deserialization with Get-PodePathParameter

The `Get-PodePathParameter` function can handle deserialization of parameters passed in the URL path, query string, or body, using specific styles to interpret the data correctly. This is useful when dealing with more complex data structures or encoded parameter values.

To enable deserialization, use the `-Deserialize` switch along with the following options:

- **`-Explode`**: Specifies whether to explode arrays when deserializing, useful when parameters contain comma-separated values.
- **`-Style`**: Defines the deserialization style (`'Simple'`, `'Label'`, or `'Matrix'`) to interpret the parameter value correctly. The default style is `'Simple'`.
- **`-KeyName`**: Specifies the key name to use when deserializing, allowing you to map the parameter data accurately. The default value for `KeyName` is `'id'`.

#### Example with Deserialization

This example demonstrates deserialization of a parameter that is styled and exploded as part of the request:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address * -Port 8080 -Protocol Http

    Add-PodeRoute -Method Get -Path '/items/:itemId' -ScriptBlock {
        # retrieve and deserialize the 'itemId' parameter
        $itemId = Get-PodePathParameter -Name 'itemId' -Deserialize -Style 'Label' -Explode

        # get the item based on the deserialized data
        $item = Get-DummyItem -ItemId $itemId

        # return the item details
        Write-PodeJsonResponse -Value @{
            Name = $item.name
            Quantity = $item.quantity
        }
    }
}
```

In this example, the `Get-PodePathParameter` function is used to deserialize the `itemId` parameter, interpreting it according to the specified style (`Label`) and handling arrays if present (`-Explode`). The default `KeyName` is `'id'`, but it can be customized as needed. This approach allows for dynamic and precise handling of incoming request data, making your Pode routes more versatile and resilient.