# Import

## Description

The `import` function allows you to declare paths to PowerShell Modules (`.psm1`) that need to be imported into each runspace. Because Pode runs most things in isolated runspaces, importing and using external modules in Pode can be quite bothersome, with `import` Pode will handle importing your modules into all async runspaces for you.

## Examples

### Example 1

The following example will import the specified module into each of the runspaces that Pode creates. This way you'll be able to use each of the functions declared wihtin the module in `routes`, `timers`, `schedules`, `loggers`, `handlers`, etc. (basically, everything):

```powershell
Server {
    import './path/to/module.psm1'
}
```

## Parameters

| Name | Type | Required | Description | Default |
| ---- | ---- | -------- | ----------- | ------- |
| Path | string | true | The path to a PowerShell Module (`.psm1`) that should be imported into the runspaces | empty |
