# Test-IsPSCore

## Description

The `Test-IsPSCore` function will return `$true` if Pode is running using PowerShell Core (v6.0+), `$false` otherwise.

## Examples

### Example 1

The following example will return whether Pode is running on PowerShell Core:

```powershell
Server {
    listen *:8080 http

    route get '/env' {
        json @{ 'PSCore' = (Test-IsPSCore) }
    }
}
```

## Parameters

None.
