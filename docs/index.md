# Welcome

[![MIT licensed](https://img.shields.io/badge/license-MIT-blue.svg)](https://raw.githubusercontent.com/Badgerati/Pode/master/LICENSE.txt)
[![AppVeyor](https://img.shields.io/appveyor/ci/Badgerati/Pode/develop.svg?label=AppVeyor)](https://ci.appveyor.com/project/Badgerati/pode/branch/develop)
[![Travis CI](https://img.shields.io/travis/Badgerati/Pode/develop.svg?label=Travis%20CI)](https://travis-ci.org/Badgerati/Pode)
[![Code Coverage](https://coveralls.io/repos/github/Badgerati/Pode/badge.svg?branch=develop)](https://coveralls.io/github/Badgerati/Pode?branch=develop)
[![Gitter](https://badges.gitter.im/Badgerati/Pode.svg)](https://gitter.im/Badgerati/Pode?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge)

Pode is a Cross-Platform PowerShell framework to create web servers that host REST APIs, Web Sites, and TCP/SMTP Servers. It also allows you to render dynamic files using `.pode` files, which is effectively embedded PowerShell, or other Third-Party template engines. Pode also has support for middleware, sessions, and authentication; as well as access and rate limiting features.

[![GetStarted](https://img.shields.io/badge/-Get%20Started!-green.svg?longCache=true&style=for-the-badge)](./Getting-Started/Installation)
[![QuickLook](https://img.shields.io/badge/-Quick%20Look!-blue.svg?longCache=true&style=for-the-badge)](#quick-look)

## Features

* Cross-platform using PowerShell Core (with support for PS4.0+)
* Docker support, including images for ARM/Raspberry Pi
* Listen on a single or multiple IP address/hostnames
* Support for HTTP, HTTPS, TCP and SMTP
* Host REST APIs, Web Pages, and Static Content (with caching)
* Support for custom error pages
* Multi-thread support for incoming requests
* Inbuilt template engine, with support for third-parties
* Async timers for short-running repeatable processes
* Async scheduled tasks using cron expressions for short/long-running processes
* Supports request logging to CLI, Files, and custom loggers to other services like LogStash
* Cross-state variable access across multiple runspaces
* Restart the server via file monitoring, or defined periods/times
* Ability to allow/deny requests from certain IP addresses and subnets
* Basic rate limiting for IP addresses and subnets
* Middleware and Sessions on web servers, with Flash message and CSRF support
* Authentication on requests, such as Basic and Windows Active Directory
* (Windows) Generate/bind self-signed certificates, and signed certificates
* (Windows) Open the hosted server as a desktop application

## Quick Look!

Below is a quick example of using Pode to create a single REST API endpoint to return a JSON response. It will [`listen`](./Functions/Core/Listen) on an endpoint, create the [`route`](./Functions/Core/Route), and respond with [`JSON`](./Functions/Response/Json) when `http://localhost:8080/ping` is hit:

```powershell
Server {
    listen localhost:8080 http

    route get '/ping' {
        json @{ 'value' = 'pong' }
    }
}
```

[![GetStarted](https://img.shields.io/badge/-Get%20Started!-green.svg?longCache=true&style=for-the-badge)](./Getting-Started/Installation)