# IIS

Pode's all PowerShell Web Server now enables you to host your server via IIS!

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
        <add name="aspNetCore" path="*" verb="*" modules="AspNetCoreModuleV2" resourceType="Unspecified" />
      </handlers>
      <aspNetCore processPath="pwsh.exe" arguments=".\server.ps1" stdoutLogEnabled="true" stdoutLogFile=".\logs\stdout" hostingModel="OutOfProcess"/>
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

* The server type is set to `Pode` (The same as doing `Start-PodeServer -Type Pode`)
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

    Add-PodeAuthIIS -Name 'IISAuth'

    Add-PodeRoute -Method Get -Path '/test' -Middleware (Get-PodeAuthMiddleware -Name 'IISAuth' -Sessionless) -ScriptBlock {
        param($e)
        Write-PodeJsonResponse -Value @{ User = $e.Auth.User }
    }
}
```

If the required header is missing, then Pode responds with a 401. The retrieved user, like other authentication, is set in the web event's `Auth.User` and contains the same information as Pode's inbuilt Windows AD authenticator:

| Name | Type | Description |
| ---- | ---- | ----------- |
| UserType | string | Specifies if the user is a Domain or Local user |
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

## Azure Web App

To host your Pode server under IIS using Azure Web Apps, ensure the OS type is Windows and the framework is .NET Core 2.1/3.0.

Your web.config's `processPath` will also need to reference `powershell.exe` not `pwsh.exe`.

Pode can auto-detect if you're using an Azure Web App, but if you're having issues trying setting the `-DisableTermination` and `-Quiet` switches on your [`Start-PodeServer`](../../Functions/Core/Start-PodeServer).

## Useful Links

* [Host ASP.NET Core on Windows with IIS \| Microsoft Docs](https://docs.microsoft.com/en-us/aspnet/core/host-and-deploy/iis/?view=aspnetcore-3.1)
