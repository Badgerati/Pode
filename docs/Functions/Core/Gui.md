# Gui

!!! warning
    Currently only supported on Windows due to using WPF.

## Description

The `gui` function allows you to run a server and have it automatically open as a desktop application. In reality it's just a WPF application with a WebBrowser control, and the server running in the background.

If you run your server directly, then the terminal will remain visible. However, you could have a script which opens PowerShell as hidden and launches the server.

!!! tip
    You can use the `gui` and listen on any endpoint, however it's recommended to `listen` on localhost - that way you don't need to run the application with elevated permissions.

## Examples

### Example 1

The following example will launch the server, and open an application called "Pode Example 1". It will also set the icon of the application:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address localhost:8080 -Protocol Http

    gui 'Pode Example 1' @{
        Icon = '../images/icon.png'
    }
}
```

### Example 2

The following example will launch the server, but will open the application as fullscreen:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address localhost:8080 -Protocol Http

    gui 'Pode Example 2' @{
        State = 'Maximized'
    }
}
```

### Example 3

The following example will launch the server, and the application's window will open at a defined fixed size:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address localhost:8080 -Protocol Http

    gui 'Pode Example 2' @{
        ResizeMode = 'NoResize'
        Width = 1200
        Height = 700
    }
}
```

## Parameters

!!! note
    The `gui` function takes 2 parameters; the first is a mandatory `name` for the window, the second is a `hashtable`. The below options are the expected keys that could be in that `hashtable`

| Name | Type | Required | Description | Default |
| ---- | ---- | -------- | ----------- | ------- |
| Icon | string | false | A path to an icon/image file that will be used for the application | null |
| ShowInTaskbar | bool | false | Defines whether or not the application should appear in the taskbar |  true |
| State | string | false | The state of the application when it opens. (Values: Normal, Maximized, Minimized) | Normal |
| WindowStyle | string | false | The border style of the application when it opens. (Values: None, SingleBorderWindow, ThreeDBorderWindow, ToolWindow) | SingleBorderWindow |
| Width | int | false | The width of the application's window | auto |
| Height | int | false | The height of the application's window | auto |
| ResizeMode | string | false | Defines whether or not the application's window can be resized. (Values: CanResize, CanMinimize, NoResize) | CanResize |
| ListenName | string | false | The name of a [`listen`](../Listen) endpoint to use - useful if you have multiple endpoints defined | empty |
