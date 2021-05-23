# IIS

Pode has support for you to host your server via IIS!

When you host your server through IIS, Pode will detect this and internally set the server type and endpoints to automatically work with IIS. This allows IIS to deal with binding, HTTPS and Certificates, as well as external traffic, etc.

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
    Sometimes you may need to run `iisreset` after installing all of the above, otherwise IIS will return 502 errors.

## Configuration

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

## IIS Setup

With the `web.config` file in place, it's then time to setup the site in IIS. The first thing to do is open up the IIS Manager, then once open, follow the below steps to setup your site:

1. In the left pane, expand the Server and then the Sites folders
2. Right click the "Application Pools" folder
    1. Enter a name for your Application Pool, just the name of your site will do, such as "pode.example.com"
    2. Select OK to create the Application Pool
3. Right click the Sites folder, and select "Add Website..."
    1. Enter the name of your website, such as "pode.example.com"
    2. Select the Application Pool that we created above
    3. Set the Physical Path to the root directory of your Pode server's script (just the directory, not the ps1 itself)
    4. Select either HTTP or HTTPS for your binding
    5. Leave IP Address as "All Unassigned", and either leave the Port as 80/443 or change to what you need
    6. Optionally enter the host name of your site, such as "pode.example.com" (usually required for HTTPS)
    7. If HTTPS, select "Require SNI"
    8. If HTTPS, select the required certificate from the dropdown
    9. Select OK to create the Site

At this point, your site is now created in IIS, and you should be able to navigate to the hostname/IP and port combination you setup above for the IIS site. Pode automatically detects that it is running via IIS, and it changes certain attributes of your Pode server so they work with IIS:

* Endpoints have their Address set to `127.0.0.1` (IIS needs Pode to be on localhost)
* Endpoints have their Port set to `ASPNETCORE_PORT`
* Endpoints have their Protocol set to `HTTP` (IIS deals with HTTPS for us)

This allows you to write a Pode server that works locally, but will also automatically work under IIS without having to change anything!

!!! note
    This does mean that Pode will force all endpoints to `127.0.0.1:PORT`. So if you had two different IPs before, they'll be merged into one. Something to be aware of if you assign routes to specific endpoints, as under IIS this won't work.

### Advanced/Domain

The above IIS site setup works, but only for simple sites. If you require the use of the Active Directory module, or your site to be running as a different user then follow the steps below.

#### Active Directory

By default a newly created site will be running as ApplicationPoolIdentity. In order to use the Active Directory module, your IIS site will need to be running as a domain user:

1. Open IIS, and select the Application Pools folder
2. Right click your Application Pool, and select "Advanced Settings..."
3. Under "Process Module", click the "..." of the "Identity" setting
4. Select "Custom account", and change the account to the credentials of a valid domain user
5. Select OK

If you've enabled Basic Authentication in IIS for you site, you'll also need to edit the domain there as well:

1. Open IIS, and expand the Sites folder
2. Select your Site
3. In the middle pane, under IIS, select "Authentication"
4. Right click "Basic Authentication" (if it's enabled)
5. Edit the domain to your domain
6. Select OK

Sometimes you might run into issues using the Active Directory module under IIS - such as the following error:

```plain
Creating a new session for implicit remoting of "Get-ADUser" command...
```

If this happens, you'll need to make your AD calls using `Invoke-Command`:

```powershell
Invoke-Command -ArgumentList $username -ScriptBlock {
    param($username)
    Import-Module -Name ActiveDirectory
    Get-ADUser -Identity $username
}
```

#### Change User

To change the user your site is running as:

1. Open IIS, and select the Application Pools folder
2. Right click your Application Pool, and select "Advanced Settings..."
3. Under "Process Module", click the "..." of the "Identity" setting
4. Change the user to either an inbuilt one, or a custom local/domain user
5. Select OK

## HTTPS

Although Pode does have support for HTTPS, when running via IIS it takes control of HTTPS for us - this is why the endpoints are forced to HTTP.

You can setup a binding in IIS for HTTPS with a Certificate, and IIS will deal with SSL for you:

1. Open IIS, and expand the Sites folder
2. Right click your Site, and select "Edit Bindings..."
3. Select "Add..."
4. Select HTTPS for your binding
5. Leave IP Address as "All Unassigned", and either leave the Port as 443 or change to what you need
6. Enter the host name of your site, such as "pode.example.com"
7. Select "Require SNI"
8. Select the required certificate from the dropdown
9. Select OK to create the Binding

## Recycling

By default, IIS has certain setting that will recycle/shutdown your Application Pools. This will cause some requests to "spin-up" the site for the first time, and go slow.

To help prevent this, below are some of the common setting that can be altered to stop IIS recycling/shutting down your site:

1. Open IIS, and select the Application Pools folder
2. Right click your Application Pool, and select "Advanced Settings..."
3. Under "Process Model", to stop IIS shutting down your site
    1. Set the "Idle Time-out" to 0
4. Under "Recycling", to stop IIS recycling your site
    1. Set the "Regular Time Interval" to 0
    2. Remove all times from "Specific Times"

This isn't bulletproof, and IIS can sometimes to restart your site if it feels like it. Also make sure that there are no periodic processes anywhere that might recycle Application Pools, or run `iisreset`.

When IIS does restart your site, the log file should show the usual Pode "Terminating" message, but preceded with "(IIS Shutdown)".

### Debug Line

Whenever IIS recycles/shuts down your site, you may see a debug line in your logs if the initial HTTP shutdown request fails, such as:

```plain
Entering debug mode. Use h or ? for help.

At C:\Program Files\PowerShell\Modules\Pode\2.0.3\Public\Core.ps1:176 char:13
+ $key = Get-PodeConsoleKey
+ ~~~~~~~~~~~~~~~~~~~~~~~~~
[DBG]: PS D:\wwwroot\sitename>>
```

This is nothing to worry about, and is purely just IIS terminating the PowerShell runspace to shutdown the Application Pool.

## ASP.NET Token

When hosted via IIS, Pode inspects every request to make sure the mandatory `MS-ASPNETCORE-TOKEN` header is present. This is a token supplied by IIS, and if it's missing Pode will reject the request with a 400 response.

There's nothing you need to do, IIS informs Pode about the token for you, and IIS will add the header to the requests automatically for you as well.

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

Pode can impersonate the user that requests the web page using Kerberos Constrained Delegation (KCD).

Requirements:

* The use of KCD requires additional configuration in Active Directory (read up on PrincipalsAllowedToDelegateToAccount)
* No Session middleware configured (`-Sessionless` switch on authentication setup)

This can be done using the following example:

```powershell
[System.Security.Principal.WindowsIdentity]::RunImpersonated($WebEvent.Auth.User.Identity.AccessToken, {
    $newIdentity = [Security.Principal.WindowsIdentity]::GetCurrent() | Select-Object -ExpandProperty 'Name'
    Write-PodeTextResponse -Value "You are running this command as the server user $newIdentity"
})
```

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
