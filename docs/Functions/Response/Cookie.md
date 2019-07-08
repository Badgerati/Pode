# Cookie

## Description

The `cookie` function allows you to add/set, get, remove and extend cookies on requests/responses; you can also specify a secret key which will be used to sign/unsign the cookie for you.

The `cookie` function also has an action to set a global secret key, that can be cached and re-used - with support for caching other named secret keys.

## Examples

### Example 1

The following example will add a cookie to the response for the current date:

```powershell
$c = cookie set 'date' ([datetime]::UtcNow)
```

### Example 2

The following example will add a signed cookie to the response, and then in a route retrieve it:

```powershell
route get '/' {
    cookie set 'username' 'great.scott' -s 'secret-key' | Out-Null
}

route get '/username' {
    $u = (cookie get 'username' -s 'secret-key').Value
    Write-PodeJsonResponse -Value @{ 'username' = $u }
}
```

### Example 3

The following example will set a signed cookie against the response, with a ttl for 7200secs, if it doesn't exist. Then, it will extend the cookie's duration on each request if it exists:

```powershell
middleware {
    if (!(cookie exists 'date')) {
        cookie set 'date' ([datetime]::UtcNow) -ttl 7200 -s 'pi' | Out-Null
    }
    else {
        cookie extend 'date' -ttl 7200 | Out-Null
    }

    return $true
}
```

### Example 4

The following example will check to see if a cookie has been signed, if it isn't then it will be removed:

```powershell
middleware {
    if (!(cookie check 'username' -s 'secret-key')) {
        cookie remove 'username'
    }

    return $true
}
```

### Example 5

The following example will define a global secret key, that can be reused throughout your server. After setting, it sets a new cookie using the global key:

```powershell
# sets a global secret, then sets a new cookie
cookie secrets global 'some-key'
cookie set 'name' 'value' -s (cookie secrets global)

# the `-gs` switch will internally retrieve the global secret
cookie set 'name' 'value' -gs


# sets a differently name secret, then uses it
cookie secrets 'my-secret' 'some-key'
cookie set 'name' 'value' -s (cookie secrets 'my-secret')
```

## Parameters

| Name | Type | Required | Description | Default |
| ---- | ---- | -------- | ----------- | ------- |
| Action | string | true | The action to perform on the cookie (Values: Check, Exists, Extend, Get, Remove, Secrets, Set) | empty |
| Name | string | true | The name of the cookie | empty |
| Value | string | false | The value to assign to the cookie | empty |
| Secret | string | false | A secret key to be used to sign the cookie's value | empty |
| Duration | int | false | The duration of the cookie in seconds from UtcNow | 0 |
| Discard | switch | false | If true, informs the browser to discard the cookie on expiry | false |
| Secure | switch | false | If true, informs the browser to only send the cookie on secure connections | false |
| HttpOnly | switch | false | If true, the cookie can only be accessed from browsers | false |
| GlobalSecret | switch | false | If true, will use the global cached secret key (overriding a passed secret) | false |

## Returns

* The `check` and `exists` actions each return a `boolean` value.

* The `secrets` action, with no value passed, returns a `string` value.

* The `extend`, `get` and `set` actions each return a `hashtable` that describes the current state of the cookie, this has the following properties:

| Name | Type |
| ---- | ---- |
| Name | string |
| Value | string |
| Expires | datetime |
| Expired | bool |
| Discard | bool |
| HttpOnly | bool |
| Secure | bool |
| TimeStamp | datetime |
| Signed | bool |