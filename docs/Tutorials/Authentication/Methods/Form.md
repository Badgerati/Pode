# Form

Form Authentication is for when you're using a `<form>` in HTML, and you submit the form. This Authentication method expects a `username` and `password` to be passed from the form's input fields.

## Setup

To setup and start using Form Authentication in Pode you use the `New-PodeAuthType -Form` function, and then pipe this into the [`Add-PodeAuth`](../../../../../Functions/Authentication/Add-PodeAuth) function:

```powershell
Start-PodeServer {
    New-PodeAuthType -Form | Add-PodeAuth -Name 'Login' -ScriptBlock {
        param($username, $password)

        # check if the user is valid

        return @{ User = $user }
    }
}
```

By default, Pode will check if the Request's payload contains a `username` and `password` fields. The `New-PodeAuthType -Form` function can be supplied parameters to allow for custom names of these fields.

For example, to look for the field `email` rather than the default `username` you could do:

```powershell
Start-PodeServer {
    New-PodeAuthType -Form -UsernameField 'email' | Add-PodeAuth -Name 'Login' -ScriptBlock {}
}
```

## Validating

Once configured you can start using Form Authentication to validate incoming Requests. You can either configure the validation to happen on every Route as global Middleware, or as custom Route Middleware.

The following will use Form Authentication to validate every request on every Route:

```powershell
Start-PodeServer {
    Get-PodeAuthMiddleware -Name 'Login' | Add-PodeMiddleware -Name 'GlobalAuthValidation'
}
```

Whereas the following example will use Form Authentication to only validate requests on specific a Route:

```powershell
Start-PodeServer {
    Add-PodeRoute -Method Get -Path '/info' -Middleware (Get-PodeAuthMiddleware -Name 'Login') -ScriptBlock {
        # logic
    }
}
```

## Full Example

The following full example of Form authentication will setup and configure authentication, validate that a users username/password is valid, and then validate on a specific Route:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address *:8080 -Protocol Http

    # setup form authentication to validate a user
    New-PodeAuthType -Form | Add-PodeAuth -Name 'Login' -ScriptBlock {
        param($username, $password)

        # here you'd check a real user storage, this is just for example
        if ($username -eq 'morty' -and $password -eq 'pickle') {
            return @{ 'user' = @{
                'ID' ='M0R7Y302'
                'Name' = 'Morty';
                'Type' = 'Human';
            } }
        }

        return $null
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

Below is an example HTML page that would POST the username/password to the server above:

```html
<form action="/login" method="post">
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
