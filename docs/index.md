# Welcome

[![MIT licensed](https://img.shields.io/badge/license-MIT-blue.svg)](https://raw.githubusercontent.com/Badgerati/Pode/master/LICENSE.txt)
[![AppVeyor](https://img.shields.io/appveyor/ci/Badgerati/Pode/develop.svg?label=AppVeyor)](https://ci.appveyor.com/project/Badgerati/pode/branch/develop)
[![Travis CI](https://img.shields.io/travis/Badgerati/Pode/develop.svg?label=Travis%20CI)](https://travis-ci.org/Badgerati/Pode)
[![Gitter](https://badges.gitter.im/Badgerati/Pode.svg)](https://gitter.im/Badgerati/Pode?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge)

Pode is a Cross-Platform PowerShell framework that allows you to host REST APIs, Web Pages and SMTP/TCP servers. It also allows you to render dynamic files using `.pode` files, which is effectively embedded PowerShell, or other Third-Party template engines. Pode also has support for middleware, sessions, and authentication; as well as access and rate limiting features.

[![GetStarted](https://img.shields.io/badge/-Get%20Started!-green.svg?longCache=true&style=for-the-badge)](./Getting-Started/Installation)
[![QuickLook](https://img.shields.io/badge/-Quick%20Look!-blue.svg?longCache=true&style=for-the-badge)](#quick-look)

## Features

* Can run on *nix environments using PowerShell Core
* Host REST APIs, Web Pages, Static Content, TCP and SMTP server
* Multiple threads can be used to response to incoming requests
* Inbuilt template engine, with support for third-parties
* Setup async timers to be used as one off tasks, or for housekeeping services
* Ability to schedule async tasks using cron expressions
* Supports logging to CLI, Files, and custom loggers to other services like LogStash, etc.
* Cross-state variable access across multiple runspaces
* Optional file monitoring to trigger internal server restart on file changes
* Ability to allow/deny requests from certain IP addresses and subnets
* Basic rate limiting for IP addresses and subnets
* Support for generating/binding self-signed certificates, and signed certificates on Windows
* Support for middleware and sessions on web servers
* Can use authentication on requests, which can either be sessionless or session persistent

## Quick Look!

Below is a quick example of using Pode to create a single REST API endpoint to return a JSON response. It will [`listen`](./Functions/Core/Listen) on a port, create the [`route`](./Functions/Core/Route), and respond with [`JSON`](./Functions/Response/Json) when `http://localhost:8080/ping` is hit:

```powershell
Server {
    listen *:8080 http

    route get '/ping' {
        json @{ 'value' = 'pong' }
    }
}
```

[![GetStarted](https://img.shields.io/badge/-Get%20Started!-green.svg?longCache=true&style=for-the-badge)](./Getting-Started/Installation)