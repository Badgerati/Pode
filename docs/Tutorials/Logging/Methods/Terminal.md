# Logging to Terminal

You can log items to the terminal using Pode's inbuilt terminal logic. The inbuilt logic will convert any item to a string, and output it to the terminal.


## Examples

### Basic

The following example will setup the terminal logging method for logging Requests:

```powershell
New-PodeLoggingMethod -Terminal | Enable-PodeRequestLogging
```
