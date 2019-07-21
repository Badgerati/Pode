# Form Authentication

Form authentication is for when you're using a `<form>` in HTML, and you submit the form. The method expects a `username` and `password` to be passed from the form input fields.

## Setup

To setup and start using Form authentication in Pode you specify `auth use <name> -t form` in your server script, the validator script you need to supply will have the username/password supplied as arguments to the scriptblock:

```powershell
Start-PodeServer {
    auth use login -t form -v {
        param($username, $password)

        # check if the user is valid

        return @{ 'user' = $user }
    }
}
```

By default, Pode will check if the request's payload (from POST) contains a `username` and `password` field. The `auth use` action can be supplied options via `-o` to override the names of these fields for anything custom.

For example, to look for the field `email` rather than rather than the default `username` you could do:

```powershell
Start-PodeServer {
    auth use login -t form -v {
        # check
    } -o @{ 'UsernameField' = 'email' }
}
```

More options can be seen further below.

## Validating

Once configured you can start using Form authentication to validate incoming requests. You can either configure the validation to happen on every `route` as global `middleware`, or as custom `route` middleware.

The following will use Form authentication to validate every request on every `route`:

```powershell
Start-PodeServer {
    (auth check login) | Add-PodeMiddleware -Name 'GlobalAuthValidation'
}
```

Whereas the following example will use Form authentication to only validate requests on specific a `route`:

```powershell
Start-PodeServer {
    Add-PodeRoute -Method Get -Path '/info' -Middleware (auth check login) -ScriptBlock {
        # logic
    }
}
```

## Full Example

The following full example of Form authentication will setup and configure authentication, validate that a users username/password is valid, and then validate on a specific `route`:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address *:8080 -Protocol Http

    # setup form authentication to validate a user
    auth use login -t form -v {
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
    Add-PodeRoute -Method Get -Path '/cpu' -Middleware (auth check login) -ScriptBlock {
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

## Use Options

| Name | Description | Default |
| ---- | ----------- | ------- |
| UsernameField | Defines the name of field which the username will be passed in from the `<form>` | username |
| PasswordField | Defines the name of field which the password will be passed in from the `<form>` | password |