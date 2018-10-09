# Test-IsUnix

## Description

The `Test-IsUnix` function will return `$true` if Pode is running on a *nix environment, `$false` otherwise.

## Examples

### Example 1

The following example will return whether the current environment is *nix:

```powershell
Server {
    listen *:8080 http

    route get '/env' {
        json @{ 'Unix' = (Test-IsUnix) }
    }
}
```

## Parameters

None.
