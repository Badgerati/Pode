# Importing Modules/Snapins

Modules/Snapins in Pode have recently undergone a change, making them easier to use with Pode's many runspaces. This change means you can use the normal `Import-Module`/`Add-PSSnapin` at the top of your scripts, and Pode will automatically import them into its runspaces. For more information, see the [Scoping](../Scoping) page.

The older [`Import-PodeModule`](../../Functions/Utilities/Import-PodeModule) and [`Import-PodeSnapin`](../../Functions/Utilities/Import-PodeSnapin) still exist - but now mostly just directly call the main module/snapin functions.

!!! important
    Snapins are only supported in Windows PowerShell.

## Modules

Modules in Pode can be imported in the normal manor using `Import-Module`. The [`Import-PodeModule`](../../Functions/Utilities/Import-PodeModule) function can now be used inside and outside of [`Start-PodeServer`](../../Functions/Core/Start-PodeServer), and should be used if you're using local modules via `ps_modules`.

### Import via Path

The following example will tell Pode that the `tools.psm1` module needs to be imported. This will allow the functions defined within the module to be accessible to all other functions within your server.

```powershell
Import-PodeModule -Path './path/to/tools.psm1'
```

### Import via Name

The following example will tell Pode to import the `EPS` module into all runspaces.

If you're using [`local modules`](../../Getting-Started/LocalModules) in your `package.json` file, then Pode will first check to see if the EPS module is in the `ps_modules` directory. When Pode can't find the EPS module within the `ps_modules` directory, then it will attempt to import a globally installed version of the EPS module.

```powershell
# if using local modules:
Import-PodeModule -Name EPS

# if using global modules
Import-Module -Name EPS
```

## Snapins

### Import via Name

The following example will tell Pode to import the `WDeploySnapin3.0` snap-in into all runspaces:

```powershell
Import-PodeSnapin -Name 'WDeploySnapin3.0'

# or just:
Add-PSSnapin -Name 'WDeploySnapin3.0'
```
