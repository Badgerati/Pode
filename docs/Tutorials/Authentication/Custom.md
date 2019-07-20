# Custom Authentication

Custom authentication works much like the inbuilt types, but allows you to specify your own parsing logic, as well as any custom options that might be required.

## Setup and Parsing

To setup and start using Custom authentication in Pode you can set `auth use -c <name>` in you server script. The `<name>` can be anything you want, even the name of an inbuilt method (it will still use your custom logic!).

Let's say we wanted something similar to [`Form`](../Form) authentication but it requires a third piece of information: `ClientName`. To setup Custom authentication for this method, you'll need to specify the parsing scriptblock under `-p`, as well as the validator script too.

The parsing script will be passed the current web event (containing the `Request`/`Response` objects, much like a `route`). In this script you can parse the request payload/headers for any credential information that needs validating. Once sourced, the data returned from the script should be either a `hashtable` or an `array`; this data will then `splatted` onto the validator scriptblock ([info](../../../Functions/Helpers/Invoke-PodeScriptBlock)):

```powershell
Start-PodeServer {
    # here we're calling the custom method "client"
    auth use -c client -p {
        # the current web event, and auth method options supplied
        param($event, $opts)

        # get client/user/pass field names to get from payload
        $clientField = (Protect-PodeValue -Value $opts.ClientField -Default 'client')
        $userField = (Protect-PodeValue -Value $opts.UsernameField -Default 'username')
        $passField = (Protect-PodeValue -Value $opts.PasswordField -Default 'password')

        # get the client/user/pass from the post data
        $client = $event.Data.$clientField
        $username = $event.Data.$userField
        $password = $event.Data.$passField

        # return the data, to be passed to the validator script
        return @($client, $username, $password)
    } `
    -v {
        param($client, $username, $password)

        # check if the client is valid

        return  @{ 'user' = $user }
    }
}
```

## Validating

Once configured you can start using the Custom authentication to validate incoming requests. You can either configure the validation to happen on every `route` as global `middleware`, or as custom `route` middleware.

The following will use Custom authentication to validate every request on every `route`:

```powershell
Start-PodeServer {
    middleware (auth check client)
}
```

Whereas the following example will use Custom authentication to only validate requests on specific a `route`:

```powershell
Start-PodeServer {
    Add-PodeRoute -Method Get -Path '/info' -Middleware (auth check login) -ScriptBlock {
        # logic
    }
}
```

## Full Example

The following full example of Custom authentication will setup and configure authentication, validate that a users client/username/password is valid, and then validate on a specific `route`:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address *:8080 -Protocol Http

    # here we're calling the custom method "client"
    auth use -c client -p {
        # the current web event, and auth method options supplied
        param($event, $opts)

        # get client/user/pass field names to get from payload
        $clientField = (Protect-PodeValue -Value $opts.ClientField -Default 'client')
        $userField = (Protect-PodeValue -Value $opts.UsernameField -Default 'username')
        $passField = (Protect-PodeValue -Value $opts.PasswordField -Default 'password')

        # get the client/user/pass from the post data
        $client = $event.Data.$clientField
        $username = $event.Data.$userField
        $password = $event.Data.$passField

        # return the data, to be passed to the validator script
        return @($client, $username, $password)
    } `
    -v {
        param($client, $username, $password)

        # check if the client is valid

        return  @{ 'user' = $user }
    }

    # check the request on this route against the authentication
    Add-PodeRoute -Method Get -Path '/cpu' -Middleware (auth check client) -ScriptBlock {
        Write-PodeJsonResponse -Value @{ 'cpu' = 82 }
    }

    # this route will not be validated against the authentication
    Add-PodeRoute -Method Get -Path '/memory' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ 'memory' = 14 }
    }
}
```

Below is an example HTML page that would POST the client/username/password to the server above:

```html
<form action="/login" method="post">
    <div>
        <label>Client:</label>
        <input type="text" name="client"/>
    </div>
    <div>
        <label>Username:</label>
        <input type="text" name="username"/>
    </div>
    <div>
        <label>Password:</label>
        <input type="password" name="password"/>
    </div>
    <div>
        <input type="submit" value="Login"/>
    </div>
</form>
```

## Use Options

!!! info
    There are no `use` options for custom types, unless you define your own.