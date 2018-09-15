# Installation

Pode is a PowerShell module that can be installed from either Chocolatey, PowerShell Gallery, or Docker. Once installed, you can import the module into your PowerShell scripts.

## Chocolatey

To install Pode via Chocolatey, the following command can be used:

```powershell
choco install pode
```

## PowerShell Gallery

To install Pode from the PowerShell Gallery, you can use the following:

```powershell
Install-Module -Name Pode
```

## Docker

Pode can run on Unix environments, therefore it only makes sense for there to be a Docker container for you to use! The container uses PowerShell Core on an Ubuntu Xenial container. To pull down the Pode container you can do:

```powershell
docker pull badgerati/pode
```

## Using the Module

After you have installed the module, you can then import it into your server scripts:

```powershell
Import-Module Pode
```