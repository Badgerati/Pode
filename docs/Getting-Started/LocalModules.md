# Local Modules

To save installing PowerShell modules globally, Pode allows you to specify modules in the `package.json` file; these modules will be downloaded into a `ps_modules` folder at the root of your server.

!!! Important
    Pode will only download modules from the PowerShell Gallery. This is only a basic implementation, if you wish to download from other locations, we'd recommend looking at other tools such as [`PSDepend`](https://github.com/RamblingCookieMonster/PSDepend/) or [`PSPM`](https://github.com/mkht/pspm)

## Package.json

Within your server's `package.json` file, you can specify a `modules` and `devModules` section with a list of modules and their versions to download:

```json
{
    "modules": {
        "eps": "0.5.0"
    },
    "devModules": {
        "pester": "latest"
    }
}
```

The `"latest"` version will always install the latest version of the module. When installing, if Pode detects a different version already downloaded then it will be removed.

## Pode Install

When you have modules defined within your `package.jon` file, then calling `pode install` from the CLI will automatically download any defined modules. Using `pode -d install` will also install the modules, but will also install the dev-modules.

These modules will be downloaded into a `ps_modules` directory at the root of your server. For example, using the above `package.json` and calling `pode -d install` will create the following directory structure:

```plain
server.ps1
package.json
/ps_modules
    /eps
        /0.5.0
    /pester
        /4.6.0
```

## Importing

When the modules have been downloaded, you can utilise them using the `Import-PodeModule` function.
