# Windows AD

Pode's inbuilt Windows AD authentication works cross-platform, using OpenLDAP to work in *nix environments.

This authenticator can only be used with the Basic and Form schemes. Custom is also supported, but a username and password must be supplied.

## Usage

To enable Windows AD authentication you can use the [`Add-PodeAuthWindowsAd`](../../../../Functions/Authentication/Add-PodeAuthWindowsAd) function. The following example will validate a user's credentials, supplied via a web-form, against the default AD the current server is joined to:

```powershell
Start-PodeServer {
    New-PodeAuthScheme -Form | Add-PodeAuthWindowsAd -Name 'Login'
}
```

### User Object

The User object returned, and accessible on Routes, and other functions via `$WebEvent.Auth.User`, will contain the following information:

| Name | Type | Description |
| ---- | ---- | ----------- |
| UserType | string | Value is fixed to Domain |
| AuthenticationType | string | Value is fixed to LDAP |
| DistinguishedName | string | The distinguished name of the user |
| Username | string | The user's username (without domain) |
| Name | string | The user's fullname |
| Email | string | The user's email address |
| FQDN | string | The FQDN of the AD server |
| Domain | string | The domain part of the user's username |
| Groups | string[] | All groups, and nested groups, of which the the user is a member |

Such as:

```powershell
Add-PodeRoute -Method Get -Path '/info' -Authentication 'Login' -ScriptBlock {
    Write-Host $WebEvent.Auth.User.Username
}
```

### Server

If you want to supply a custom DNS domain, then you can supply the `-Fqdn` parameter:

```powershell
Start-PodeServer {
    New-PodeAuthScheme -Form | Add-PodeAuthWindowsAd -Name 'Login' -Fqdn 'test.example.com'
}
```

### Domain

For OpenLDAP Pode will automatically retrieve the NetBIOS to be prepended on the username, ie: `<domain>\<username>`. This is automatically generate by used the first part of the DNS server's FQDN, for example if your server's FQDN was `test.example.com` then Pode would set the NetBIOS as `test`.

You can use a custom domain NetBIOS by suppliying the `-Domain` parameter:

```powershell
Start-PodeServer {
    New-PodeAuthScheme -Form | Add-PodeAuthWindowsAd -Name 'Login' -Fqdn 'test.example.com' -Domain 'testdomain'
}
```

### SearchBase

When authentication users via OpenLDAP, the base distinguished name search from is the server root, ie: `DC=test,DC=example,DC=com`. You can further refine this by suppliying a `-SearchBase` that will be prepended onto the base internally:

For example, the below will search in `OU=CustomUsers,DC=test,DC=example,DC=com`:

```powershell
Start-PodeServer {
    New-PodeAuthScheme -Form | Add-PodeAuthWindowsAd -Name 'Login' -Fqdn 'test.example.com' -SearchBase 'OU=CustomUsers'
}
```

### Groups

You can supply a list of group names to validate that users are a member of them in AD. If you supply multiple group names, the user only needs to be a member of one of the groups. You can supply the list of groups to the function's `-Groups` parameter as an array - the list is not case-sensitive:

```powershell
Start-PodeServer {
    New-PodeAuthScheme -Form | Add-PodeAuthWindowsAd -Name 'Login' -Groups @('admins', 'devops')
}
```

If an user being authenticated is not in one of these groups, then a 401 is returned.

### Users

You can supply a list of authorised usernames to validate a user's access, after credentials are validated, and instead of of checking AD groups. You can supply the list of usernames to the function's `-Users` parameter as an array - the list is not case-sensitive:

```powershell
Start-PodeServer {
    New-PodeAuthScheme -Form | Add-PodeAuthWindowsAd -Name 'Login' -Users @('jsnow', 'rsanchez')
}
```

If an user being authenticated is not one of the allowed users, then a 401 is returned.

### Additional Validation

Similar to the normal [`Add-PodeAuth`](../../../../Functions/Authentication/Add-PodeAuth), [`Add-PodeAuthWindowsAd`](../../../../Functions/Authentication/Add-PodeAuthWindowsAd) can be supplied can an optional ScriptBlock parameter. This ScriptBlock is supplied the found User object as a parameter, structured as details above. You can then use this to further check the user, or load additional user information from another storage.

The ScriptBlock has the same return rules as [`Add-PodeAuth`](../../../../Functions/Authentication/Add-PodeAuth), as can be seen in the [Overview](../../Overview).

For example, to return the user back:

```powershell
New-PodeAuthScheme -Form | Add-PodeAuthWindowsAd -Name 'Login' -ScriptBlock {
    param($user)

    # check or load extra data

    return @{ User = $user }
}
```

Or to fail authentication with an error message:

```powershell
New-PodeAuthScheme -Form | Add-PodeAuthWindowsAd -Name 'Login' -ScriptBlock {
    param($user)
    return @{ Message = 'Authorisation failed' }
}
```
