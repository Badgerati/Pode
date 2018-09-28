# Welcome

Pode is a Cross-Platform PowerShell framework that allows you to host REST APIs, Web Pages and SMTP/TCP servers. It also allows you to render dynamic files using `.pode` files, which is effectively embedded PowerShell, or other Third-Party template engines. Pode also has support for middleware, sessions, and authentication; as well as access and rate limiting features.

[![MIT licensed](https://img.shields.io/badge/license-MIT-blue.svg)](https://raw.githubusercontent.com/Badgerati/Pode/master/LICENSE.txt)
[![AppVeyor](https://img.shields.io/appveyor/ci/Badgerati/Pode/develop.svg?label=AppVeyor)](https://ci.appveyor.com/project/Badgerati/pode/branch/develop)
[![Travis CI](https://img.shields.io/travis/Badgerati/Pode/travidevelops.svg?label=Travis%20CI)](https://travis-ci.org/Badgerati/Pode)
[![Gitter](https://badges.gitter.im/Badgerati/Pode.svg)](https://gitter.im/Badgerati/Pode?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge)

[![Chocolatey](https://img.shields.io/chocolatey/dt/pode.svg?label=Chocolatey&colorB=a1301c)](https://chocolatey.org/packages/pode)
[![PowerShell](https://img.shields.io/powershellgallery/dt/pode.svg?label=PowerShell&colorB=085298)](https://www.powershellgallery.com/packages/Pode)
[![Docker](https://img.shields.io/docker/pulls/badgerati/pode.svg?label=Docker)](https://hub.docker.com/r/badgerati/pode/)

## Features

* Can run on *nix environments using PowerShell Core
* Host REST APIs and Web Pages
* Host TCP and SMTP server - great for tests and mocking
* Multiple threads can be used to response to incoming requests
* Use the full power of PowerShell, want a REST API for NUnit? Go for it!
* Ability to write dynamic files in PowerShell using Pode, or other third-party template engines
* Can use yarn package manager to install bootstrap, or other frontend libraries
* Setup async timers to be used as one off tasks, or for housekeeping services
* Ability to schedule async tasks using cron expressions
* Supports logging to CLI, Files, and custom loggers to other services like LogStash, etc.
* Cross-state runspace variable access for timers, routes and loggers
* Optional file monitoring to trigger internal server restart on file changes
* Ability to allow/deny requests from certain IP addresses and subnets
* Basic rate limiting for IP addresses and subnets
* Support for generating/binding self-signed certificates, and signed certificates on Windows
* Support for middleware on web servers
* Session middleware support on web requests
* Can use authentication on requests, which can either be sessionless or session persistant