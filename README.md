# <img src="https://github.com/Badgerati/Pode/blob/develop/images/icon.png?raw=true" width="25" /> Pode

[![MIT licensed](https://img.shields.io/badge/license-MIT-blue.svg)](https://raw.githubusercontent.com/Badgerati/Pode/master/LICENSE.txt)
[![Documentation](https://img.shields.io/badge/docs-latest-blue.svg)](https://badgerati.github.io/Pode)
[![GitHub Actions](https://img.shields.io/endpoint.svg?url=https%3A%2F%2Factions-badge.atrox.dev%2Fbadgerati%2Fpode%2Fbadge&style=flat)](https://actions-badge.atrox.dev/badgerati/pode/goto)
[![AppVeyor](https://img.shields.io/appveyor/ci/Badgerati/Pode/develop.svg?label=AppVeyor)](https://ci.appveyor.com/project/Badgerati/pode/branch/develop)
[![Travis CI](https://img.shields.io/travis/Badgerati/Pode/develop.svg?label=Travis%20CI)](https://travis-ci.org/Badgerati/Pode)
[![Code Coverage](https://coveralls.io/repos/github/Badgerati/Pode/badge.svg?branch=develop)](https://coveralls.io/github/Badgerati/Pode?branch=develop)
[![Gitter](https://badges.gitter.im/Badgerati/Pode.svg)](https://gitter.im/Badgerati/Pode?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge)

[![Chocolatey](https://img.shields.io/chocolatey/dt/pode.svg?label=Chocolatey&colorB=a1301c)](https://chocolatey.org/packages/pode)
[![PowerShell](https://img.shields.io/powershellgallery/dt/pode.svg?label=PowerShell&colorB=085298)](https://www.powershellgallery.com/packages/Pode)
[![Docker](https://img.shields.io/docker/pulls/badgerati/pode.svg?label=Docker)](https://hub.docker.com/r/badgerati/pode/)

Pode is a Cross-Platform PowerShell framework for creating web servers to host [REST APIs](https://badgerati.github.io/Pode/Tutorials/Routes/Overview/), [Web Pages](https://badgerati.github.io/Pode/Tutorials/Routes/Examples/WebPages/), and [SMTP/TCP](https://badgerati.github.io/Pode/Tutorials/SmtpServer/) Servers. Pode also allows you to render dynamic files using [`.pode`](https://badgerati.github.io/Pode/Tutorials/Views/Pode/) files, which are just embedded PowerShell, or other [Third-Party](https://badgerati.github.io/Pode/Tutorials/Views/ThirdParty/) template engines. Plus many more features, including [Azure Functions](https://badgerati.github.io/Pode/Tutorials/Serverless/Types/AzureFunctions/) and [AWS Lambda](https://badgerati.github.io/Pode/Tutorials/Serverless/Types/AwsLambda/) support!

<p align="center">
    <img src="https://github.com/Badgerati/Pode/blob/develop/images/example_code_2.png?raw=true" />
</p>

See [here](https://badgerati.github.io/Pode/Getting-Started/FirstApp) for building your first app!

## Documentation

All documentation and tutorials for Pode can be [found here](https://badgerati.github.io/Pode) - this documentation will be for the latest release.

To see the docs for other releases, branches or tags, you can host the documentation locally. To do so you'll need to have the [`Invoke-Build`](https://github.com/nightroman/Invoke-Build) module installed; then:

```powershell
Invoke-Build Docs
```

Then navigate to `http://127.0.0.1:8000` in your browser.

## Features

* Cross-platform using PowerShell Core (with support for PS5)
* Docker support, including images for ARM/Raspberry Pi
* Azure Functions and AWS Lambda support
* Listen on a single or multiple IP address/hostnames
* Support for HTTP, HTTPS, TCP and SMTP
* Host REST APIs, Web Pages, and Static Content (with caching)
* Support for custom error pages
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
* Authentication on requests, such as Basic and Windows Active Directory
* Support for dynamically building Routes from Functions and Modules
* (Windows) Generate/bind self-signed certificates, and signed certificates
* (Windows) Open the hosted server as a desktop application

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

## Contributing

Pull Requests, Bug Reports and Feature Requests are welcome! Feel free to help out with Issues and Projects!

To run the unit tests, run the following command from the root of the repository (this will auto-install Pester for you):

```powershell
Invoke-Build Test
```

To work on issues you can fork Pode, and then open a Pull Request for approval. Pull Requests should be made against the `develop` branch. Each Pull Request should also have an appropriate issue created.
