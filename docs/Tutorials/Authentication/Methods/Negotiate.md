# Negotiate

Negotiate authentication lets you use Kerberos or NTLM authentication with an Active Directory (AD) server. This enables the use of, for example, `-UseDefaultCredentials` on `Invoke-WebRequest` and `Invoke-RestMethod`. The Negotiate authentication in Pode is built using the [Kerberos.NET](https://github.com/dotnet/Kerberos.NET) library.

!!! important
    To use the Negotiate authentication you will require a valid keytab file, which can be generated using the [ktpass](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/ktpass) command-line tool.

## KeyTab

To generate the required keytab file, ensure that the `ktpass` command-line tool is available. Additionally, you must have a user account in the Active Directory (AD) your are configuring for Negotiate authentication

Once available, you can either generate a keytab using `ktpass` directly, such as:

```powershell
# generates a pode.keytab file in the current directory
ktpass /princ HTTP/pode.example.com@example.com /mapuser example\pode-user /pass * /out pode.keytab /crypto all /ptype KRB5_NT_PRINCIPAL /mapop set
```

Or, you can use the simple helper [`New-PodeAuthKeyTab`](../../../../Functions/Authentication/New-PodeAuthKeyTab) function in Pode - this does still call `ktpass` under the hood:

```powershell
# generates a pode.keytab file in the current directory
New-PodeAuthKeyTab -Hostname 'pode.example.com' -DomainName 'example.com' -Username 'example\pode_user'
```

In both, the `/princ` or `-Hostname` should be the hostname that your Pode server endpoint is running as:

```powershell
Add-PodeEndpoint -Address localhost -Port 8080 -Host 'pode.example.com' -Protocol Http
```

!!! note
    In the above examples, `ktpass` will prompt for the user's password.

### SPN

In most cases, `ktpass` will setup the relevant SPN for you. However, if you need to set this up, then an example of doing so is a follows using [setspn](https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2012-r2-and-2012/cc731241(v=ws.11)):

```powershell
setspn -A HTTP/pode.example.com example\pode-user
```

## Setup

To use Negotiate authentication in Pode, after you've created a keytab file, you can use [`New-PodeAuthScheme`](../../../../Functions/Authentication/New-PodeAuthScheme) and the pipe the result into [`Add-PodeAuth`](../../../../Functions/Authentication/Add-PodeAuth). The scriptblock for `Add-PodeAuth` will be supplied the [ClaimsPrincipal](https://learn.microsoft.com/en-us/dotnet/api/system.security.claims.claimsprincipal?view=net-9.0) object for the authenticated AD user:

```powershell
$keytab = '.\pode.keytab'
New-PodeAuthScheme -Negotiate -KeytabPath $keytab | Add-PodeAuth -Name 'Login' -Sessionless -ScriptBlock {
    param($claim)

    # perform any optional additional validation on the claim
    # the user's name will be under $claim.Identity.Name

    return @{ User = $claim }
}
```

## Middleware

Once configured you can start using Negotiate authentication to validate incoming requests. You can either configure the validation to happen on every Route as global Middleware, or as custom Route Middleware.

The following will use Negotiate authentication to validate every request on every Route:

```powershell
Start-PodeServer {
    Add-PodeAuthMiddleware -Name 'GlobalAuthValidation' -Authentication 'Login'
}
```

Whereas the following example will use Negotiate authentication to only validate requests on specific a Route:

```powershell
Start-PodeServer {
    Add-PodeRoute -Method Get -Path '/info' -Authentication 'Login' -ScriptBlock {
        # logic
    }
}
```

## Full Example

The following full example of Negotiate authentication will setup and configure authentication, and then validate on a specific Route:

```powershell
Start-PodeServer -Threads 2 {
    Add-PodeEndpoint -Address localhost -Port 8080 -Host 'pode.example.com' -Protocol Http

    # setup negotiate authentication
    $keytab = '.\pode.keytab'
    New-PodeAuthScheme -Negotiate -KeytabPath $keytab | Add-PodeAuth -Name 'Login' -Sessionless -ScriptBlock {
        param($claim)
        return @{ User = $claim }
    }

    # check the request on this route against the authentication
    Add-PodeRoute -Method Get -Path '/cpu' -Authentication 'Login' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ 'cpu' = 82 }
    }

    # this route will not be validated against the authentication
    Add-PodeRoute -Method Get -Path '/memory' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ 'memory' = 14 }
    }
}
```
