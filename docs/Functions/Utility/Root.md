# Root

## Description

The `root` function returns the parent path to your server script.


!!! tip
    Useful when loading local files when running Pode as a service, and the working directory is shifted to where the PowerShell executable is located.

## Examples

### Example 1

The following example will import the local module, located within the `/modules` directory:

```powershell
Start-PodeServer {
    Import-PodeModule -Path "$(Get-PodeServerPath)/modules/tools.psm1"
}
```
