# Pode

[![MIT licensed](https://img.shields.io/badge/license-MIT-blue.svg)](https://raw.githubusercontent.com/Badgerati/Pode/master/LICENSE.txt)
[![Documentation](https://img.shields.io/badge/docs-latest-blue.svg)](https://badgerati.github.io/Pode)
[![AppVeyor](https://img.shields.io/appveyor/ci/Badgerati/Pode/develop.svg?label=AppVeyor)](https://ci.appveyor.com/project/Badgerati/pode/branch/develop)
[![Travis CI](https://img.shields.io/travis/Badgerati/Pode/develop.svg?label=Travis%20CI)](https://travis-ci.org/Badgerati/Pode)
[![Gitter](https://badges.gitter.im/Badgerati/Pode.svg)](https://gitter.im/Badgerati/Pode?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge)

[![Chocolatey](https://img.shields.io/chocolatey/dt/pode.svg?label=Chocolatey&colorB=a1301c)](https://chocolatey.org/packages/pode)
[![PowerShell](https://img.shields.io/powershellgallery/dt/pode.svg?label=PowerShell&colorB=085298)](https://www.powershellgallery.com/packages/Pode)
[![Docker](https://img.shields.io/docker/pulls/badgerati/pode.svg?label=Docker)](https://hub.docker.com/r/badgerati/pode/)

Pode is a Cross-Platform PowerShell framework that allows you to host [REST APIs](#rest-api), [Web Pages](#web-pages) and [SMTP/TCP](#smtp-server) servers. It also allows you to render dynamic files using [Pode](#pode-files) files, which is effectively embedded PowerShell, or other [Third-Party](#third-party-view-engines) template engines.

## Documentation

All documentation and tutorials for Pode can be [found here](https://badgerati.github.io/Pode) - this documentation will be for the latest release.

To see the docs for other releases, branches or tags, you can host the documentation locally. To do so you'll need to have the [`Invoke-Build`](https://github.com/nightroman/Invoke-Build) module installed; then:

```powershell
Invoke-Build Docs
```

Then navigate to `http://127.0.0.1:8000` in your browser.

## Features

* Can run on *nix environments using PowerShell Core
* Host REST APIs, Web Pages, TCP and SMTP server
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

## Build Your First App

See [here](https://badgerati.github.io/Pode/Getting-Started/FirstApp) for building your first app!
