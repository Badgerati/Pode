# Installation

Pode is a PowerShell module that can be installed from either Chocolatey, the PowerShell Gallery, or Docker. Once installed, you can use the module in your PowerShell scripts.

## Minimum Requirements

Before installing Pode, the minimum requirements must be met:

* OS:
    * Windows
    * Linux
    * MacOS
    * Raspberry Pi
* PowerShell:
    * Windows PowerShell 5+
    * PowerShell (Core) 6+
* .NET Framework 4.7.2+ (For Windows PowerShell)

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

Pode can run on *nix environments, therefore it only makes sense for there to be Docker images for you to use! The images use PowerShell v7.1.1 on either an Ubuntu Bionic image (default), or an ARM32 image (for Raspberry Pis).

* To pull down the latest Pode image you can do:

```powershell
# for latest
docker pull badgerati/pode:latest

# or the following for a specific version:
docker pull badgerati/pode:2.1.0
```

* To pull down the ARM32 Pode image you can do:

```powershell
# for latest
docker pull badgerati/pode:latest-arm32

# or the following for a specific version:
docker pull badgerati/pode:2.1.0-arm32
```

Once pulled, you can [view here](../Docker) on how to use the image.

## GitHub Package Registry

You can also get the Pode docker image from the GitHub Package Registry! The images are the same as the ones hosted in Docker.

* To pull down the latest Pode image you can do:

```powershell
# for latest
docker pull docker.pkg.github.com/badgerati/pode/pode:latest

# or the following for a specific version:
docker pull docker.pkg.github.com/badgerati/pode/pode:2.1.0
```

* To pull down the ARM32 Pode image you can do:

```powershell
# for latest
docker pull docker.pkg.github.com/badgerati/pode/pode:latest-arm32

# or the following for a specific version:
docker pull docker.pkg.github.com/badgerati/pode/pode:2.1.0-arm32
```

Once pulled, you can [view here](../Docker) on how to use the image.

## Using the Module

After you have installed the module all functions should be readily available to you. In the case of the Docker images, the module is pre-installed for you.

If you have any issues then you can try and import the module into your server scripts:

```powershell
Import-Module Pode
```
