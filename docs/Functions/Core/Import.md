# Import

## Description

The `import` function lets you declare names/paths to PowerShell modules/scripts (`.psm1`/`.psd1`/`.ps1`) that need to be imported into each runspace - you can also specify just the name of a specific module you already have installed. Because Pode runs most things in isolated runspaces, importing and using external modules in Pode can be quite bothersome, with `import` Pode will handle importing your modules into all runspaces for you.

If a module name is used rather than a raw path, then Pode will check your server's [`ps_modules`](../../../Getting-Started/LocalModules) directory first, and then check your globally installed modules.

Using the `-SnapIn` flag, Pode will treat the name supplied to `import` as a snap-in rather than a module - this is only supported on Windows PowerShell.

You can also use the `import` function to import multiple modules/scripts into runspaces by using wildcard paths. If you supply a directory path, then by default Pode will attempt to import all `*.ps*1` files (so typically: `.psm1`/`.psd1`/`.ps1`).

## Examples

### Example 1

The following example will import the specified module file into each of the runspaces that Pode creates. This way you'll be able to use each of the functions declared within  the module in `routes`, `timers`, `schedules`, `loggers`, `handlers`, etc. (basically, everything):

```powershell
server {
    import './path/to/module.psm1'
}
```

### Example 2

The following example will import the `EPS` module, for views, into each of the runspaces:

```powershell
server {
    import eps
}
```

### Example 3

The following example will import the `WDeploySnapin3.0` snap-in into each of the runspaces:

```powershell
server {
    import -snapin 'WDeploySnapin3.0'
}
```

### Example 4

The following example will import a script into each of the runspaces:

```powershell
server {
    import './path/to/script.ps1'
}
```

### Example 5

The following example will import all modules (`*.psm1`) at the supplied path into each of the runspaces:

```powershell
server {
    import './path/*.psm1'
}
```

## Parameters

| Name | Type | Required | Description | Default |
| ---- | ---- | -------- | ----------- | ------- |
| Path | string | true | The path to a PowerShell module/script (`.psm1`/`.psd1`/`.ps1`), or the name of an installed mode, that should be imported into the runspaces. You can also supply a directory path to import multiple modules/scripts | empty |
| Now | switch | false | If true, the module/script will be imported immediately into the current scope | false |
| SnapIn | switch | false | If true, Pode will treat the name/path as a snap-in rather than a module/script | false |
