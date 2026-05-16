# Terminal

You can log items to the terminal using Pode's inbuilt terminal Method, via [`New-PodeLogTerminalMethod`](../../../../Functions/Logging/New-PodeLogTerminalMethod).

!!! note
    This will convert the supplied transformed log items into a string, if it isn't one already.

## Examples

### Basic

The following example will setup the terminal logging Method for logging Requests:

```powershell
New-PodeLogTerminalMethod | Enable-PodeRequestLogging
```
