# Windows AD

Pode's inbuilt Windows AD authentication works cross-platform, using OpenLDAP to work in *nix environments.

## Usage

To enable Windows AD authentication you can use the [`Add-PodeAuthWindowsAd`](../../../../Functions/Authentication/Add-PodeAuthWindowsAd) function. The following example will validate a user's credentials, supplied via a web-form, against the default AD the current server is joined to:

```powershell
Start-PodeServer {
    New-PodeAuthType -Form | Add-PodeAuthWindowsAd -Name 'Login'
}
```

### User Object

The User object returned, and accessible on Routes, and other functions via `$e.Auth.User`, will contain the following information:

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
Add-PodeRoute -Method Get -Path '/info' -Middleware (Get-PodeAuthMiddleware -Name 'Login') -ScriptBlock {
    param($e)
    Write-Host $e.Auth.User.Username
}
```

### Server

If you want to supply a custom DNS domain, then you can supply the `-Fqdn` parameter:

```powershell
Start-PodeServer {
    New-PodeAuthType -Form | Add-PodeAuthWindowsAd -Name 'Login' -Fqdn 'test.example.com'
}
```

### Groups

You can supply a list of group names to validate that user's are a member of them in AD. If you supply multiple group names, the user only needs to be a of one of the groups. You can supply the list of groups to the `auth` function's options parameter as an array - the list is not case-sensitive:

```powershell
Start-PodeServer {
    New-PodeAuthType -Form | Add-PodeAuthWindowsAd -Name 'Login' -Groups @('admins', 'devops')
}
```

### Users

You can supply a list of authorised usernames to validate a user's access, after credentials are validated, and instead of of checking AD groups. You can supply the list of usernames to the `auth` function's options parameter as an array - the list is not case-sensitive:

```powershell
Start-PodeServer {
    New-PodeAuthType -Form | Add-PodeAuthWindowsAd -Name 'Login' -Users @('jsnow', 'rsanchez')
}
```
