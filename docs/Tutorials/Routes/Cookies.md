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
lorem

### Exists
lorem

### Extend
lorem

### Get
lorem

### Remove
lorem

### Set
lorem