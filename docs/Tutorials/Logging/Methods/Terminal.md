# Terminal

You can log items to the terminal using Pode's inbuilt terminal Method, via [`New-PodeLogTerminalMethod`](../../../../Functions/Logging/New-PodeLogTerminalMethod).

!!! note
    This will convert the supplied transformed log items into a string, if it isn't one already.

!!! important
    The `New-PodeLoggingMethod` function is now deprecated, please use [`New-PodeLogTerminalMethod`](../../../../Functions/Logging/New-PodeLogTerminalMethod) instead.

## Override

You can use [`New-PodeLogTerminalOverride`](../../../../Functions/Logging/New-PodeLogTerminalOverride) to override certain properties of the Terminal Log Method, when calling either [`Write-PodeErrorLog`](../../../../Functions/Logging/Write-PodeErrorLog) or [`Write-PodeLog`](../../../../Functions/Logging/Write-PodeLog).

The only option available for Terminal is `-Ignore`, which allows you to specify that certain log items will not be logged via the Terminal.

If you don't specify an `-Id` then the override will apply to all Terminal Log Methods configured for a Log Type.

```powershell
# if you have an error log method configured with file and terminal logging,
# the below will only log the error to file and ignore the terminal
$_ | Write-PodeErrorLog -Override @(
    New-PodeLogTerminalOverride -Ignore
)
```

## Examples

### Basic

The following example will setup the terminal Log Method for logging Requests:

```powershell
New-PodeLogTerminalMethod | Enable-PodeLogRequestType
```
