# View

## Description

The `view` function allows you to render view files that are placed within the `/views` directory at the root of your server. When you call `view`, Pode will automatically look within this directory for files.

Pode uses a View Engine to render either HTML, Pode, or other file types. Default is HTML, and you can change it to Pode, or other third-party engines, by using the [`engine`](../../Core/Engine) function.

## Examples

### Example 1

The following example will render the `index.html` view when you navigate to `http://localhost:8080`:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Endpoint *:8080 -Protocol HTTP

    route get '/' {
        view 'index'
    }
}
```

### Example 2

The following example will render the `index.pode` view when you navigate to `http://localhost:8080`:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Endpoint *:8080 -Protocol HTTP
    Set-PodeViewEngine -Type Pode

    route get '/' {
        view 'index'
    }
}
```

### Example 3

The following example will render the `index.pode` view when you navigate to `http://localhost:8080`, it will also supply dynamic data - in this case, the current date:

> The dynamic data can be used in your pode view via `$($data.date)`

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Endpoint *:8080 -Protocol HTTP
    Set-PodeViewEngine -Type Pode

    route get '/' {
        view 'index' -d @{ 'date' = [DateTime]::Now }
    }
}
```

## Parameters

| Name | Type | Required | Description | Default |
| ---- | ---- | -------- | ----------- | ------- |
| Path | string | true | The path to the view to render, relative to your `/views` directory | null |
| Data | hashtable | false | A hashtable of dynamic data that will be supplied to `.pode`, and other third-party template engine, view files | `@{}` |
| FlashMessages | switch | false | If true, will load all flash messages from the current session into the dynamic view's data as `$data.flash` | false |
