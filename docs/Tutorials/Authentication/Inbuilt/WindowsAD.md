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
| AuthenticationType | string | Value is fixed to LDAP |
| DistinguishedName | string | The distinguished name of the user |
| Username | string | The username of the user |
| Name | string | The user's fullname in AD |
| Email | string | The user's email address in AD |
| FQDN | string | The DNS domain of the AD |
| Domain | string | The domain part of the username |
| Groups | string[] | The groups that the user is a member of in AD, both directly and recursively |

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
