# Simple Pages

Pode has support for generating simple GET Routes from Files, Views and ScriptBlocks.

To do this, you use the [`Add-PodePage`](../../../../Functions/Routes/Add-PodePage) function, which will automatically generate a GET Route for you. Any content to be returned will be done so as HTML.

## ScriptBlocks

You can create a simple Page using a ScriptBlock. The generated route will invoke the ScriptBlock and return any result back as HTML.

This following example generates a `GET /Services` route:

```powershell
Add-PodePage -Name 'Services' -ScriptBlock { Get-Service }
```

This would be the same as if you did the below:

```powershell
Add-PodeRoute -Method Get -Path '/Services' -ScriptBlock {
    Write-PodeHtmlResponse -Value (Get-Service)
}
```

## Files

You can create a simple Page using a file, the path of which can be literal or relative to the server. The generated route will call [`Write-PodeFileResponse`](../../../../Functions/Responses/Write-PodeFileResponse) using the file and return the content back as HTML.

This following example generates a `GET /About` route:

```powershell
Add-PodePage -Name 'About' -FilePath './views/about.html'
```

This would be the same as if you did the below:

```powershell
Add-PodeRoute -Method Get -Path '/About' -ScriptBlock {
    Write-PodeFileResponse -Path './views/about.html' -ContentType 'text/html'
}
```

!!! tip
    The file doesn't have to be static HTML, you can also use `.pode` files or other template engine files!

## Views

You can create a simple Page using a View from within the server's `/views` directory.

This following example generates a `GET /Index` route:

```powershell
Add-PodePage -Name 'Index' -View 'index'
```

This would be the same as if you did the below:

```powershell
Add-PodeRoute -Method Get -Path '/Index' -ScriptBlock {
    Write-PodeViewResponse -Path 'index'
}
```

!!! tip
    The file doesn't have to be static HTML, you can also use `.pode` files or other template engine files!

## Route Path

The Routes created will all have automatically generated paths. There are 2 components to the path:

1. The first is if you supplied a path via `-Path`.
2. The second is the `-Name` parameter.

In general, the path will look as follows: `/<path>/<name>`
