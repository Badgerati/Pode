# Importing Modules/SnapIns

Because Pode runs most things in isolated runspaces, importing and using modules or snap-ins can be quite bothersome. To overcome this, you can use the [`import`](../../Functions/Core/Import) function to declare paths/names of modules or snap-ins that need to be imported into all of the runspaces.

The `import` function takes a path/name of a module (`.psm1`/`.psd1`), or the name of a snap-in, and adds it to the session state for each runspace pool.

!!! important
    Snap-ins are only supported in Windows PowerShell.

## Modules

### Import via Path

The following example will tell Pode that the `tools.psm1` module needs to be imported into all runspaces. This will allow the functions defined within the module to be accessible to all other functions within your server.

```powershell
Server {
    import './path/to/tools.psm1'
}
```

### Import via Name

The following example will tell Pode to import the `EPS` module into all runspaces.

If you're using [`local modules`](../../Getting-Started/LocalModules) in your `package.json` file, then Pode will first check to see if the EPS module is in the `ps_modules` directory. When Pode can't find the EPS module within the `ps_modules` directory, then it will attempt to import a globally installed version of the EPS module.

```powershell
Server {
    import eps
}
```

## SnapIns

### Import via Name

The following example will tell Pode to import the `WDeploySnapin3.0` snap-in into all runspaces:

```powershell
Server {
    import -snapin 'WDeploySnapin3.0'
}
```