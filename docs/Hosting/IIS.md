# IIS

Pode has support for you to host your server via IIS!

When you host your server through IIS, Pode can detect this and internally set the server type and endpoints to automatically work with IIS. This allows IIS to deal with binding, HTTPS and Certificates, as well as external traffic, etc.

!!! important
    This being IIS, it is for Windows only!

## Requirements

To start with you'll need to have IIS (or IIS Express) installed:

```powershell
Install-WindowsFeature -Name Web-Server -IncludeManagementTools -IncludeAllSubFeature
```

Next you'll need to install ASP.NET Core Hosting:

```powershell
choco install dotnetcore-windowshosting -y
```

You'll also need to use PowerShell Core (*not Windows PowerShell!*):

```powershell
choco install pwsh -y
```

Finally, you'll need to have Pode installed under PowerShell Core:

```powershell
pwsh -c "Install-Module Pode -Scope AllUsers"
```

!!! note
    Sometimes you may need to run `iisreset`, otherwise IIS will return 502 errors.

## Server

The first thing you'll need to do so IIS can host your server is, in the same directory as your Pode server's `.ps1` root script, create a `web.config` file. This file should look as follows, but make sure you replace the `.\server.ps1` with the path to your actual server script:

```xml
<configuration>
  <location path="." inheritInChildApplications="false">
    <system.webServer>
      <handlers>
        <remove name="WebDAV" />
        <add name="aspNetCore" path="*" verb="*" modules="AspNetCoreModuleV2" resourceType="Unspecified" />
        <remove name="ExtensionlessUrlHandler-Integrated-4.0" />
        <add name="ExtensionlessUrlHandler-Integrated-4.0" path="*." verb="*" type="System.Web.Handlers.TransferRequestHandler" preCondition="integratedMode,runtimeVersionv4.0" />
        <remove name="ExtensionlessUrl-Integrated-4.0" />
        <add name="ExtensionlessUrl-Integrated-4.0" path="*." verb="*" type="System.Web.Handlers.TransferRequestHandler" preCondition="integratedMode,runtimeVersionv4.0" />
      </handlers>

      <modules>
        <remove name="WebDAVModule" />
      </modules>

      <aspNetCore processPath="pwsh.exe" arguments=".\server.ps1" stdoutLogEnabled="true" stdoutLogFile=".\logs\stdout" hostingModel="OutOfProcess"/>

      <security>
        <authorization>
          <remove users="*" roles="" verbs="" />
          <add accessType="Allow" users="*" verbs="GET,HEAD,POST,PUT,DELETE,DEBUG,OPTIONS" />
        </authorization>
      </security>
    </system.webServer>
  </location>
</configuration>
```

Once done, you can setup IIS in the normal way:

* Create an Application Pool
* Create a website, and set the physical path to the root directory of your Pode server
* Setup a binding (something like HTTP on *:8080 - IP Address can be anything)
* Then, navigate to the IIS binding endpoint

Pode automatically detects that it is running via IIS, and it changes certain attributes of your Pode server so they work with IIS:

* Endpoints have their Address set to `127.0.0.1` (IIS needs Pode to be on localhost)
* Endpoints have their Port set to `ASPNETCORE_PORT`
* Endpoints have their Protocol set to `HTTP` (IIS deals with HTTPS for us)

This allows you to write a Pode server that works locally, but will also automatically work under IIS without having to change anything!

!!! note
    This does mean that Pode will force all endpoints to `127.0.0.1:PORT`. So if you had two different IPs before, they'll be merged into one.

## HTTPS

Although Pode does have support for HTTPS, when running via IIS it takes control of HTTPS for us - this is why the endpoints are forced to HTTP.

You can setup a binding in IIS for HTTPS with a Certificate, and IIS will deal with SSL for you.

## IIS Authentication

