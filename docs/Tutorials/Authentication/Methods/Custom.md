# Custom

Custom authentication works much like the inbuilt types (Basic/Form/etc), but allows you to specify your own parsing logic, as well as any custom options that might be required.

## Setup and Parsing

To setup and start using Custom authentication in Pode you use the `New-PodeAuthScheme -Custom` function, and then pipe this into the [`Add-PodeAuth`](../../../../Functions/Authentication/Add-PodeAuth) function.

Let's say we wanted something similar to [`Form`](../Form) Authentication, but it requires a third piece of information: `ClientName`. To setup Custom Authentication for this method, you'll need to specify the parsing logic within the `-ScriptBlock` of the [`New-PodeAuthScheme`](../../../../Functions/Authentication/New-PodeAuthScheme) function.

The `-ScriptBlock` on [`New-PodeAuthScheme`](../../../../Functions/Authentication/New-PodeAuthScheme) will be passed the current [web event](../../../WebEvent) (containing the `Request`/`Response` objects, and other pieces of information much like on Routes or Middleware). In this script you can parse the Request payload/headers for any credential information that needs validating. Once sourced the data returned from the script should be an `array`, which will then splatted onto the `-ScriptBlock` from your [`Add-PodeAuth`](../../../../Functions/Authentication/Add-PodeAuth) function:

```powershell
Start-PodeServer {
    # define a new custom authentication type
    $custom_type = New-PodeAuthScheme -Custom -ScriptBlock {
        param($e, $opts)

        # get client/user/password field names
        $clientField = (Protect-PodeValue -Value $opts.ClientField -Default 'client')
        $userField = (Protect-PodeValue -Value $opts.UsernameField -Default 'username')
        $passField = (Protect-PodeValue -Value $opts.PasswordField -Default 'password')

        # get the client/user/password from the request's post data
        $client = $e.Data.$clientField
        $username = $e.Data.$userField
        $password = $e.Data.$passField

        # return the data in a array, which will be passed to the validator script
        return @($client, $username, $password)
    }

    # now, add a new custom authentication method using the type you created above
    $custom_type | Add-PodeAuth -Name 'Login' -ScriptBlock {
        param($client, $username, $password)

        # check if the client is valid in some database

        # return a user object (return $null if validation failed)
        return  @{ User = $user }
    }
}
```

!!! note
    The `$opts` parameter in the `New-PodeAuthScheme` ScriptBlock come from the `-ArgumentList` HashTable.

## Post Validation

The typical setup of authentication is that you create some type to parse the request ([`New-PodeAuthScheme`](../../../../Functions/Authentication/New-PodeAuthScheme)), and then you pipe this into a validator/method to validate the parsed user's credentials ([`Add-PodeAuth`](../../../../Functions/Authentication/Add-PodeAuth)).

There is however also an optional `-PostValidator` ScriptBlock that can be passed to your Custom Authentication type on the [`New-PodeAuthScheme`](../../../../Functions/Authentication/New-PodeAuthScheme) function. This `-PostValidator` script runs after normal user validation, and is supplied the current [web event](../../../WebEvent), the original splatted array returned from the [`New-PodeAuthScheme`](../../../../Functions/Authentication/New-PodeAuthScheme) ScriptBlock, the result HashTable from the user validator from `Add-PodeAuth`, and the `-ArgumentList` HashTable from `New-PodeAuthScheme`. You can use this script to re-generate any hashes for further validation, but if successful you *must* return the User object again (ie: re-return the last parameter which is the original validation result).

For example, if you have a post validator script for the above Client Custom Authentication, then it would be supplied the following parameters:

* Web Event
* ClientName
* Username
* Password
* ClientName
* Validation Result
* Type ArgumentsList

For example:

```powershell
Start-PodeServer {
    # define a new custom authentication type
    $custom_type = New-PodeAuthScheme -Custom -ScriptBlock {
        param($e, $opts)

        # get client/user/password field names
        $clientField = (Protect-PodeValue -Value $opts.ClientField -Default 'client')
        $userField = (Protect-PodeValue -Value $opts.UsernameField -Default 'username')
        $passField = (Protect-PodeValue -Value $opts.PasswordField -Default 'password')

        # get the client/user/password from the request's post data
        $client = $e.Data.$clientField
        $username = $e.Data.$userField
        $password = $e.Data.$passField

        # return the data in a array, which will be passed to the validator script
        return @($client, $username, $password)
    } `
    -PostValidator {
        param($e, $client, $username, $password, $result, $opts)

        # run any extra post-validation logic

        # the result is the object returned from the below scriptblock
        return $result
    }

    # now, add a new custom authentication method using the type you created above
    $custom_type | Add-PodeAuth -Name 'Login' -ScriptBlock {
        param($client, $username, $password)

        # check if the client is valid in some database

        # return a user object (return $null if validation failed)
        return  @{ User = $user }
    }
}
```

## Middleware

Once configured you can start using the Custom Authentication to validate incoming Requests. You can either configure the validation to happen on every Route as global Middleware, or as custom Route Middleware.

The following will use Custom Authentication to validate every request on every Route:

```powershell
Start-PodeServer {
    Add-PodeAuthMiddleware -Name 'GlobalAuthValidation' -Authentication 'Login'
}
```

Whereas the following example will use Custom authentication to only validate requests on specific a Route:

```powershell
Start-PodeServer {
    Add-PodeRoute -Method Get -Path '/info' -Authentication 'Login' -ScriptBlock {
        # logic
    }
}
```

## Full Example

The following full example of Custom authentication will setup and configure authentication, validate that a users client/username/password is valid, and then validate on a specific `route`:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address * -Port 8080 -Protocol Http

    # define a new custom authentication type
    $custom_type = New-PodeAuthScheme -Custom -ScriptBlock {
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
    $custom_type | Add-PodeAuth -Name 'Login' -Sessionless -ScriptBlock {
        param($client, $username, $password)

        # check if the client is valid

        # return a user object (return $null if validation failed)
        return  @{ User = $user }
    }

    # check the request on this route against the authentication
    Add-PodeRoute -Method Get -Path '/cpu' -Authentication 'Login' -ScriptBlock {
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
