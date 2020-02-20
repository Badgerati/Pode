# IIS

Pode's all PowerShell Web Server now enables you to host your server via IIS!

When you host your server through IIS, Pode can detect this and internally set the server type and endpoints to automatically work with IIS. This allows IIS to deal with binding, HTTPS and Certificates, as well as external traffic, etc.

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
pwsh -c "Install-Module Pode"
```

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
    This does mean that the Pode server will force all endpoints to `127.0.0.1:PORT`. So if you had two different IPs before, they'll be merged into one.

## HTTPS

Although Pode does have support for HTTPS, when running via IIS it takes control of HTTPS for us - this is why the endpoints are forced to HTTP.

You can setup a binding in IIS for HTTPS with a Certificate, and IIS will deal with SSL for you.

## Useful Links

* [Host ASP.NET Core on Windows with IIS \| Microsoft Docs](https://docs.microsoft.com/en-us/aspnet/core/host-and-deploy/iis/?view=aspnetcore-3.1)