If you decide to use IIS for Windows Authentication, then you can retrieve the authenticated user in Pode. This is done using the [`Add-PodeAuthIIS`](../../Functions/Authentication/Add-PodeAuthIIS) function, and it will check for the `MS-ASPNETCORE-WINAUTHTOKEN` header from IIS. The function creates a custom Authentication Type and Method, and can be used on Routes like other Authentications in Pode:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address 127.0.0.1 -Protocol Http

    Add-PodeAuthIIS -Name 'IISAuth' -Sessionless

    Add-PodeRoute -Method Get -Path '/test' -Authentication 'IISAuth' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ User = $WebEvent.Auth.User }
    }
}
```

If the required header is missing, then Pode responds with a 401. The retrieved user, like other authentication, is set on the [web event](../../../WebEvent)'s `$WebEvent.Auth.User` property, and contains the same information as Pode's inbuilt Windows AD authenticator:

| Name | Type | Description |
| ---- | ---- | ----------- |
| UserType | string | Specifies if the user is a Domain or Local user |
| Identity | System.Security.Principal.WindowsIdentity | Returns the WindowsIdentity which can be used for Impersonation |
| AuthenticationType | string | Value is fixed to LDAP |
| DistinguishedName | string | The distinguished name of the user |
| Username | string | The user's username (without domain) |
| Name | string | The user's fullname |
| Email | string | The user's email address |
| FQDN | string | The FQDN of the AD server |
| Domain | string | The domain part of the user's username |
| Groups | string[] | All groups of which the the user is a member |

!!! note
    If the authenticated user is a Local User, then the following properties will be empty: FQDN, Email, and DistinguishedName

### Kerberos Constrained Delegation

Pode can impersonate the user that requests the webpage using Kerberos Constrained Delegation (KCD).
This can be done using the following example:

```powershell
[System.Security.Principal.WindowsIdentity]::RunImpersonated($WebEvent.Auth.User.Identity.AccessToken,{
    $newIdentity = [Security.Principal.WindowsIdentity]::GetCurrent() | Select-Object -ExpandProperty 'Name'    
    Write-PodeTextResponse -Value "You are running this command as the server user $newIdentity"
})
```

!!! note The use of KCD requires additional configuration the Active Directory 

### Additional Validation

Similar to the normal [`Add-PodeAuth`](../../Functions/Authentication/Add-PodeAuth), [`Add-PodeAuthIIS`](../../Functions/Authentication/Add-PodeAuthIIS) can be supplied can an optional ScriptBlock parameter. This ScriptBlock is supplied the found User object as a parameter, structured as details above. You can then use this to further check the user, or load additional user information from another storage.

The ScriptBlock has the same return rules as [`Add-PodeAuth`](../../Functions/Authentication/Add-PodeAuth), as can be seen in the [Overview](../../Tutorials/Authentication/Overview).

For example, to return the user back:

```powershell
Add-PodeAuthIIS -Name 'IISAuth' -Sessionless -ScriptBlock {
    param($user)

    # check or load extra data

    return @{ User = $user }
}
```

Or to fail authentication with an error message:

```powershell
Add-PodeAuthIIS -Name 'IISAuth' -Sessionless -ScriptBlock {
    param($user)
    return @{ Message = 'Authorisation failed' }
}
```

## Azure Web Apps

To host your Pode server under IIS using Azure Web Apps, ensure the OS type is Windows and the framework is .NET Core 2.1/3.0.

Your web.config's `processPath` will also need to reference `powershell.exe` not `pwsh.exe`.

Pode can auto-detect if you're using an Azure Web App, but if you're having issues trying setting the `-DisableTermination` and `-Quiet` switches on your [`Start-PodeServer`](../../Functions/Core/Start-PodeServer).

## Useful Links

* [Host ASP.NET Core on Windows with IIS \| Microsoft Docs](https://docs.microsoft.com/en-us/aspnet/core/host-and-deploy/iis/?view=aspnetcore-3.1)
