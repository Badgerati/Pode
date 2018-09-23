# Auth

## Description

The `auth` function allows you to setup/use and validate/check against defined authentication methods on web requests; this could be Basic or Form authentication, to custom defined authentication. Authentication can either be sessionless (requiring validation on every request), or session-persistent (only requiring validation once, and then checks against a session signed-cookie).

## Actions

### Use

The `auth use` action allows you to specify and configure which authentication methods your server will use; you can have many of them, defining which one to validate against on the `auth check` action.

The name of the method specified should be a valid inbuilt method, unless you have stated that the method is custom. If custom, you *must* supply a parser script which will parse payloads/headers for credentials and then return this data as an array - which will then be supplied to the validator script.

### Check

The `auth check` action allows you to define which authentication method to validate a request against. The action returns a valid middleware script, meaning you can either use this action on specific `route` definitions, or globally for all routes as `middleware`. If this action fails, then a 401 response is returned.

On success, this action will then allow the `route` logic to be invoked. If `session` `middleware` has been configured then an authenticated session is also created for future requests.

When the user makes another call using the same authenticated session, then the `auth check` action will detect the already authenticated session and skip the validator script. If you're using sessions and you don't want the `auth check` to check the session, or store the user against the session, then pass `-o @{ 'Session' = $false }` to the `auth check`.

The following table contains options that you can supply to an `auth check -o @{}` call - these are all optional:

| Name | Description | Default |
| ---- | ----------- | ------- |
| FailureUrl | The URL to redirect to should authentication fail | empty |
| SuccessUrl | The URL to redirect to should authenticationh succeed | empty |
| Session | If true, check if the session already has an authenticated user; storing the user in the session if they are authenticated | true |
| Login | If true, check the authentication status in the session and redirect to the SuccessUrl if the user is authenticated. Otherwise proceed to the page with no authentication required | false |
| Logout | If true, purge the session and redirect to the FailureUrl | false |

!!! info
    The `Login` option allows you to have authentication on your login pages, such that if there is no user in a current session then the login page displays - rather then being 401'd. Whereas if there is an authenticated user in the session it will auto-redirect to the `SuccessUrl`.

## Examples

### Example 1

The following example will setup sessionless `Basic` authentication, and then use it as `route` middleware. This will require authentication on every request. The basic authentication will check for an `{ "Authorization": "Basic user:pass" }` header on the request:

```powershell
Server {
    listen *:8080 http

    # setup basic auth, with validator to check the user
    auth use basic -v {
        param($username, $pass)
        # check if the user is valid
        return @{ 'user' = $user }
    }

    # check the request against the above auth
    route get '/info' (auth check basic) {
        json @{ 'cpu' = 82 }
    }
}
```

### Example 2

The following example will setup sessionless `Form` authentication, and set it as global middleware for every `route`. This will require authentication on every request. The form authentication will check the POST payload for a `username` and `password`, supplied from a `<form>`:

```powershell
Server {
    listen *:8080 http

    # setup form auth, with validator to check the user
    auth use form -v {
        param($username, $pass)
        # check if the user is valid
        return @{ 'user' = $user }
    }

    # apply the auth check as global middleware
    middleware (auth check form)

    # the route will use the above auth middleware
    route get '/info' {
        json @{ 'cpu' = 82 }
    }
}
```

### Example 3

The following example will setup session-persistent `Basic` authentication, and then use it as `route` middleware. This will only require authentication once, and the the check will succeed if the authenticated session cookie is passed:

```powershell
Server {
    listen *:8080 http

    # configure session middleware to bind the auth'd user against
    middleware (session @{
        'Secret' = 'schwifty';
        'Duration' = 300;
    })

    # setup basic auth, with validator to check the user
    auth use basic -v {
        param($username, $pass)
        # check if the user is valid
        return @{ 'user' = $user }
    }

    # check the request against the above auth
    route get '/info' (auth check basic) {
        json @{ 'cpu' = 82 }
    }
}
```

## Parameters

| Name | Type | Required | Description | Default |
| ---- | ---- | -------- | ----------- | ------- |
| Action | string | true | The action to perform on the `auth` function (Values: Use, Check) | empty |
| Name | string | true | The name of the authentication middleware; if `-Custom` is not specified, then this will be the name of an inbuilt authentication method | empty |
| Validator | scriptblock | false | A script that will be passed user credentials, here you can validate the user is valid and exists in some data store | null |
| Parser | scriptblock | false | If `-Custom` is supplied then this parameter is required. This is the custom script where you can parse payloads/querystring or headers to source user credentials, that will then be supplied to your validator | null |
| Options | hashtable | false | A hashtable of options to customise the authentication method. Depending on the method is this be options like FieldName or Encoding | null |
| Custom | switch | false | If passed, states that this authentication method is a custom defined method | false |
