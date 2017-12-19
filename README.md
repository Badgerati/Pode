# Pode

Pode is a PowerShell framework that runs a HTTP/TCP listener on a specific port, allowing you to host REST APIs, Web Pages and SMTP servers via PowerShell.

## Documentation

This documentation will cover the basics on how to use Pode to create a simple REST API, Web Page, and SMTP Server. Further examples can be found in the examples folder.

### Basics

Pode, at it's heart, is a PowerShell module. In order to use Pode, you'll need to start off your POSH WebServer by importing it:

```powershell
Import-Module Pode
```

After that, all of your main server logic must be wrapped in a `Server` block. This lets you specify port numbers, server type, and any key logic: (you can only have one `Server` per Pode script)

```powershell
Server -Port 8080 {
    # logic
}
```

The above `Server` block will start a basic HTTP listener on port 8080.

### REST API

Once you have the basics down, creating a REST API isn't far off. When creating an API in Pode, you specify logic for certain routes for specific HTTP methods. Methods supported are: DELETE, GET, HEAD, MERGE, OPTIONS, PATCH, POST, PUT, and TRACE.

The method to create new routes is `Add-PodeRoute`, this will take your method, route, and logic. For example, let's say you want a basic GET `ping` endpoint to just return `pong`:

```powershell
Add-PodeRoute 'get' '/api/ping' {
    param($session)
    Write-JsonResponse @{ 'value' = 'pong'; }
}
```

The scriptblock requires a `param` section for just one argument: `$session`. This argument will contain the `Request`, `Response` and the `Data` if the route is a POST endpoint.

The last line is to write JSON response. So anyone hitting `http://localhost:8080/api/ping` will be greeted back with `{ "value": "pong" }`.

If you wanted a POST endpoint that created a user, then it would roughly look as follows:

```powershell
Add-PodeRoute 'post' '/api/users' {
    param($session)

    # create the user
    $userId = New-DummyUser $session.Email $session.Name $session.Password

    # return with userId
    Write-JsonResponse @{ 'userId' = $userId; }
}
```

> This can be seen in the examples under `rest-api.ps1`, and `nunit-rest-api.ps1` for a more practical example

### Web Pages

It's actually possible for Pode to serve up webpages - css, fonts, and javascript included. They pretty much work exactly like the above REST APIs, except Pode has inbuilt logic to handle css/javascript.

All HTML content *must* be placed with a `/views/` directory, which is in the same location as your pode script. In here you can place your static HTML files, so when you call `Write-HtmlResponseFromFile` Pode will automatically look in the `/views/` directory. For example, if you call `Write-HtmlResponseFromFile 'simple.html'` the Pode will look for `/views/simple.html`. Likewise for `/views/main/simple.html` if you pass `'main/simple.html'` instead.

Any other file types, from css, javascript, fonts and images, must all be placed within a `/public/` directory - again, in the same location as your pode script. Here, when Pode sees a request for a path with a file extension, it will automatically look for that path in the `/public/` directory. For example, if you reference `<link rel="stylesheet" type="text/css" href="styles/simple.css">` in your HTML file, then Pode will look for `/public/styles/simple.css`.

A quick example of a single page site on port 8085:

```powershell
Server -Port 8085 {
    Add-PodeRoute 'get' '/' {
        param($session)
        Write-HtmlResponseFromFile 'simple.html'
    }
}
```

> This can be seen in the examples under `web-pages.ps1`

### SMTP Server

Pode can also run as an SMTP server - useful for mocking tests. There are two options, you can either use Pode's inbuilt simple SMTP logic, or write your own using Pode as a TCP server instead.

If you're using Pode's unbuilt SMTP logic, then you need to state so when creating the server: `Server -Smtp`. This will automatically create a TCP listener on port 25 (unless you pass a different port number).

Unlike with HTTP Routes, TCP and SMTP can only have one handler. To create a handler for the inbuilt logic:

```powershell
Server -Smtp {
    Add-PodeTcpHandler 'smtp' {
        param($session)
        Write-Host $session.From
        Write-Host $session.To
        Write-Host $session.Data
    }
}
```

The SMTP Handler will be passed a session already populated with the `From` address, the single or multiple `To` addresses, and the raw `Data` of the mail body.

> This can be seen in the examples under `mail-server.ps1`

If you want to create you own SMTP server, then you'll need to set Pode up as a TCP listener and manually read the SMTP stream yourself:

```powershell
Server -Tcp -Port 25 {
    Add-PodeTcpHandler 'tcp' {
        param($session)
        $client = $session.Client
        # your stream writing/reading here
    }
}
```

To help with writing and reading from the client stream, Pode has two helper functions

* `Write-ToTcpStream -Message 'msg'`
* `$msg = Read-FromTcpStream`

## Inbuild Functions

Pode comes with a few helper functions - mostly for writing responses and reading streams:

* `Write-ToResponse`
* `Write-ToResponseFromFile`
* `Write-JsonResponse`
* `Write-JsonResponseFromFile`
* `Write-XmlResponse`
* `Write-XmlResponseFromFile`
* `Write-HtmlResponse`
* `Write-HtmlResponseFromFile`
* `Write-ToTcpStream`
* `Read-FromTcpStream`