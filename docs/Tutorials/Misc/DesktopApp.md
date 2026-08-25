# Desktop Application

Normally in Pode you define a server and run it, however if you use [`Show-PodeGui`](../../../Functions/Core/Show-PodeGui) then Pode will display the server as a desktop application.

!!! warning
    Currently only supported in Windows PowerShell, and PowerShell 7 on Windows due to requiring WPF.

## Server to run as Application

To display your server as a desktop application you write you Pode server script as normal, the only difference is you use [`Show-PodeGui`](../../../Functions/Core/Show-PodeGui) to display the application - a `-Title` is required.

The following will create a basic web server with a single page, but when the server is run it will display as a desktop application:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address localhost -Port 8080 -Protocol Http

    Show-PodeGui -Title 'Example Server'

    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        Write-PodeViewResponse -Path 'index'
    }
}
```

The page used is as follows:

```html
<html>
  <head>
    <link rel="stylesheet" type="text/css" href="/styles/main.css" />
  </head>
  <body>
    <h1>Hello, world!</h1>
    <p>Welcome to a very simple desktop app!</p>
  </body>
</html>
```

## Script to load Application

When you run the server from your terminal, the application will open and the terminal will remain visible. However, you use a script which opens PowerShell as hidden and launches the server.

The following is a basic example of a `.bat` file which could be double-clicked to open the application, and then hide the terminal:

```batch
powershell.exe -noprofile -windowstyle hidden -command .\you-server-script.ps1
exit
```

## Using Chromium

The default WPF Browser Element used by Pode is based on the system internal Internet Explorer API, which is also bound to the same JavaScript and web browser limitations as Internet Explorer itself.

To utilise Chromium in WPF instead, Pode offers support for using [`CefSharp`](http://cefsharp.github.io/) which adds a Chromium Web Element to WPF. Pode will automatically switch to CefSharp if the binaries are loaded into the Powershell session before the Pode Module itself gets initialised.

The following packages are required, and can be compiled from scratch or downloaded from NuGet:

* [CefSharp.Wpf](https://www.nuget.org/packages/CefSharp.Wpf/)
* [CefSharp.Common](https://www.nuget.org/packages/CefSharp.Common/)
* [chromiumembeddedframework.runtime.win-x64](https://www.nuget.org/packages/chromiumembeddedframework.runtime.win-x64/)

This example shows how to load them:

```Powershell
Import-Module -Name "$PSScriptRoot\lib\cefsharp\CefSharp.dll"
Import-Module -Name "$PSScriptRoot\lib\cefsharp\CefSharp.Wpf.dll"
```
