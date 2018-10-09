# External Modules

Because Pode runs most things in isolated runspaces, importing and using external modules in Pode can be quite bothersome. To overcome this, you can use the [`import`]() function to declare paths to modules that need to be imported into each runspace.

The `import` function takes a path to a module (`.psm1`) - can be literal or relative - and adds it to the session state for each runspace pool.

The following example will tell Pode that the `module.psm1` module needs to be imported onto all runspace. This will allow the functions defined in the module to be accessible to timers, routes, scheduled, etc.

```powershell
Server {
    import './path/to/module.psm1'
}
```