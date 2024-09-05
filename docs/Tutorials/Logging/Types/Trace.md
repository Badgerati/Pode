
# Main Logging

Pode supports logging for any public function invocation and some important non-error messages using the inbuilt Main logging method. This method enables comprehensive logging for various operations within Pode ensuring that important actions and messages are captured.

## Enabling

To enable and use the Main logging you use the `Enable-PodeTraceLogging` function supplying a logging method from `New-PodeLoggingMethod`.

## Examples

### Log to Syslog

The following example enables Main logging and will output all items to a Syslog server:

```powershell
$method = New-PodeLoggingMethod -Syslog -Server '127.0.0.1' -Transport 'UDP'
$method | Enable-PodeTraceLogging
```

### Using Raw Data

The following example uses a Custom logging method and sets Main logging to include raw log data in the logging output. The Custom method logs the raw data to the terminal:

```powershell
$method = New-PodeLoggingMethod -Custom -ScriptBlock {
    param($item)
    "$($item | ConvertTo-Json -Depth 10)" | Out-Default
}

$method | Enable-PodeTraceLogging -Raw
```

## Raw Main Log Data

The raw log data hashtable that will be supplied to any Custom logging methods will look as follows:

```powershell
@{
  'Server'     = 'pode-dev'
  'Message'    = 'Operation Add-PodeRoute invoked with parameters= ScriptBlock=<ScriptBlock> Method=Get Path=/'
  'ThreadId'   = 21
  'Operation'  = 'Add-PodeRoute'
  'Level'      = 'Info'
  'Date'       = '2024-06-18T21=31=36.4636345Z'
  'Parameters' = @{
    'ScriptBlock' = @{
      'Attributes'      = ''
      'File'            = 'C=\\Users\\pode\\Documents\\GitHub\\Pode\\examples\\logging.ps1'
      'IsFilter'        = $false
      'IsConfiguration' = $false
      'Module'          = $null
      'StartPosition'   = 'System.Management.Automation.PSToken'
      'DebuggerHidden'  = $false
      'Id'              = '0de89f0a-4df2-4160-a605-97fd90c2ae2e'
      'Ast'             = "{\r\n        Write-PodeLog -Name  'mylog' -Message 'Something' -Level 'Info'\r\n  }"
    }
    'Method'      = @('Get')
    'Path'        = '/'
  }
  'Tag'        = 'Main'
}
```
