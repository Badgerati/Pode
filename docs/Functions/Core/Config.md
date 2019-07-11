# Config

## Description

The `config` function returns the loaded contents of the `pode.json` (or `pode.ENV.json`) configuration file.

If no configuration file exists, then an empty hashtable will be returned.

## Examples

### Example 1

The following example load the `pode.json` file, and bind onto the port number (80) in the configuration:

*pode.json*
```json
{
    "port": 80
}
```

*server.ps1*
```powershell
Start-PodeServer {
    $port = (config).port
    Add-PodeEndpoint -Address *:$port -Protocol HTTP
}
```

### Example 2

The following example has a `pode.json` and `pode.dev.json`. When the you set `$env:PODE_ENVIRONMENT = 'dev'`, then Pode will automatically load the `pode.dev.json` file. When using `config` for the port number, the dev one of 8080 will be used:

*pode.json*
```json
{
    "port": 80
}
```

*pode.dev.json*
```json
{
    "port": 8080
}
```

*server.ps1*
```powershell
Start-PodeServer {
    $port = (config).port
    Add-PodeEndpoint -Address *:$port -Protocol HTTP
}
```