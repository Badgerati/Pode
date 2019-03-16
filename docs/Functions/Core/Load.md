# Load

## Description

The `load` function can be used to dot-source other PowerShell scripts into your server. While normal dot-sourcing still works as normal in Pode, this function is used to aid relative paths when running your server as a Service (as relative paths may resolve from where the service is running, and not where the server is running).

## Examples

### Example 1

The following example will run the given PowerShell script, creating any `routes`, etc., that are needed. Because the path is relative, the server's root path will be automatically added:

```powershell
Server {
    load './routes/api.ps1'
}
```

## Parameters

| Name | Type | Required | Description | Default |
| ---- | ---- | -------- | ----------- | ------- |
| Path | string | true | The path to a PowerShell script (`.ps1`) that needs to be dot-sourced | empty |
