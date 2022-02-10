# Scoping

Scoping in Pode can be a little confusing at times, with everything running in different runspaces it can be hard to keep track of what's available, and what's not.

In 2.0 work was done to help alleviate some of this confusion, mostly around modules; snapins; functions, and variables.

## Modules

Prior to 2.0 you had to use the [`Import-PodeModule`](../../Functions/Utilities/Import-PodeModule) function; but now, you can use the normal `Import-Module` function. Pode will automatically import all currently loaded modules into its runspaces. The [`Import-PodeModule`](../../Functions/Utilities/Import-PodeModule) function still exists though, for support with local modules via `ps_modules` - under the hood however, it now just calls `Import-Module`.

Below, `SomeModule1` and `SomeModule2` will be automatically imported into all of Pode's runspaces, and their functions readily available:

```powershell
Import-Module SomeModule1, SomeModule2

Start-PodeServer -ScriptBlock {
    Add-PodeEndpoint -Address localhost -Port 9000 -Protocol Http

    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        Use-SomeModule1Function
    }
}
```

!!! note
    If you're starting your server with `pode start`, you'll need to use `-Scope Global` on `Import-Module`.

### Disable

If you don't need any modules, or want to stop the auto-importing from occurring, you can use disable it via the `server.psd1` [configuration file](../Configuration):

```powershell
@{
    Server = @{
        AutoImport = @{
            Modules = @{
                Enable = $false
            }
        }
    }
}
```

### Export

If you want finer control over which modules are auto-imported, then you can set the auto-import to use an export list. To do so, you set Pode to only import exported modules:

```powershell
@{
    Server = @{
        AutoImport = @{
            Modules = @{
                Enable = $true
                ExportOnly = $true
            }
        }
    }
}
```

Then you can "export" modules that Pode should import by using [`Export-PodeModule`](../../Functions/AutoImport/Export-PodeModule). Below only `SomeModule2` will be auto-imported into all of Pode's runspaces.

```powershell
Import-Module SomeModule1, SomeModule2

Start-PodeServer -ScriptBlock {
    Export-PodeModule SomeModule2
}
```

## Snapins

!!! important
    Snapins are only supported on Windows PowerShell.

Prior to 2.0 you had to use the [`Import-PodeSnapin`](../../Functions/Utilities/Import-PodeSnapin) function; but now, you can use the normal `Add-PSSnapin` function. Pode will automatically import all currently loaded snapins into its runspaces. The [`Import-PodeSnapin`](../../Functions/Utilities/Import-PodeSnapin) function still exists though, just to make transition to 2.0 a little easier - under the hood however, it now just calls `Add-PSSnapin`.

Below, `Some.Snapin.1` and `Some.Snapin.2` will be automatically imported into all of Pode's runspaces, and their functions readily available:

```powershell
Add-PSSnapin Some.Snapin.1
Add-PSSnapin Some.Snapin.2

Start-PodeServer -ScriptBlock {
    Add-PodeEndpoint -Address localhost -Port 9000 -Protocol Http

    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        Use-SomeSnapinFunction
    }
}
```

### Disable

If you don't need any snapins, or want to stop the auto-importing from occurring, you can use disable it via the `server.psd1` [configuration file](../Configuration):

```powershell
@{
    Server = @{
        AutoImport = @{
            Snapins = @{
                Enable = $false
            }
        }
    }
}
```

### Export

If you want finer control over which snapins are auto-imported, then you can set the auto-import to use an export list. To do so, you set Pode to only import exported snapins:

```powershell
@{
    Server = @{
        AutoImport = @{
            Snapins = @{
                Enable = $true
                ExportOnly = $true
            }
        }
    }
}
```

Then you can "export" snapins that Pode should import by using [`Export-PodeSnapin`](../../Functions/AutoImport/Export-PodeSnapin). Below only `Some.Snapin.2` will be auto-imported into all of Pode's runspaces.

