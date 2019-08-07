# Windows AD

!!! important
    The Windows AD authentication method is only supported on Windows (PowerShell, and PS Core v6.1+ only).

## Usage

To use Windows AD authentication you use the [`Add-PodeAuthWindowsAd`](../../../../../Functions/Authentication/Add-PodeAuthWindowsAd) function. The following example will validate a user's credentials, supplied via a web-form against the default DNS domain defined in `$env:USERDNSDOMAIN`:

```powershell
Start-PodeServer {
    New-PodeAuthType -Form | Add-PodeAuthWindowsAd -Name 'Login'
}
```

### User Object

The User object returned, and accessible on Routes, and other functions via `$e.Auth.User`, will contain the following information:

| Name | Type | Description |
| ---- | ---- | ----------- |
| Username | string | The username of the user |
| Name | string | The user's fullname in AD |
| FQDN | string | The DNS domain of the AD |
| Groups | string[] | The groups that the user is a member of in AD, both directly and recursively |

Such as:

```powershell
Add-PodeRoute -Method Get -Path '/info' -Middleware (Get-PodeAuthMiddleware -Name 'Login') -ScriptBlock {
    param($e)
    Write-Host $e.Auth.User.Username
}
```

### Custom Domain

If you want to supply a custom DNS domain, then you can supply the `-FQDN` parameter:

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

## Linux

The inbuilt authentication only supports Windows, but you can use libraries such as [Novell.Directory.Ldap.NETStandard](https://www.nuget.org/packages/Novell.Directory.Ldap.NETStandard/) with dotnet core on *nix environments:

```powershell
Start-PodeServer {
    New-PodeAuthType -Form | Add-PodeAuth -Name 'Login' -ScriptBlock {
        param ($username, $password)

        Add-Type -Path '<path-to-novell-dll>'

        try {
            $ldap = New-Object Novell.Directory.Ldap.LdapConnection
            $ldap.Connect('ad-server-name', 389)
            $ldap.Bind("<domain>\$username", $password)
        }
        catch {
            return $null
        }
        finally {
            $ldap.Dispose()
        }

        return @{
            User = @{
                Username = "<domain>\$username"
            }
        }
    }
}
```
