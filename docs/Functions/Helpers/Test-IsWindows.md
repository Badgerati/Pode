# Test-IsWindows

## Description

The `Test-IsWindows` function will return `$true` if Pode is running on a Windows environment, `$false` otherwise.

## Examples

### Example 1

The following example will return whether the current environment is Windows:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Endpoint *:8080 -Protocol HTTP

    route get '/env' {
        Write-PodeJsonResponse -Value @{ 'Windows' = (Test-IsWindows) }
    }
}
```

## Parameters

None.
