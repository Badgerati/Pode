# Desktop Application

Normally in Pode you define a server and run it however, using the [`gui`](../../Functions/Core/Gui) function Pode can serve the server up as a desktop application.

!!! warning
    Currently only supported on Windows due to using WPF. (Though it appears WPF could soon be supported on .NET Core 3)

## Setting Server to run as Application

To serve up you server as a desktop application you can just write you Pode server script as normal. The only difference is you can use the [`gui`](../../Functions/Core/Gui) function to display the application. The make-up of the function is as follows:

```powershell
gui <name> [-options @{}]
```

The `gui` *must* have a name supplied - this is the title of the application's window. The options are a `hashtable` that define further feature to customise the window.

The following will create a basic web server with a single page, but when the server is run it will pop up as a desktop application:

```powershell
Server {
    gui 'Basic Server'

    listen localhost:8080 http

    route get '/' {
        view 'index'
    }
}
```

The page used is as follows:

```html
<html>
    <head>
        <link rel="stylesheet" type="text/css" href="styles/main.css">
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