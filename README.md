# Pode

[![MIT licensed](https://img.shields.io/badge/license-MIT-blue.svg)](https://raw.githubusercontent.com/Badgerati/Pode/master/LICENSE.txt)

[![Chocolatey](https://img.shields.io/chocolatey/v/pode.svg?colorB=a1301c)](https://chocolatey.org/packages/pode)
[![Chocolatey](https://img.shields.io/chocolatey/dt/pode.svg?label=downloads&colorB=a1301c)](https://chocolatey.org/packages/pode)

Pode is a PowerShell framework that runs HTTP/TCP listeners on a specific port, allowing you to host [REST APIs](#rest-api), [Web Pages](#web-pages) and [SMTP/TCP](#smtp-server) servers via PowerShell. It also allows you to render dynamic HTML using [PSHTML](#pshtml) files.

## Features

* Host REST APIs and Web Pages
* Run TCP listeners
* Host SMTP servers - great for tests and mocking
* Use the full power of PowerShell, want a REST API for NUnit? Go for it!
* Ability to write dynamic webpages in PowerShell using PSHTML

## Documentation

This documentation will cover the basics on how to use Pode to create a simple REST API, Web Page, and SMTP Server. Further examples can be found in the examples folder.

### Basics

Pode, at it's heart, is a PowerShell module. In order to use Pode, you'll need to start off your script by importing it:

```powershell
Import-Module Pode
```

After that, all of your main server logic must be wrapped in a `Server` block. This lets you specify port numbers, server type, and any key logic: (you can only have one `Server` per Pode script)

```powershell
Server -Port 8080 {
    # logic
}
```

The above `Server` block will start a basic HTTP listener on port 8080. Once started, to exit out of Pode at anytime just use `Ctrl+C`.

### REST API

Once you have the basics down, creating a REST API isn't far off. When creating an API in Pode, you specify logic for certain routes for specific HTTP methods. Methods supported are: DELETE, GET, HEAD, MERGE, OPTIONS, PATCH, POST, PUT, and TRACE.

The method to create new routes is `Add-PodeRoute`, this will take your method, route, and logic. For example, let's say you want a basic GET `ping` endpoint to just return `pong`:

```powershell
Server -Port 8080 {
    Add-PodeRoute 'get' '/api/ping' {
        param($session)
        Write-JsonResponse @{ 'value' = 'pong'; }
    }
}
```

The scriptblock requires a `param` section for just one argument: `$session`. This argument will contain the `Request`, `Response` and the `Data` if the route is a POST endpoint.

The last line is to write JSON response. So anyone hitting `http://localhost:8080/api/ping` will be greeted back with `{ "value": "pong" }`.

If you wanted a POST endpoint that created a user, then it would roughly look as follows:

```powershell
Server -Port 8080 {
    Add-PodeRoute 'post' '/api/users' {
        param($session)

        # create the user
        $userId = New-DummyUser $session.Email $session.Name $session.Password

        # return with userId
        Write-JsonResponse @{ 'userId' = $userId; }
    }
}
```

> This can be seen in the examples under `rest-api.ps1`, and `nunit-rest-api.ps1` for a more practical example

### Web Pages

It's actually possible for Pode to serve up webpages - css, fonts, and javascript included. They pretty much work exactly like the above REST APIs, except Pode has inbuilt logic to handle css/javascript.

Pode also has its own format for writing HTML pages: PSHTML. There are examples in the example directory, but they allow you to dynamic generate HTML using PowerShell.

All HTML (and PSHTML) content *must* be placed with a `/views/` directory, which is in the same location as your pode script. In here you place your HTML/PSHTML files, so when you call `Write-ViewResponse` Pode will automatically look in the `/views/` directory. For example, if you call `Write-ViewResponse 'simple'` then Pode will look for `/views/simple.html`. Likewise for `/views/main/simple.html` if you pass `'main/simple'` instead.

> Pode uses a View Engine to either render HTML or PSHTML. Default is HTML, and you can change it by calling `Set-PodeViewEngine 'PSHTML'` at the top of your Server scriptblock

Any other file types, from css to javascript, fonts and images, must all be placed within a `/public/` directory - again, in the same location as your pode script. Here, when Pode sees a request for a path with a file extension, it will automatically look for that path in the `/public/` directory. For example, if you reference `<link rel="stylesheet" type="text/css" href="styles/simple.css">` in your HTML file, then Pode will look for `/public/styles/simple.css`.

A quick example of a single page site on port 8085:

```powershell
Server -Port 8085 {
    Set-PodeViewEngine 'HTML'

    Add-PodeRoute 'get' '/' {
        param($session)
        Write-ViewResponse 'simple'
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

## PSHTML

PSHTML is mostly just an HTML file - in fact, you can write pure HTML and still be able to use it. The difference is that you're able to embed PowerShell logic into the file, which allows you to dynamically generate HTML.

To use PSHTML files, you will need to place them within the `/views/` folder. Then you'll need to set the View Engine for Pode to be PSHTML; once set, you can just write view responses as per normal

```powershell
Server -Port 8080 {
    # set the engine to use and render PSHTML files
    Set-PodeViewEngine 'PSHTML'

    # render the index.pshtml file
    Add-PodeRoute 'get' '/' {
        param($session)
        Write-ViewResponse 'index'
    }
}
```

Below is a basic example of a PSHTML file which just writes the current date to the browser:

```html
<!-- index.pshtml -->
<html>
    <head>
        <title>Current Date</title>
    </head>
    <body>
        <span>$([DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss'))</span>
    </body>
</html>
```

> When you need to use PowerShell, ensure you wrap them within `$(...)`

You can also supply data to `Write-ViewResponse` when rendering PSHTML files. This allows you to make them far more dynamic. The data supplied to `Write-ViewResponse` must be a `hashtable`, and can be referenced within a PSHTML file by using `$data`.

For example, say you need to render a search page which is a list of accounts, then you're basic pode script would look like:

```powershell
Server -Port 8080 {
    # set the engine to use and render PSHTML files
    Set-PodeViewEngine 'PSHTML'

    # render the search.pshtml file
    Add-PodeRoute 'get' '/' {
        param($session)

        # some logic to get accounts
        $query = $session.Request.QueryString.Item('query')
        $accounts = Find-Account -Query $query
        
        # render the file
        Write-ViewResponse 'search' -Data @{ 'query' = $query; 'accounts' = $accounts; }
    }
}
```

You can see that we're supplying the found accounts to the `Write-ViewResponse` function as a hashtable. Next, we see the `search.pshtml` file which generates the HTML:

```html
<!-- search.pshtml -->
<html>
    <head>
        <title>Search</title>
    </head>
    <body>
        <h1>Search</h1>
        Query: $($data.query)

        <div>
            $(foreach ($account in $data.accounts) {
                "<div>Name: $($account.Name)</div><hr/>"
            })
        </div>
    </body>
</html>
```

> Remember, you can access supplied data by using `$data`

## Inbuild Functions

Pode comes with a few helper functions - mostly for writing responses and reading streams:

* `Add-PodeRoute`
* `Add-PodeTcpHandler`
* `Write-ToResponse`
* `Write-ToResponseFromFile`
* `Write-JsonResponse`
* `Write-JsonResponseFromFile`
* `Write-XmlResponse`
* `Write-XmlResponseFromFile`
* `Write-HtmlResponse`
* `Write-HtmlResponseFromFile`
* `Write-ViewResponse`
* `Write-ToTcpStream`
* `Read-FromTcpStream`
* `Set-PodeViewEngine`