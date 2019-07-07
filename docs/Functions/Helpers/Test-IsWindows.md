# Test-IsWindows

## Description

The `Test-IsWindows` function will return `$true` if Pode is running on a Windows environment, `$false` otherwise.

## Examples

### Example 1

The following example will return whether the current environment is Windows:

```powershell
Server {
    listen *:8080 http

    route get '/env' {
        Write-PodeJsonResponse -Value @{ 'Windows' = (Test-IsWindows) }
    }
}
```

## Parameters

None.
