# Welcome!

[![MIT licensed](https://img.shields.io/badge/license-MIT-blue.svg)](https://raw.githubusercontent.com/Badgerati/Pode/master/LICENSE.txt)
[![GitHub Actions](https://img.shields.io/endpoint.svg?url=https%3A%2F%2Factions-badge.atrox.dev%2Fbadgerati%2Fpode%2Fbadge&style=flat&label=GitHub)](https://actions-badge.atrox.dev/badgerati/pode/goto)
[![Code Coverage](https://coveralls.io/repos/github/Badgerati/Pode/badge.svg?branch=develop)](https://coveralls.io/github/Badgerati/Pode?branch=develop)
[![Gitter](https://badges.gitter.im/Badgerati/Pode.svg)](https://gitter.im/Badgerati/Pode?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge)
[![GitHub Sponsors](https://img.shields.io/github/sponsors/Badgerati?color=%23ff69b4&logo=github&style=flat&label=Sponsers)](https://github.com/sponsors/Badgerati)

Pode is a Cross-Platform framework to create web servers that host REST APIs, Web Sites, and TCP/SMTP Servers. It also allows you to render dynamic files using `.pode` files, which is effectively embedded PowerShell, or other Third-Party template engines. Pode also has support for middleware, sessions, authentication, and logging; as well as access and rate limiting features. There's also Azure Functions and AWS Lambda support!

[![GetStarted](https://img.shields.io/badge/-Get%20Started!-green.svg?longCache=true&style=for-the-badge)](./Getting-Started/FirstApp)
[![QuickLook](https://img.shields.io/badge/-Quick%20Look!-blue.svg?longCache=true&style=for-the-badge)](#quick-look)

## Features

* Cross-platform using PowerShell Core (with support for PS5)
* Docker support, including images for ARM/Raspberry Pi
* Azure Functions, AWS Lambda, and IIS support
* OpenAPI, Swagger, and ReDoc support
* Listen on a single or multiple IP address/hostnames
* Cross-platform support for HTTP, HTTPS, TCP and SMTP
* Cross-platform support for WebSockets, including secure WebSockets
* Host REST APIs, Web Pages, and Static Content (with caching)
* Support for custom error pages
* Request and Response compression using GZip/Deflate
* Multi-thread support for incoming requests
* Inbuilt template engine, with support for third-parties
* Async timers for short-running repeatable processes
* Async scheduled tasks using cron expressions for short/long-running processes
* Supports logging to CLI, Files, and custom logic for other services like LogStash
* Cross-state variable access across multiple runspaces
* Restart the server via file monitoring, or defined periods/times
* Ability to allow/deny requests from certain IP addresses and subnets
* Basic rate limiting for IP addresses and subnets
* Middleware and Sessions on web servers, with Flash message and CSRF support
* Authentication on requests, such as Basic, Windows and Azure AD
* Support for dynamically building Routes from Functions and Modules
* Generate/bind self-signed certificates
* (Windows) Open the hosted server as a desktop application

## Companies using Pode

[![coop](./images/companies/coop-logo.png)](https://coop.dk)

## Quick Look!

Below is a quick example of using Pode to create a single REST API endpoint to return a JSON response. It will listen on an endpoint, create the route, and respond with a JSON object when `http://localhost:8080/ping` is called:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address localhost -Port 8080 -Protocol Http

    Add-PodeRoute -Method Get -Path '/ping' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ 'value' = 'pong' }
    }
}
```

[![GetStarted](https://img.shields.io/badge/-Get%20Started!-green.svg?longCache=true&style=for-the-badge)](./Getting-Started/FirstApp)
