# Cookies

You can create, remove or extend cookies on web requests/responses by using the [`cookie`](../../../Functions/Responses/Cookie) function.

## Usage

When using the `cookie` function, you supply a specific action to undertake as well as the name of the cookie. Some of the actions need a value to set against the cookie, plus additional arguments such as a secret keys and TTLs.

The make-up of the `cookie` function is as follows:

```powershell
cookie <action> <name> [<value>] [-secret <string>] [-duration <int>] [-httpOnly] [-discard] [-secure]

# or shorthand:
cookie <action> <name> [<value>] [-s <string>] [-ttl <int>] [-http] [-d] [-ssl]
```

The following are a summary of the actions you can perform:

| Action | Description | Returns |
| ------ | ----------- | ------- |
| Check | Given a cookie name and a secret, returns whether the cookie is signed | bool |
| Exists | Given a cookie name, returns whether the cookie exists on the request | bool |
| Extend | Extend the duration of a given cookie | hashtable |
| Get | Retrieves a cookie from the request, and if a secret is passed unsigns it | hashtable |
| Remove | Removes a cookie from the response | none |
| Set | Creates/updates a cookie, and adds it to the response | hashtable |

## Actions

### Check

The `check` action can be used to verify that a given cookie is signed, using the passed secret key. If the cookie is signed then `$true` is returned, otherwise `$false` is returned.

```powershell
cookie check 'token' -s 'secret-key'
```

### Exists

The `exists` action can be used to verify that a given cookie is present on the request. If the cookie is present then `$true` is returned, otherwise `$false` is returned.

```powershell
cookie exists 'token'
```

### Extend

The `extend` action allows you to extend the expiry time of a given cookie; the cookie's duration will be set to the current time, plus the number of seconds specified. If the cookie isn't present on the response, this action will also add it to the response. If successful, a hashtable describing the cookie will be returned.

```powershell
cookie extend 'token' -ttl 3600
```

### Get

The `get` action will return a given cookie, optionally attempting to unsign the cookie's value if a secret key is also supplied. If successful, a hashtable describing the cookie will be returned.

```powershell
cookie get 'token' -s 'secret-key'
```

### Remove

The `remove` action will remove a given cookie from the response - setting it to expire immediately, and inform browsers to discard the cookie.

```powershell
cookie remove 'token'
```

### Set

The `set` action will create/update a cookie on the response, setting the value (which can be signed by passing a secret key), a duration, and other details described in the [`cookie`](../../../Functions/Response/Cookie) function page. If successful, a hashtable describing the cookie will be returned.

```powershell
cookie set 'token' 'a1b2c3-d4e5f6' -s 'secret-key' -ttl 3600 -ssl
```