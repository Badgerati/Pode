# Import

## Description

The `import` function lets you declare paths to PowerShell Modules (`.psm1`/`.psd1`) that need to be imported into each runspace - you can also specify the name of a module you already have installed. Because Pode runs most things in isolated runspaces, importing and using external modules in Pode can be quite bothersome, with `import` Pode will handle importing your modules into all runspaces for you.

If a module name is used rather than a raw path, then Pode will check you're server's [`ps_modules`](../../../Getting-Started/LocalModules) directory first, and then check your globally installed modules.

## Examples

### Example 1

The following example will import the specified module file into each of the runspaces that Pode creates. This way you'll be able to use each of the functions declared within  the module in `routes`, `timers`, `schedules`, `loggers`, `handlers`, etc. (basically, everything):

```powershell
Server {
    import './path/to/module.psm1'
}
```

### Example 2

The following example will import the `EPS` module, for views, into each of the runspaces:

```powershell
Server {
    import eps
}
```

## Parameters

| Name | Type | Required | Description | Default |
| ---- | ---- | -------- | ----------- | ------- |
| Path | string | true | The path to a PowerShell Module (`.psm1`/`.psd1`), or the name of an installed mode, that should be imported into the runspaces | empty |
| Now | switch | false | If true, the module will be imported immediately into the current scope | false |
