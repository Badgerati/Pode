# Engine

## Description

The `engine` function allows you to specify the engine used to render `view` and content templates. You can also specify a third-party engine to use, such as [EPS](https://github.com/straightdave/eps).

> If you don't use the `engine` function, then the defaut of HTML will be used

## Examples

1. The following example will render views and content using the Pode template engine (such as the `index.pode` view or the `style.css.pode` public content file):

    ```powershell
    Server {
        engine pode
    }
    ```

2. The following example will use the third-party engine `EPS` to render views (such as the `index.eps` view or the `style.css.eps` public content file):

    ```powershell
    Server {
        engine eps {
            param($path, $data)
            return Invoke-EpsTemplate -Path $path -Binding $data
        }
    }
    ```

## Parameters

| Name | Type | Required | Description | Default |
| ---- | ---- | -------- | ----------- | ------- |
| Engine | string | true | The type of engine to use, can be either HTML, Pode, or a custom third-party type - the value passed should be the extension used by the engine | HTML |
| ScriptBlock | scriptblock | false | When using a third-party template engine, the ScriptBlock is required as it tells Pode how to render views/static content using the engine | null |
