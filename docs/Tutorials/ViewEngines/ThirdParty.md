# Third Party Engines

Pode supports the use of third-party view engines, for example you could use the [EPS](https://github.com/straightdave/eps) template engine. To do this, you'll need to supply a custom scriptblock to the [`engine`](../../../Functions/Core/Engine) function which tells Pode how use the third-party engine. The scriptblock will be supplied with two arguments:

1. `$path`: The path to the view/public file that needs generating
2. `$data`: Any data that was supplied to the `view` function

If you did use `EPS` and already have the module installed, then the following example would work:

```powershell
Server {
    listen *:8080 http

    # import the EPS module into the runspaces
    import eps

    # set the engine to use and render EPS files
    # (could be index.eps, or for content scripts.css.eps)
    engine eps {
        param($path, $data)

        if ($null -eq $data) {
            return (Invoke-EpsTemplate -Path $path)
        }
        else {
            return (Invoke-EpsTemplate -Path $path -Binding $data)
        }
    }

    # render the index.eps view
    route get '/' {
        view 'index'
    }
}
```