# Welcome!

[![MIT licensed](https://img.shields.io/badge/license-MIT-blue.svg)](https://raw.githubusercontent.com/Badgerati/Pode/master/LICENSE.txt)
[![GitHub Actions](https://img.shields.io/endpoint.svg?url=https%3A%2F%2Factions-badge.atrox.dev%2Fbadgerati%2Fpode%2Fbadge&style=flat&label=GitHub)](https://actions-badge.atrox.dev/badgerati/pode/goto)
[![Code Coverage](https://coveralls.io/repos/github/Badgerati/Pode/badge.svg?branch=develop)](https://coveralls.io/github/Badgerati/Pode?branch=develop)
[![Discord](https://img.shields.io/discord/887398607727255642)](https://discord.gg/fRqeGcbF6h)

[![GitHub Sponsors](https://img.shields.io/github/sponsors/Badgerati?color=%23ff69b4&logo=github&style=flat&label=Sponsers)](https://github.com/sponsors/Badgerati)
[![Ko-fi](https://img.shields.io/static/v1?logo=kofi&label=Ko-fi&logoColor=white&message=Buy+me+a+coffee&color=ff5f5f)](https://ko-fi.com/badgerati)
[![PayPal](https://img.shields.io/static/v1?logo=paypal&label=PayPal&logoColor=white&message=Donate&color=00457C)](https://paypal.me/badgerati)

> 💝 A lot of my free time, evenings, and weekends goes into making Pode happen; please do consider sponsoring as it will really help! 😊

Pode is a Cross-Platform framework to create web servers that host REST APIs, Web Sites, and TCP/SMTP Servers. It also allows you to render dynamic files using `.pode` files, which is effectively embedded PowerShell, or other Third-Party template engines. Pode also has support for middleware, sessions, authentication, and logging; as well as access and rate limiting features. There's also Azure Functions and AWS Lambda support!

[![GetStarted](https://img.shields.io/badge/-Get%20Started!-green.svg?longCache=true&style=for-the-badge)](./Getting-Started/FirstApp)
[![QuickLook](https://img.shields.io/badge/-Quick%20Look!-blue.svg?longCache=true&style=for-the-badge)](#quick-look)

## 🚀 Features

* Cross-platform using PowerShell Core (with support for PS5)
* Docker support, including images for ARM/Raspberry Pi
* Azure Functions, AWS Lambda, and IIS support
* OpenAPI specification version 3.0.x and 3.1.0
* OpenAPI documentation with Swagger, Redoc, RapidDoc, StopLight, OpenAPI-Explorer and RapiPdf
* Listen on a single or multiple IP(v4/v6) addresses/hostnames
* Cross-platform support for HTTP(S), WS(S), SSE, SMTP(S), and TCP(S)
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
* Authorisation support on requests, using Roles, Groups, Scopes, etc.
* Support for dynamically building Routes from Functions and Modules
* Generate/bind self-signed certificates
* Secret management support to load secrets from vaults
* Support for File Watchers
* In-memory caching, with optional support for external providers (such as Redis)
* (Windows) Open the hosted server as a desktop application
* FileBrowsing support
* Localization (i18n) in Arabic, German, Spanish, France, Italian, Japanese, Korean, Polish, Portuguese, and Chinese

## 🏢 Companies using Pode

[![coop](./images/companies/coop-logo.png)](https://coop.dk)

## 🔥 Quick Look!

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
