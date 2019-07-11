# Test-IsUnix

## Description

The `Test-IsUnix` function will return `$true` if Pode is running on a *nix environment, `$false` otherwise.

## Examples

### Example 1

The following example will return whether the current environment is *nix:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address *:8080 -Protocol HTTP

    route get '/env' {
        Write-PodeJsonResponse -Value @{ 'Unix' = (Test-IsUnix) }
    }
}
```

## Parameters

None.
