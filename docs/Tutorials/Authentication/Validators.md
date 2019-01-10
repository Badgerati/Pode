# Inbuilt Validators

To make authentication easier, Pode will start to support inbuilt validators. This will allow you to specify the name of a validator on the `auth use` function, rather than defining a scriptblock.

Using one of the below validators is simple, just pass its name to `auth use`. For example, the below would define a login method using Basic authentication for Windows AD:

```powershell
Server {
    auth use login -t basic -v 'windows-ad'
}
```

## Windows AD

* Name: `windows-ad`
* Support: Windows (PowerShell, and PS Core v6.1+ only)
* *Note: Example of Windows AD on Linux below*

This will validate a user's credentials, supplied via a web-form against the default DNS domain:

```powershell
Server {
    auth use login -t form -v 'windows-ad'
}
```

This will also validate a user's credentials, but with the domain to use specified:

```powershell
Server {
    auth use login -t form -v 'windows-ad' -o @{ 'fqdn' = 'test.example.com' }
}
```

The User object returned, accessible on `routes`, will contain the Username and FQDN.

The inbuilt support is only for Windows, but you can use libraries such as [Novell.Directory.Ldap.NETStandard](https://www.nuget.org/packages/Novell.Directory.Ldap.NETStandard/) with dotnet core on *nix environments:

```powershell
Server {
    auth use login -t form -v {
        param ($username, $password)

        Add-Type -Path '<path-to-dll>'

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