# Windows AD

Pode's inbuilt Windows AD authentication works cross-platform, using OpenLDAP to work in *nix environments.

This authenticator can only be used with the Basic and Form schemes. Custom is also supported, but a username and password must be supplied.

## Usage

To enable Windows AD authentication you can use the [`Add-PodeAuthWindowsAd`](../../../../Functions/Authentication/Add-PodeAuthWindowsAd) function. The following example will validate a user's credentials, supplied via a web-form, against the default AD the current server is joined to:

```powershell
Start-PodeServer {
    Enable-PodeSessionMiddleware -Duration 120 -Extend
    New-PodeAuthScheme -Form | Add-PodeAuthWindowsAd -Name 'Login'
}
```

## User Object

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

## Providers

The default Provider which Pode uses for Windows AD is Directory Services on Windows, or OpenLDAP on *nix environments. However, you can force OpenLDAP or Windows, or you can specify to use the ActiveDirectory module on Windows using the `-OpenLDAP` or `-ADModule` switches:

```powershell
# force OpenLDAP
New-PodeAuthScheme -Form | Add-PodeAuthWindowsAd -Name 'Login' -OpenLDAP

# force ActiveDirectory
New-PodeAuthScheme -Form | Add-PodeAuthWindowsAd -Name 'Login' -ADModule
```

When you use `-ADModule` switch, Pode will automatically import the module for you.

## Groups

By default Pode will retrieve all groups that a user is a member of, recursively. This can at times cause performance issues if you have a lot of groups in your domain.

If you need groups, but you only need the direct groups a user is a member of then you can specify `-DirectGroups`. Or, if you don't need the groups at all, you can specify `-NoGroups`:

```powershell
# direct groups only
New-PodeAuthScheme -Form | Add-PodeAuthWindowsAd -Name 'Login' -DirectGroups

# no groups
New-PodeAuthScheme -Form | Add-PodeAuthWindowsAd -Name 'Login' -NoGroups
```

## Server

If you want to supply a custom DNS domain, then you can supply the `-Fqdn` parameter:

```powershell
New-PodeAuthScheme -Form | Add-PodeAuthWindowsAd -Name 'Login' -Fqdn 'test.example.com'
```

## Domain

For OpenLDAP Pode will automatically retrieve the NetBIOS to be prepended on the username, ie: `<domain>\<username>`. This is automatically generate by used the first part of the DNS server's FQDN, for example if your server's FQDN was `test.example.com` then Pode would set the NetBIOS as `test`.

You can use a custom domain NetBIOS by suppliying the `-Domain` parameter:

```powershell
New-PodeAuthScheme -Form | Add-PodeAuthWindowsAd -Name 'Login' -Fqdn 'test.example.com' -Domain 'testdomain'
```

## SearchBase

When authenticating users via OpenLDAP, the default base distinguished name searched from will be the server root, ie: `DC=test,DC=example,DC=com`. You can refine this by supplying an optional `-SearchBase`, that should be the full distinguished name:

For example, the below will search in `OU=CustomUsers,DC=test,DC=example,DC=com`:

```powershell
New-PodeAuthScheme -Form | Add-PodeAuthWindowsAd -Name 'Login' -SearchBase 'OU=CustomUsers,DC=test,DC=example,DC=com'
```

## Allow

You can supply an optional array of either User/Group names, or both; and if the user being authenticated is in the list (or on of their groups are) they will be allowed.

### Groups

You can supply a list of group names to validate that users are a member of them in AD. If you supply multiple group names, the user only needs to be a member of one of the groups. You can supply the list of groups to the function's `-Groups` parameter as an array - the list is not case-sensitive:

```powershell
New-PodeAuthScheme -Form | Add-PodeAuthWindowsAd -Name 'Login' -Groups @('admins', 'devops')
```

If an user being authenticated is not in one of these groups, then a 401 is returned.

### Users

You can supply a list of authorised usernames to validate a user's access, after credentials are validated, and instead of of checking AD groups. You can supply the list of usernames to the function's `-Users` parameter as an array - the list is not case-sensitive:

```powershell
New-PodeAuthScheme -Form | Add-PodeAuthWindowsAd -Name 'Login' -Users @('jsnow', 'rsanchez')
```

If an user being authenticated is not one of the allowed users, then a 401 is returned.

## Additional Validation

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
