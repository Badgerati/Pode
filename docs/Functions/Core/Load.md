# Load

## Description

The `load` function can be used to dot-source other PowerShell scripts into your server. While normal dot-sourcing still works as normal in Pode, this function is used to aid relative paths when running your server as a Service or a Module (as relative paths may resolve from where the service/module is running, and not where the Pode server is running).

You can also use the `load` function to dot-source multiple scripts by using wildcard paths. If you supply a directory path, then by default Pode will attempt to load all `*.ps1` files.

## Examples

### Example 1

The following example will run the given PowerShell script, creating any `routes`, etc., that are needed. Because the path is relative, the server's root path will be automatically added:

```powershell
server {
    load './routes/api.ps1'
}
```

### Example 2

The following example will dot-source all `*.ps1` scripts at the passed directory path:

```powershell
server {
    load './routes/*.ps1'
}
```

## Parameters

| Name | Type | Required | Description | Default |
| ---- | ---- | -------- | ----------- | ------- |
| Path | string | true | The path to a PowerShell script (`.ps1`), or a directory with many scripts, that need to be dot-sourced | empty |
