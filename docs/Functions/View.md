# View

## Description

The `view` function allows you to render any of the view files that you place within the `/views` directory. When you call `view`, Pode will automatically look within this directory.

Pode uses a View Engine to either render HTML, Pode, or other types. Default is HTML, and you can change it to Pode by using the [`engine`](Engine.md) function.

## Examples

1. The following example will render the `index.html` view when you navigate to `http://localhost:8080`:

    ```powershell
    Server {
        listen *:8080 http

        route get '/' {
            view 'index'
        }
    }
    ```

2. The following example will render the `index.pode` view when you navigate to `http://localhost:8080`:

    ```powershell
    Server {
        listen *:8080 http
        engine pode

        route get '/' {
            view 'index'
        }
    }
    ```

3. The following example will render the `index.pode` view when you navigate to `http://localhost:8080`, it will also supply dynamic data - in this case, the current date:

    > The dynamic data can be used in your pode view via `$($data.date)`

    ```powershell
    Server {
        listen *:8080 http
        engine pode

        route get '/' {
            view 'index' -d @{ 'date' = [DateTime]::Now }
        }
    }
    ```

## Parameters

| Name | Type | Required | Description | Default |
| ---- | ---- | -------- | ----------- | ------- |
| Path | string | true | The path to the view to render, relative to your `/views` directory | null |
| data | hashtable | false | A hashtable of dynamic data that will be supplied to `.pode`, and other third-party template engines | `@{}` |
