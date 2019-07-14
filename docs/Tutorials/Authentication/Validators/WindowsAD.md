# Windows AD

!!! important
    The Windows AD validator is only supported on Windows (PowerShell, and PS Core v6.1+ only).

## Usage

To use the Windows AD validator you supply the name `windows-ad` to the `auth` function's `-v` parameter. The following example will validate a user's credentials, supplied via a web-form against the default DNS domain defined in `$env:USERDNSDOMAIN`:

```powershell
Start-PodeServer {
    auth use login -t form -v 'windows-ad'
}
```

### User Object

The User object returned, and accessible on `routes` and other functions via `$e.Auth.User`, will contain the following information:

| Name | Type | Description |
| ---- | ---- | ----------- |
| Username | string | The username of the user |
| Name | string | The user's fullname in AD |
| FQDN | string | The DNS domain of the AD |
| Groups | string[] | The groups that the user is a member of in AD, both directly and recursively |

Such as:

```powershell
Add-PodeRoute -Method Get -Path '/info' -Middleware (auth check login) -ScriptBlock {
    param($e)
    Write-Host $e.Auth.User.Username
}
```

### Custom Domain

If you want to supply a custom DNS domain, then you can supply an `FQDN` in the options parameter of the `auth` function:

```powershell
Start-PodeServer {
    auth use login -t form -v 'windows-ad' -o @{
        'fqdn' = 'test.example.com'
    }
}
```

### Groups

You can supply a list of group names to validate that user's are a member of them in AD. If you supply multiple group names, the user only needs to be a of one of the groups. You can supply the list of groups to the `auth` function's options parameter as an array - the list is not case-sensitive:

```powershell
Start-PodeServer {
    auth use login -t form -v 'windows-ad' -o @{
        'groups' = @('admins', 'devops')
    }
}
```

### Users

You can supply a list of authorised usernames to validate a user's access, after credentials are validated, and instead of of checking AD groups. You can supply the list of usernames to the `auth` function's options parameter as an array - the list is not case-sensitive:

```powershell
Start-PodeServer {
    auth use login -t form -v 'windows-ad' -o @{
        'users' = @('jsnow', 'rsanchez')
    }
}
```

## Linux

The inbuilt validator only supports Windows, but you can use libraries such as [Novell.Directory.Ldap.NETStandard](https://www.nuget.org/packages/Novell.Directory.Ldap.NETStandard/) with dotnet core on *nix environments:

```powershell
Start-PodeServer {
    auth use login -t form -v {
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
            'user' = @{ 'username' = "<domain>\$username" }
        }
    }
}
```