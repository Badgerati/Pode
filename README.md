# Pode

[![MIT licensed](https://img.shields.io/badge/license-MIT-blue.svg)](https://raw.githubusercontent.com/Badgerati/Pode/master/LICENSE.txt)

[![Chocolatey](https://img.shields.io/chocolatey/v/pode.svg?colorB=a1301c)](https://chocolatey.org/packages/pode)
[![Chocolatey](https://img.shields.io/chocolatey/dt/pode.svg?label=downloads&colorB=a1301c)](https://chocolatey.org/packages/pode)

[![PowerShell](https://img.shields.io/powershellgallery/v/pode.svg?label=powershell&colorB=085298)](https://www.powershellgallery.com/packages/Pode)
[![PowerShell](https://img.shields.io/powershellgallery/dt/pode.svg?label=downloads&colorB=085298)](https://www.powershellgallery.com/packages/Pode)

[![Docker](https://img.shields.io/docker/pulls/badgerati/pode.svg)](https://hub.docker.com/r/badgerati/pode/)

Pode is a PowerShell framework that runs HTTP/TCP listeners on specific ports, allowing you to host [REST APIs](#rest-api), [Web Pages](#web-pages) and [SMTP/TCP](#smtp-server) servers via PowerShell. It also allows you to render dynamic HTML using [PSHTML](#pshtml) files.

## Features

* Can run on Unix environments using PowerShell Core
* Host REST APIs and Web Pages
* Run TCP listeners
* Host SMTP servers - great for tests and mocking
* Use the full power of PowerShell, want a REST API for NUnit? Go for it!
* Ability to write dynamic webpages in PowerShell using PSHTML (As well as PSCSS and PSJS)
* Can use yarn package manager to install bootstrap, or other frontend libraries

## Install

You can install Pode from either Chocolatey, the PowerShell Gallery, or Docker:

```powershell
# chocolatey
choco install pode

# powershell gallery
Install-Module -Name Pode

# docker
docker pull badgerati/pode
```

## Documentation

This documentation will cover the basics on how to use Pode to create a simple REST API, Web Page, and SMTP Server. Further examples can be found in the examples folder.

### Setup

Pode has a couple of useful commands that you can use on the CLI, to help you initialise, start, test, build, or install any packages for your repo. These commands all utilise the `package.json` structure - as seen in Node and Yarn.

> At the moment, Pode only uses the `start`, `test`, `build` and `install` properties of the `scripts` section in your `package.json`. You can still have others, like `dependencies` for Yarn

```powershell
# similar to yarn and node, init will help you create a new package.json
pode init

# if you have a "start" script this will run that property; otherwise will run the script in "main"
pode start

# if you have a "test" script this will run that property
pode test

# if you have a "install" script this will run that property
pode install

# if you have a "build" script this will run that property
pode build
```

> By default, Pode will pre-populate `test`, `build` and `install` using `yarn`, `psake` and `pester` respectively

Following is an example `package.json`

```json
{
    "name":  "example",
    "description":  "",
    "version":  "1.0.0",
    "main":  "./file.ps1",
    "scripts":  {
        "start":  "./file.ps1",
        "test":  "invoke-pester ./tests/*.ps1",
        "install":  "yarn install --force --ignore-scripts --modules-folder pode_modules",
        "build": "psake"
    },
    "author":  "",
    "license":  "MIT"
}
```

### Frontend

You can host web-pages using Pode, and to help you can also use package managers like `yarn` to help install frontend libraries (like bootstrap).

```powershell
choco install yarn -y
yarn init
yarn add bootstrap
```

When run, Pode will tell `yarn` to install the packages to a `pode_modules` directory. Other useful packages could include `gulp`, `lodash`, `moment`, etc.

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

The scriptblock requires a `param` section for just one argument: `$session`. This argument will contain the `Request` and `Response` objeccts; `Data` (from POST), and the `Query` (from the query string of the URL), as well as any `Parameters` from the route itself (eg: `/:accountId`).

The last line is to write the JSON response. Anyone hitting `http://localhost:8080/api/ping` will be greeted back with `{ "value": "pong" }`.

If you wanted a POST endpoint that created a user, and a GET endpoint to get details of a user, then it would roughly look as follows:

```powershell
Server -Port 8080 {
    Add-PodeRoute 'post' '/api/users' {
        param($session)

        # create the user
        $userId = New-DummyUser $session.Data.Email $session.Data.Name $session.Data.Password

        # return with userId
        Write-JsonResponse @{ 'userId' = $userId; }
    }

    Add-PodeRoute 'get' '/api/users/:userId'{
        param($session)

        # get the user
        $user = Get-DummyUser -UserId $session.Parameters['userId']

        # return the user
        Write-JsonResponse @{ 'user' = $user; }
    }
}
```

> More can be seen in the examples under `rest-api.ps1`, and `nunit-rest-api.ps1`

### Web Pages

It's actually possible for Pode to serve up webpages - css, fonts, and javascript included. They pretty much work exactly like the above REST APIs, except Pode has inbuilt logic to handle css/javascript and other files.

Pode also has its own format for writing HTML pages: PSHTML, PSCSS and PSJS. There are examples in the example directory, but in general they allow you to dynamically generate HTML, CSS and JS using PowerShell.

All HTML (and PSHTML) content *must* be placed within a `/views/` directory, which is in the same location as your Pode script. In here you can place your HTML/PSHTML files, so when you call `Write-ViewResponse` Pode will automatically look in the `/views/` directory. For example, if you call `Write-ViewResponse 'simple'` then Pode will look for `/views/simple.html`. Likewise for `/views/main/simple.html` if you pass `'main/simple'` instead.

> Pode uses a View Engine to either render HTML or PSHTML. Default is HTML, and you can change it by calling `Set-PodeViewEngine 'PSHTML'` at the top of your Server scriptblock

Any other file types, from css/pscss to javascript/psjs, fonts and images, must all be placed within a `/public/` directory - again, in the same location as your Pode script. Here, when Pode sees a request for a path with a file extension, it will automatically look for that path in the `/public/` directory. For example, if you reference `<link rel="stylesheet" type="text/css" href="styles/simple.css">` in your HTML file, then Pode will look for `/public/styles/simple.css`.

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

To use PSHTML files, you will need to place them within the `/views/` folder. Then you'll need to set the View Engine for Pode to be PSHTML; once set, you can just write view responses as per normal:

> Any PowerShell in a PSHTML will need to use semi-colons to end each line

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
        <span>$([DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss');)</span>
    </body>
</html>
```

> When you need to use PowerShell, ensure you wrap the commands within `$(...)`, and end each line with a semi-colon (as you would in C#/Java)

You can also supply data to `Write-ViewResponse` when rendering PSHTML files. This allows you to make them far more dynamic. The data supplied to `Write-ViewResponse` must be a `hashtable`, and can be referenced within a PSHTML file by using `$data`.

For example, say you need to render a search page which is a list of accounts, then you're basic Pode script would look like:

```powershell
Server -Port 8080 {
    # set the engine to use and render PSHTML files
    Set-PodeViewEngine 'PSHTML'

    # render the search.pshtml file
    Add-PodeRoute 'get' '/' {
        param($session)

        # some logic to get accounts
        $query = $session.Query['query']
        $accounts = Find-Account -Query $query

        # render the file
        Write-ViewResponse 'search' -Data @{ 'query' = $query; 'accounts' = $accounts; }
    }
}
```

You can see that we're supplying the found accounts to the `Write-ViewResponse` function as a `hashtable`. Next, we see the `search.pshtml` file which generates the HTML:

```html
<!-- search.pshtml -->
<html>
    <head>
        <title>Search</title>
    </head>
    <body>
        <h1>Search</h1>
        Query: $($data.query;)

        <div>
            $(foreach ($account in $data.accounts) {
                "<div>Name: $($account.Name)</div><hr/>";
            })
        </div>
    </body>
</html>
```

> Remember, you can access supplied data by using `$data`

### PSCSS and PSJS
The rules for PSCSS and PSJS files work exactly like the PSHTML files above, just they're placed within the `/public/` directory instead of the `/views/` directory.

For example, the below PSCSS will render the page in purple on even seconds, or red on odd seconds:

```css
body {
    $(
        $date = [DateTime]::UtcNow;

        if ($date.Second % 2 -eq 0)
        {
            "background-color: rebeccapurple;";
        }
        else
        {
            "background-color: red;";
        }
    )
}
```

## Inbuilt Functions

Pode comes with a few helper functions - mostly for writing responses and reading streams:

* `Add-PodeRoute`
* `Get-PodeRoute`
* `Add-PodeTcpHandler`
* `Get-PodeTcpHandler`
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