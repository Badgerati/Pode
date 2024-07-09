<p align="center">
    <img src="https://github.com/Badgerati/Pode/raw/develop/images/icon-new.svg?raw=true" width="250" />
</p>

[![MIT licensed](https://img.shields.io/badge/license-MIT-blue.svg)](https://raw.githubusercontent.com/Badgerati/Pode/master/LICENSE.txt)
[![Documentation](https://img.shields.io/github/v/release/badgerati/pode?label=docs&logo=readthedocs&logoColor=white)](https://badgerati.github.io/Pode)
[![GitHub Actions](https://img.shields.io/endpoint.svg?url=https%3A%2F%2Factions-badge.atrox.dev%2Fbadgerati%2Fpode%2Fbadge&style=flat&label=GitHub)](https://actions-badge.atrox.dev/badgerati/pode/goto)
[![Code Coverage](https://coveralls.io/repos/github/Badgerati/Pode/badge.svg?branch=develop)](https://coveralls.io/github/Badgerati/Pode?branch=develop)
[![Discord](https://img.shields.io/discord/887398607727255642?logo=discord&logoColor=white)](https://discord.gg/fRqeGcbF6h)

[![Chocolatey](https://img.shields.io/chocolatey/dt/pode.svg?label=Chocolatey&colorB=a1301c&logo=chocolatey&logoColor=white)](https://chocolatey.org/packages/pode)
[![PowerShell](https://img.shields.io/powershellgallery/dt/pode.svg?label=PowerShell&colorB=085298&logo=powershell&logoColor=white)](https://www.powershellgallery.com/packages/Pode)
[![Docker](https://img.shields.io/docker/pulls/badgerati/pode.svg?label=Docker&logoColor=white&logo=docker)](https://hub.docker.com/r/badgerati/pode/)

[![GitHub Sponsors](https://img.shields.io/github/sponsors/Badgerati?color=%23ff69b4&logo=github&style=flat&label=Sponsers)](https://github.com/sponsors/Badgerati)
[![Ko-fi](https://img.shields.io/static/v1?logo=kofi&label=Ko-fi&logoColor=white&message=Buy+me+a+coffee&color=ff5f5f)](https://ko-fi.com/badgerati)
[![PayPal](https://img.shields.io/static/v1?logo=paypal&label=PayPal&logoColor=white&message=Donate&color=00457C)](https://paypal.me/badgerati)

> 💝 A lot of my free time, evenings, and weekends goes into making Pode happen; please do consider sponsoring as it will really help! 😊

- [📘 Documentation](#-documentation)
- [🚀 Features](#-features)
- [📦 Install](#-install)
- [🙌 Contributing](#-contributing)
- [🌎 Roadmap](#-roadmap)

Pode is a Cross-Platform framework for creating web servers to host [REST APIs](https://badgerati.github.io/Pode/Tutorials/Routes/Overview/), [Web Pages](https://badgerati.github.io/Pode/Tutorials/Routes/Examples/WebPages/), and [SMTP/TCP](https://badgerati.github.io/Pode/Servers/) Servers. Pode also allows you to render dynamic files using [`.pode`](https://badgerati.github.io/Pode/Tutorials/Views/Pode/) files, which are just embedded PowerShell, or other [Third-Party](https://badgerati.github.io/Pode/Tutorials/Views/ThirdParty/) template engines. Plus many more features, including [Azure Functions](https://badgerati.github.io/Pode/Hosting/AzureFunctions/) and [AWS Lambda](https://badgerati.github.io/Pode/Hosting/AwsLambda/) support!

```powershell

Start-PodeServer -ScriptBlock {
    Add-PodeEndPoint -Address localhost -port 32005 -Protocol Http
    Add-PodeRoute -Method Get -Path '/ping' -ScriptBlock {
        Write-PodeJsonResponse -Value @{value = 'pong' }
    }
}

```

See [here](https://badgerati.github.io/Pode/Getting-Started/FirstApp) for building your first app! Don't know HTML, CSS, or JavaScript? No problem! [Pode.Web](https://github.com/Badgerati/Pode.Web) is currently a work in progress, and lets you build web pages using purely PowerShell!

## 📘 Documentation

All documentation and tutorials for Pode can be [found here](https://badgerati.github.io/Pode) - this documentation will be for the latest release.

To see the docs for other releases, branches or tags, you can host the documentation locally. To do so you'll need to have the [`InvokeBuild`](https://github.com/nightroman/Invoke-Build) module installed; then:

```powershell
Invoke-Build Docs
```

Then navigate to `http://127.0.0.1:8000` in your browser.

## 🚀 Features

* Cross-platform using PowerShell Core (with support for PS5)
* Docker support, including images for ARM/Raspberry Pi
* Azure Functions, AWS Lambda, and IIS support
* OpenAPI specification version 3.0.x and 3.1.0
* OpenAPI documentation with Swagger, Redoc, RapidDoc, StopLight, OpenAPI-Explorer and RapiPdf
* Listen on a single or multiple IP(v4/v6) address/hostnames
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

## 📦 Install

You can install Pode from either Chocolatey, the PowerShell Gallery, or Docker:

```powershell
# chocolatey
choco install pode

# powershell gallery
Install-Module -Name Pode

# docker
docker pull badgerati/pode
```

## 🙌 Contributing

> The full contributing guide can be [found here](https://github.com/Badgerati/Pode/blob/develop/.github/CONTRIBUTING.md)

Pull Requests, Bug Reports and Feature Requests are welcome! Feel free to help out with Issues and Projects!

To run the unit tests, run the following command from the root of the repository (this will build Pode and, if needed, auto-install Pester/.NET):

```powershell
Invoke-Build Test
```

To just build Pode, before running any examples, run the following:

```powershell
Invoke-Build Build
```

More information on how to build Pode can be [found here](./docs/Getting-Started/build.md)

To work on issues you can fork Pode, and then open a Pull Request for approval. Pull Requests should be made against the `develop` branch. Each Pull Request should also have an appropriate issue created.

## 🌎 Roadmap

You can find a list of the features, enhancements and ideas that will hopefully one day make it into Pode [here in the documentation](https://badgerati.github.io/Pode/roadmap/).

There is also a [Project Board](https://github.com/users/Badgerati/projects/2) in the beginnings of being setup for Pode, with milestone progression and current roadmap issues and ideas. If you see any draft issues you wish to discuss, or have an idea for one, please discuss it over on [Discord](https://discord.gg/fRqeGcbF6h) in the `#ideas` or `#pode` channel.