```powershell
Add-PSSnapin 'Some.Snapin.1'
Add-PSSnapin 'Some.Snapin.2'

Start-PodeServer -ScriptBlock {
    Export-PodeSnapin 'Some.Snapin.2'
}
```

## Functions

Prior to 2.0 if you wanted to use quick local functions in your Routes/etc, you would have needed to put them all into a module file, and then use [`Import-PodeSnapin`](../../Functions/Utilities/Import-PodeSnapin) to load them. But now you can just define your functions in the same ps1 file, and Pode will auto-import them for you.

Below, `Write-HelloResponse` and `Write-ByeResponse` will be automatically imported into all of Pode's runspaces, ready for use:

```powershell
function Write-HelloResponse
{
    Write-PodeJsonResponse -Value @{ Message = 'Hello!' }
}

Start-PodeServer -ScriptBlock {
    function Write-ByeResponse
    {
        Write-PodeJsonResponse -Value @{ Message = 'Bye!' }
    }

    Add-PodeEndpoint -Address localhost -Port 9000 -Protocol Http

    Add-PodeRoute -Method Get -Path '/hello' -ScriptBlock {
        Write-HelloResponse
    }

    Add-PodeRoute -Method Get -Path '/bye' -ScriptBlock {
        Write-ByeResponse
    }
}
```

If you store Routes/etc in other files, you can also have local functions in these files as well. However, for Pode to import them you must use [`Use-PodeScript`](../../Functions/Utilities/Use-PodeScript) to dot-source the scripts - this will trigger Pode to scan the file for functions.

### Disable

If you don't need any functions, or want to stop the auto-importing from occurring, you can use disable it via the `server.psd1` [configuration file](../Configuration):

```powershell
@{
    Server = @{
        AutoImport = @{
            Functions = @{
                Enable = $false
            }
        }
    }
}
```

### Export

If you want finer control over which functions are auto-imported, then you can set the auto-import to use an export list. To do so, you set Pode to only import exported modules:

```powershell
@{
    Server = @{
        AutoImport = @{
            Functions = @{
                Enable = $true
                ExportOnly = $true
            }
        }
    }
}
```

Then you can "export" functions that Pode should import by using [`Export-PodeFunction`](../../Functions/AutoImport/Export-PodeFunction). Below only `Write-HelloResponse` will be auto-imported into all of Pode's runspaces.

```powershell
function Write-HelloResponse
{
    Write-PodeJsonResponse -Value @{ Message = 'Hello!' }
}

Start-PodeServer -ScriptBlock {
    function Write-ByeResponse
    {
        Write-PodeJsonResponse -Value @{ Message = 'Bye!' }
    }

    Add-PodeEndpoint -Address localhost -Port 9000 -Protocol Http

    Add-PodeRoute -Method Get -Path '/hello' -ScriptBlock {
        Write-HelloResponse
    }

    Add-PodeRoute -Method Get -Path '/bye' -ScriptBlock {
        # this would fail
        Write-ByeResponse
    }

    Export-PodeFunction 'Write-HelloResponse'
}
```

## Variables

Prior to 2.0 if you wanted to use quick local variables in your Routes/etc, you would have needed to use the [`Set-PodeState`](../../Functions/State/Set-PodeState)/[`Get-PodeState`](../../Functions/State/Get-PodeState) functions. But now you can just define your variables in the same ps1 file, and then reference them in your Routes/etc via the `$using:` syntax.

The `$using:` syntax is supported in almost all `-ScriptBlock` parameters for the likes of:

* Authentication
* Endware
* Handlers
* Logging
* Middleware
* Routes
* Schedules
* Timers

Below, the `$outer_msg` and `$inner_msg` variables can now be more simply referenced in a Route:

```powershell
$outer_msg = 'Hello, there'

Start-PodeServer -ScriptBlock {
    Add-PodeEndpoint -Address localhost -Port 9000 -Protocol Http

    $inner_msg = 'General Kenobi'

    Add-PodeRoute -Method Get -Path '/random' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ Message = "$($using:outer_msg) ... $($using:inner_msg)" }
    }
}
```
