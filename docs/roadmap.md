# Roadmap

This page lists the planned features and enhancements that will, hopefully, one day make it into Pode. There is no timeframe on when to expect them, some could be in-progress right now, and others in the future.

Where possible items listed here will have a link to any relevant issues in GitHub.

There is also a [Project Board](https://github.com/users/Badgerati/projects/2) in the beginnings of being setup for Pode, with milestone progression and current roadmap issues and ideas. If you see any draft issues you wish to discuss, or have an idea for one, please dicuss it over on [Discord](https://discord.gg/fRqeGcbF6h) in the `#ideas` or `#pode` channel.

## 🎯 Goal

Pode at its heart, is mostly a web server, but overtime I've started to setup Pode to be much more: including the likes of Web Sockets, SMTP, and TCP servers. Below you'll even see on the roadmap is FTP.

The eventual goal is to have Pode be a central PowerShell module for a number of different server types, even allowing you to host different types together and use them in combination - an FTP server with a web frontend for instance! This will be fleshed out more in Pode 3.0 - which plans for this have started!

## 🚢 Releases

Under normal circumstanes Pode releases approximately once every 2 months, where the following month is usually a Pode.Web release.

Sometimes there could be more, if patch releases are needed. But sometimes there could be fewer if peronsal time constraints prevent releases.

## 📃 Plan

### Features

- [ ] NTLM and/or Kerberos authentication - likely it's own module [#402](https://github.com/Badgerati/Pode/issues/402)
- [ ] More logging provider support - such as Azure, AWS, and Splunk. These could be baked into Pode or be standalone modules
- [ ] Better support for a more "serverless" Pode feel via Docker, such as auto-loading routes from a folder
- [ ] Starting Pode as a background job from CLI, instead of blocking [#553](https://github.com/Badgerati/Pode/issues/553)
- [ ] gRPC support
- [ ] HTTP/2.0 support
- [ ] HTTP/3.0 support
- [ ] Inbuilt authorization support, on top the current authentications support [#992](https://github.com/Badgerati/Pode/issues/992)
- [ ] Secret management support [#980](https://github.com/Badgerati/Pode/issues/980)
- [ ] Some way of being able to merge authentication types [588](https://github.com/Badgerati/Pode/issues/588)
- [ ] Improved garbage collection in runspaces, to help free up memory
- [ ] A Session Pool that can be used to port/re-use PSSessions in Pode more easily
- [ ] Further improvements to OIDC, such as HMAC and refresh token support
- [ ] Implement an inbuilt FTP(S) server
- [ ] Is it possible to implement an inbuilt SFTP server?
- [ ] Inbuilt connectors for connecting to message brokers, like Kafka, RabbitMQ, etc.
- [ ] Would is be possible to create an inbuilt pub/sub server?
- [ ] An inbuilt FIM server, so we can fun logic on FIM events

### Misc

- [ ] Performance testing on PRs, and metrics in the documentation
- [ ] Further security testing, like DAST testing
- [ ] Is it possible to plug Pode into an APM, like Datadog?
- [ ] Blog posts and video tutorials

## ⏩ Future

Here and there notes get added to for ideas on Pode 3.0. With Pode supporting more server types, some functions like `Add-PodeRoute` might get renamed to `Add-PodeWebRoute` - to better indicate its usage, much like `Add-PodeSignalRoute`.

Other ideas include:

### Syntax Rewrite

For the longest time you've always had to place your logic into `Start-PodeServer`. This is just a thought/proposal, but one idea could be to make the syntax more PowerShell-y, something like:

```powershell
$pode = New-PodeServer

$pode | Add-PodeEndpoint -Address 127.0.0.1 -Port 8080 -Protocol Http

$basic = New-PodeAuthScheme -Basic
$pode | Add-PodeAuth -Name 'SomeAuth' -Scheme $basic -ScriptBlock {
    return @{ User = @{} }
}

$pode | Add-PodeRoute -Method Get -Path '/' -Authentication SomeAuth -ScriptBlock {
    Write-PodeJsonResponse -Value @{ Message = 'Hello' }
}

$pode | Start-PodeServer -Threads 2
```

Potentially have `New-PodeServer` set a global variable instead, to prevent all of the `$pode` piping. But allow `-PassThru` and the piping to support multiple servers being created.

