# Gui

!!! warning
    Currently only supported on Windows due to using WPF. (Though it appears WPF could soon be supported on .NET Core 3)

## Description

The `gui` function allows you to run a server and have it automatically open as a desktop application. In reality it's just a WPF application with a WebBrowser control, and the server running in the background.

If you run your server directly, then the terminal will remain visible. However, you could have a script which opens PowerShell as hidden and launches the server.

!!! tip
    You can use the `gui` and listen on any endpoint however, it's recommended to `listen` on the localhost - that way you don't need to run the application with elevated permissions.

## Examples

### Example 1

The following example will launch the server, and open a application called "Pode Example 1". It will also set the icon of the application:

```powershell
Server {
    gui 'Pode Example 1' @{
        'Icon' = '../images/icon.png'
    }

    listen localhost:8080 http
}
```

### Example 2

The following example will launch the server, but will open the application as fullscreen:

```powershell
Server {
    gui 'Pode Example 2' @{
        'State' = 'Maximized'
    }

    listen localhost:8080 http
}
```

## Parameters

!!! note
    The `gui` function takes 2 parameters; the first is a mandatory `name` for the window, the second is a `hashtable`. The below parameters are the expected keys that could be in that `hashtable`

| Name | Type | Required | Description | Default |
| ---- | ---- | -------- | ----------- | ------- |
| Icon | string | false | A path to an icon/image file that will be used for the application | null |
| ShowInTaskbar | bool | false | Defines whether or not the application should appear in the taskbar |  true |
| State | string | false | The state of the application when it opens. (Values: Normal, Maximized, Minimized) | Normal |
| WindowStyle | string | false | The border style of the application when it opens. (Values: None, SingleBorderWindow, ThreeDBorderWindow, ToolWindow) | SingleBorderWindow |
| ListenName | string | false | The name of a [`listen`](../Listen) endpoint to use - useful if you have multiple endpoints defined | empty |