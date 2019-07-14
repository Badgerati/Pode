# Test-IsWindows

## Description

The `Test-IsWindows` function will return `$true` if Pode is running on a Windows environment, `$false` otherwise.

## Examples

### Example 1

The following example will return whether the current environment is Windows:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address *:8080 -Protocol Http

    Add-PodeRoute -Method Get -Path '/env' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ 'Windows' = (Test-IsWindows) }
    }
}
```

## Parameters

None.
