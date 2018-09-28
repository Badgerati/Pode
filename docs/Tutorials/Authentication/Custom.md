# Custom Authentication

Custom authentication works much like the inbuilt types, but allows you to specify your own parsing logic, as well as any custom options that might be required.

## Setup and Parsing

To setup and start using Custom authentication in Pode you can set `auth use -c <name>` in you server script. The `<name>` can be anything you want, even the name of an inbuilt method (it will still use your custom logic!).

Let's say we wanted something similar to [`Form`](../Form) authentication but it requires a third piece of information: `ClientName`. To setup Custom authentication for this method, you'll need to specify the parsing scriptblock under `-p`, as well as the validator script too.

The parsing script will be passed the current request session (containing the Request/Response objects, much like a `route`). In this script you can parse the request payload/headers for any credential information that needs validating. Once sourced, the data returned from the script should be either a `hashtable` or an `array`; this data will then `splatted` onto the validator scriptblock ([info](../../../Functions/Helpers/Invoke-ScriptBlock)):

```powershell
Server {
    # here we're calling the custom method "client"
    auth use -c client -p {
        # the current request session, and auth method options supplied
        param($session, $opts)

        # get client/user/pass field names to get from payload
        $clientField = (coalesce $opts.ClientField 'client')
        $userField = (coalesce $opts.UsernameField 'username')
        $passField = (coalesce $opts.PasswordField 'password')

        # get the client/user/pass from the post data
        $client = $session.Data.$clientField
        $username = $session.Data.$userField
        $password = $session.Data.$passField

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
Server {
    middleware (auth check client)
}
```

Whereas the following example will use Custom authentication to only validate requests on specific a `route`:

```powershell
Server {
    route get '/info' (auth check client) {
        # logic
    }
}
```

## Full Example

The following full example of Custom authentication will setup and configure authentication, validate that a users client/username/password is valid, and then validate on a specific `route`:

```powershell
Server {
    listen *:8080 http

    # here we're calling the custom method "client"
    auth use -c client -p {
        # the current request session, and auth method options supplied
        param($session, $opts)

        # get client/user/pass field names to get from payload
        $clientField = (coalesce $opts.ClientField 'client')
        $userField = (coalesce $opts.UsernameField 'username')
        $passField = (coalesce $opts.PasswordField 'password')

        # get the client/user/pass from the post data
        $client = $session.Data.$clientField
        $username = $session.Data.$userField
        $password = $session.Data.$passField

        # return the data, to be passed to the validator script
        return @($client, $username, $password)
    } `
    -v {
        param($client, $username, $password)

        # check if the client is valid

        return  @{ 'user' = $user }
    }

    # check the request on this route against the authentication
    route get '/cpu' (auth check client) {
        json @{ 'cpu' = 82 }
    }

    # this route will not be validated against the authentication
    route get '/memory' {
        json @{ 'memory' = 14 }
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