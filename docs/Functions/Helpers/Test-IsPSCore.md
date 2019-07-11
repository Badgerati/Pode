# Test-IsPSCore

## Description

The `Test-IsPSCore` function will return `$true` if Pode is running using PowerShell Core (v6.0+), `$false` otherwise.

## Examples

### Example 1

The following example will return whether Pode is running on PowerShell Core:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address *:8080 -Protocol HTTP

    route get '/env' {
        Write-PodeJsonResponse -Value @{ 'PSCore' = (Test-IsPSCore) }
    }
}
```

## Parameters

None.
