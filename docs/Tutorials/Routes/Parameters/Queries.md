# Queries

The following is an example of using data from a request's query string. To retrieve values from the query parameters, you can use the `Query` property on the `$WebEvent` variable in a route's logic.

Alternatively, you can use the `Get-PodeQueryParameter` function to retrieve the query parameter data, with additional support for deserialization.

This example will return a user based on the `userId` supplied:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address * -Port 8080 -Protocol Http

    Add-PodeRoute -Method Get -Path '/users' -ScriptBlock {
        # get the user
        $user = Get-DummyUser -UserId $WebEvent.Query['userId']

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
Invoke-WebRequest -Uri 'http://localhost:8080/users?userId=12345' -Method Get
```

### Using Get-PodeQueryParameter

Alternatively, you can use the `Get-PodeQueryParameter` function to retrieve the query data. This function works similarly to the `Query` property on `$WebEvent` but provides additional options for deserialization when needed.

Here is the same example using `Get-PodeQueryParameter`:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address * -Port 8080 -Protocol Http

    Add-PodeRoute -Method Get -Path '/users' -ScriptBlock {
        # get the query data
        $userId = Get-PodeQueryParameter -Name 'userId'

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

#### Deserialization with Get-PodeQueryParameter

The `Get-PodeQueryParameter` function can also deserialize query parameters passed in the URL, using specific styles to interpret the data correctly. This feature is particularly useful when handling complex data structures or encoded parameter values.

To enable deserialization, use the `-Deserialize` switch along with the following options:

- **`-NoExplode`**: Prevents deserialization from exploding arrays when handling comma-separated values. This is useful when array expansion is not desired.
- **`-Style`**: Defines the deserialization style (`'Simple'`, `'Label'`, `'Matrix'`, `'Form'`, `'SpaceDelimited'`, `'PipeDelimited'`, `'DeepObject'`) to interpret the query parameter value correctly. The default style is `'Form'`.
- **`-KeyName`**: Specifies the key name to use when deserializing, allowing you to map the query parameter data accurately. The default value for `KeyName` is `'id'`.

#### Supported Deserialization Styles


| Style          | Explode | URI Template | Primitive Value (id = 5) | Array (id = [3, 4, 5]) | Object (id = {"role": "admin", "firstName": "Alex"}) |
|----------------|---------|--------------|--------------------------|------------------------|------------------------------------------------------|
| form*           | true*    | /users{?id*} | /users?id=5              | /users?id=3&id=4&id=5  | /users?role=admin&firstName=Alex                     |
| form           | false   | /users{?id}  | /users?id=5              | /users?id=3,4,5        | /users?id=role,admin,firstName,Alex                  |
| spaceDelimited | true    | /users{?id*} | n/a                      | /users?id=3&id=4&id=5  | n/a                                                  |
| spaceDelimited | false   | n/a          | n/a                      | /users?id=3%204%205    | n/a                                                  |
| pipeDelimited  | true    | /users{?id*} | n/a                      | /users?id=3&id=4&id=5  | n/a                                                  |
| pipeDelimited   | false   | n/a              | n/a                      | /users?id=3|4|5              | n/a                                                              |
| deepObject      | true    | n/a              | n/a                      | n/a                          | /users?id[role]=admin&id[firstName]=Alex                         |


\* Default serialization method

#### Example with Deserialization

This example demonstrates deserialization of a query parameter with specific styles and options:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address * -Port 8080 -Protocol Http

    Add-PodeRoute -Method Get -Path '/items' -ScriptBlock {
        # retrieve and deserialize the 'filter' query parameter
        $filter = Get-PodeQueryParameter -Name 'filter' -Deserialize -Style 'SpaceDelimited' -NoExplode

        # get items based on the deserialized filter data
        $items = Get-DummyItems -Filter $filter

        # return the item details
        Write-PodeJsonResponse -Value $items
    }
}
```

In this example, the `Get-PodeQueryParameter` function is used to deserialize the `filter` query parameter, interpreting it according to the specified style (`SpaceDelimited`) and preventing array explosion (`-NoExplode`). This approach allows for dynamic and precise handling of complex query data, enhancing the flexibility of your Pode routes.