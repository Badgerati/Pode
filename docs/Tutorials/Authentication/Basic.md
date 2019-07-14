# Basic Authentication

Basic authentication is when you pass an encoded `username:password` value on the header of your requests: `@{ 'Authorization' = 'Basic <base64 encoded username:password>' }`.

## Setup

To setup and start using Basic authentication in Pode you can call `auth use <name> -t basic` in your server script, the validator script you need to supply will have the username/password passed as arguments to the scriptblock:

```powershell
Start-PodeServer {
    auth use login -t basic -v {
        param($username, $password)

        # check if the user is valid

        return @{ 'user' = $user }
    }
}
```

By default, Pode will check if the request's header contains an `Authorization` key, and whether the value of that key starts with `Basic`. The `auth use` action can be supplied options via `-o` to override the start name of the value, as well as the encoding that Pode uses.

For example, to use `ASCII` encoding rather than the default `ISO-8859-1` you could do:

```powershell
Start-PodeServer {
    auth use login -t basic -v {
        # check
    } -o @{ 'Encoding' = 'ASCII' }
}
```

More options can be seen further below.

## Validating

Once configured you can start using Basic authentication to validate incoming requests. You can either configure the validation to happen on every `route` as global `middleware`, or as custom `route` middleware.

The following will use Basic authentication to validate every request on every `route`:

```powershell
Start-PodeServer {
    middleware (auth check login)
}
```

Whereas the following example will use Basic authentication to only validate requests on specific a `route`:

```powershell
Start-PodeServer {
    Add-PodeRoute -Method Get -Path '/info' -Middleware (auth check login) -ScriptBlock {
        # logic
    }
}
```

## Full Example

The following full example of Basic authentication will setup and configure authentication, validate that a users username/password is valid, and then validate on a specific `route`:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address *:8080 -Protocol Http

    # setup basic authentication to validate a user
    auth use login -t basic -v {
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

## Use Options

| Name | Description | Default |
| ---- | ----------- | ------- |
| Encoding | Defines which encoding to use when decoding the Authorization header | ISO-8859-1 |
| Name | Defines the name part of the header, in front of the encoded sting, such as the `Basic` part of `Basic <username:password>` | Basic |