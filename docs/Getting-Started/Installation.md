# Installation

Pode is a PowerShell module that can be installed from either Chocolatey, PowerShell Gallery, or Docker. Once installed, you can import the module into your PowerShell scripts.

## Chocolatey

[![Chocolatey](https://img.shields.io/chocolatey/dt/pode.svg?label=Downloads&colorB=a1301c)](https://chocolatey.org/packages/pode)

To install Pode via Chocolatey, the following command can be used:

```powershell
choco install pode
```

## PowerShell Gallery

[![PowerShell](https://img.shields.io/powershellgallery/dt/pode.svg?label=Downloads&colorB=085298)](https://www.powershellgallery.com/packages/Pode)

To install Pode from the PowerShell Gallery, you can use the following:

```powershell
Install-Module -Name Pode
```

## Docker

[![Docker](https://img.shields.io/docker/stars/badgerati/pode.svg?label=Stars)](https://hub.docker.com/r/badgerati/pode/)
[![Docker](https://img.shields.io/docker/pulls/badgerati/pode.svg?label=Pulls)](https://hub.docker.com/r/badgerati/pode/)

Pode can run on *nix environments, therefore it only makes sense for there to be a Docker container for you to use! The container uses PowerShell Core on an Ubuntu Xenial container. To pull down the Pode container you can do:

```powershell
docker pull badgerati/pode
```

## Using the Module

After you have installed the module, you can then import it into your server scripts:

```powershell
Import-Module Pode
```