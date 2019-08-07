# Desktop Application

Normally in Pode you define a server and run it, however if you use the `Show-PodeGui` function Pode will serve the server up as a desktop application.

!!! warning
    Currently only supported on Windows due to using WPF.

## Setting Server to run as Application

To serve up you server as a desktop application you can just write you Pode server script as normal. The only difference is you can use the `Show-PodeGui` function to display the application.

The `Show-PodeGui` function *must* have a Title supplied - this is the title of the application's window.

The following will create a basic web server with a single page, but when the server is run it will pop up as a desktop application:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address localhost:8080 -Protocol Http

    Show-PodeGui -Title 'Basic Server'

    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        Write-PodeViewResponse -Path 'index'
    }
}
```

The page used is as follows:

```html
<html>
    <head>
        <link rel="stylesheet" type="text/css" href="/styles/main.css">
    </head>
    <body>
        <h1>Hello, world!</h1>
        <p>Welcome to a very simple desktop app!</p>
    </body>
</html>
```

## Simple script to load Application

When you run the server from your terminal, the application will open and the terminal will remain visible. However, you could have a script which opens PowerShell as hidden and launches the server.

The following is a basic example of a `.bat` file which could be double-clicked to open the application, and then hide the terminal:

```batch
powershell.exe -noprofile -windowstyle hidden -command .\you-server-script.ps1
exit
```
