# Custom

Custom authentication works much like the inbuilt types (Basic and Form), but allows you to specify your own parsing logic, as well as any custom options that might be required.

## Setup and Parsing

To setup and start using Custom authentication in Pode you use the `New-PodeAuthType -Custom` function, and then pipe this into the [`Add-PodeAuth`](../../../../../Functions/Authentication/Add-PodeAuth) function.

Let's say we wanted something similar to [`Form`](../Form) Authentication, but it requires a third piece of information: `ClientName`. To setup Custom Authentication for this method, you'll need to specify the parsing logic within the `-ScriptBlock`.

The `-ScriptBlock` on [`New-PodeAuthType`](../../../../../Functions/Authentication/New-PodeAuthType) will be passed the current web event (containing the `Request`/`Response` objects, much like a Route). In this script you can parse the Request payload/headers for any credential information that needs validating. Once sourced, the data returned from the script should be either an `array`, which will then splatted onto the `-ScriptBlock` from your [`New-PodeAuthType`](../../../../../Functions/Authentication/New-PodeAuthType) function:

```powershell
Start-PodeServer {
    # define a new custom authentication type
    $custom_type = New-PodeAuthType -Custom -ScriptBlock {
        param($e, $opts)

        # get client/user/pass field names to get from payload
        $clientField = (Protect-PodeValue -Value $opts.ClientField -Default 'client')
        $userField = (Protect-PodeValue -Value $opts.UsernameField -Default 'username')
        $passField = (Protect-PodeValue -Value $opts.PasswordField -Default 'password')

        # get the client/user/pass from the post data
        $client = $e.Data.$clientField
        $username = $e.Data.$userField
        $password = $e.Data.$passField

        # return the data, to be passed to the validator script
        return @($client, $username, $password)
    }

    # now, add a new custom authentication method
    $custom_type | Add-PodeAuth -Name 'Login' -ScriptBlock {
        param($client, $username, $password)

        # check if the client is valid

        return  @{ User = $user }
    }
}
```

## Validating

Once configured you can start using the Custom Authentication to validate incoming Requests. You can either configure the validation to happen on every Route as global Middleware, or as custom Route Middleware.

The following will use Custom Authentication to validate every request on every Route:

```powershell
Start-PodeServer {
    Get-PodeAuthMiddleware -Name 'Login' | Add-PodeMiddleware -Name 'GlobalAuthValidation'
}
```

Whereas the following example will use Custom authentication to only validate requests on specific a `route`:

```powershell
Start-PodeServer {
    Add-PodeRoute -Method Get -Path '/info' -Middleware (Get-PodeAuthMiddleware -Name 'Login') -ScriptBlock {
        # logic
    }
}
```

## Full Example

The following full example of Custom authentication will setup and configure authentication, validate that a users client/username/password is valid, and then validate on a specific `route`:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address *:8080 -Protocol Http

    # define a new custom authentication type
    $custom_type = New-PodeAuthType -Custom -ScriptBlock {
        param($e, $opts)

        # get client/user/pass field names to get from payload
        $clientField = (Protect-PodeValue -Value $opts.ClientField -Default 'client')
        $userField = (Protect-PodeValue -Value $opts.UsernameField -Default 'username')
        $passField = (Protect-PodeValue -Value $opts.PasswordField -Default 'password')

        # get the client/user/pass from the post data
        $client = $e.Data.$clientField
        $username = $e.Data.$userField
        $password = $e.Data.$passField

        # return the data, to be passed to the validator script
        return @($client, $username, $password)
    }

    # now, add a new custom authentication method
    $custom_type | Add-PodeAuth -Name 'Login' -ScriptBlock {
        param($client, $username, $password)

        # check if the client is valid

        return  @{ User = $user }
    }

    # check the request on this route against the authentication
    Add-PodeRoute -Method Get -Path '/cpu' -Middleware (Get-PodeAuthMiddleware -Name 'Login') -ScriptBlock {
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
