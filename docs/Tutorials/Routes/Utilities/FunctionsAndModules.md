# Functions and Modules

Pode has support for converting commands (functions/aliases) into Routes. This could be from an array of defined commands, or by using a Module's exported commands.

To do this, you use the [`ConvertTo-PodeRoute`](../../../../Functions/Routes/ConvertTo-PodeRoute) function. This function also allows you to specify a Path and Middleware for all the Routes generated.

## Commands

You can convert an array of commands into Routes by supplying them to the [`ConvertTo-PodeRoute`](../../../../Functions/Routes/ConvertTo-PodeRoute) function. For example, to convert the `Get-ChildItem` and `Invoke-Expression` functions you can use the following:

```powershell
ConvertTo-PodeRoute -Commands @('Get-ChildItem', 'Invoke-Expression')
```

This will generate two Routes, similar to as if you did the below:

```powershell
Add-PodeRoute -Method Get -Path '/Get-ChildItem' -ScriptBlock {
    $parameters = $WebEvent.Data
    $result = (Get-ChildItem @parameters)
    Write-PodeJsonResponse -Value $result -Depth 1
}

Add-PodeRoute -Method Post -Path '/Invoke-Expression' -ScriptBlock {
    $parameters = $WebEvent.Data
    $result = (Invoke-Expression @parameters)
    Write-PodeJsonResponse -Value $result -Depth 1
}
```

!!! tip
    You can stop the function verbs being used in the Route's path by supplying the `-NoVerb` switch.

## Modules

If you have a Module whose exported commands you want to convert into Routes, then you can supply the Module's name to [`ConvertTo-PodeRoute`](../../../../Functions/Routes/ConvertTo-PodeRoute).

Supplying a Module will cause it to be automatically imported using [`Import-PodeModule`](../../../../Functions/Utilities/Import-PodeModule). This means the Module can be referenced by name, or by path, and it supports modules within the `ps_modules` directory.

For example, if you wanted to import all commands from Pester you could do the following:

```powershell
ConvertTo-PodeRoute -Module Pester
```

Or, you can convert specific commands from Pester:

```powershell
ConvertTo-PodeRoute -Module Pester -Commands @('Invoke-Pester')
```

## Route Path

The Routes created will all have automatically generated paths. There are 3 components to the path:

1. The first is if you supplied a path via `-Path`.
2. The second is if you're using a Module.
3. The final part is the name of the Command itself.

In general, the path will look as follows: `/<path>/<module>/<command>`

## HTTP Methods

The Routes created will also have an automatic HTTP method assigned. This method is determined by the verb of the command; if it's `Get-ChildItem` then it's a GET route, or if it's `Invoke-Expression` then it's a POST route.

If you want to use one HTTP method for everything, then you can supply the `-Method` parameter on [`ConvertTo-PodeRoute`](../../../../Functions/Routes/ConvertTo-PodeRoute).

The table below defines how verbs are mapped.

| Method | Verbs |
| ------ | ----- |
| POST | Default - All other verbs |
| GET | Find, Format, Get, Join, Search, Select, Split, Measure, Ping, Test, Trace |
| PUT | Set |
| PATCH | Rename, Edit, Update |
| DELETE | Clear, Close, Exit, Hide, Remove, Undo, Dismount, Unpublish, Disable, Uninstall, Unregister |
