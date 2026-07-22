# Basics

!!! important
    You can only initiate one Pode server per PowerShell instance.

## Importing

While it's not mandatory, we strongly recommend importing the Pode module with a specified maximum version. This practice helps to prevent potential issues arising from breaking changes introduced in new major versions:

```powershell
Import-Module -Name Pode -MaximumVersion 2.99.99
```

To further enhance the robustness of your code, consider wrapping the import statement within a try/catch block. This way, if the module fails to load, your script won't proceed, preventing possible errors or unexpected behaviour:

```powershell
try {
    Import-Module -Name Pode -MaximumVersion 2.99.99
} catch {
    Write-Error "Failed to load the Pode module"
    throw
}
```

## Running

To start a new Pode server use [`Start-PodeServer`](../../Functions/Core/Start-PodeServer), and supply your server's logic via the `-ScriptBlock` parameter.

The following example will listen over HTTP on port 8080, and expose a simple Route that returns the host's name at `http://localhost:8080/`:

```powershell
Start-PodeServer {
    # attach to port 8080 for http
    Add-PodeEndpoint -Address localhost -Port 8080 -Protocol Http

    # a simple route that returns the host's name
    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        @{ Name = $env:COMPUTERNAME } | Write-PodeJsonResponse
    }
}
```

To start the server you can either:

* Directly run the `./server.ps1` script, or
* If you created a `package.json` file, ensure the `./server.ps1` script is set as your `main` or `scripts/start`, then just run `pode start` (more [here](../../Getting-Started/CLI))

## Terminating

Once your Pode server has started, you can terminate it at any time using `Ctrl+C`. If you want to disable your server from being terminated then use the `-DisableTermination` switch on [`Start-PodeServer`](../../Functions/Core/Start-PodeServer).

## Restarting

You can restart your Pode server by using `Ctrl+R`, or on Unix you can also use `Shift+C` and `Shift+R` as well. When the server restarts it will only re-invoke the initial `-ScriptBlock`, so any changes made to this main scriptblock will *not* be reflected - you'll need to terminate and start your server again.

## Script from File

You can define your server's scriptblock in a separate file, and load it via the `-FilePath` parameter on [`Start-PodeServer`](../../Functions/Core/Start-PodeServer).

Using this approach there are 2 ways to start you server:

1. You can put your scriptblock into a separate file, and put your [`Start-PodeServer`](../../Functions/Core/Start-PodeServer) call into another script. This other script is then what you call on the CLI.
2. You can directly call [`Start-PodeServer`](../../Functions/Core/Start-PodeServer) on the CLI.

When you call [`Start-PodeServer`](../../Functions/Core/Start-PodeServer) directly on the CLI, then your server's root path will be set to directory of that file. You can override this behaviour by either defining a path via `-RootPath`, or by telling the server to use the current working path as root via `-CurrentPath`.

For example, the following is a file that contains the same scriptblock for the server at the top of this page. Following that are the two ways to run the server - the first is via another script, and the second is directly from the CLI:

* File.ps1
```powershell
{
    # attach to port 8080 for http
    Add-PodeEndpoint -Address * -Port 8080 -Protocol Http

    # a simple page for displaying services
    Add-PodePage -Name 'processes' -ScriptBlock { Get-Process }
}
```

* Server.ps1 (start via script)
```powershell
Start-PodeServer -FilePath './File.ps1'
```
then use `./Server.ps1` on the CLI.

* CLI (start from CLI)
```powershell
PS> Start-PodeServer -FilePath './File.ps1'
```

!!! tip
    Normally when you restart your Pode server any changes to the main scriptblock don't reflect. However, if you reference a file instead, then restarting the server will reload the scriptblock from that file - so any changes will reflect.

## App Name

Primarily used by logging, the default application name of your server will be "Pode". You can customise this name via the `-AppName` parameter on [`Start-PodeServer`](../../Functions/Core/Start-PodeServer).

## Localisation

Pode has built-in support for localisation. By default, Pode uses the `$PsUICulture` variable to determine the User Interface Culture (UICulture).

You can enforce a specific localisation when importing the Pode module by using the UICulture argument. This argument accepts a culture code, which specifies the language and regional settings to use.

Here's an example of how to enforce Korean localisation:

```powershell
Import-Module -Name Pode -ArgumentList 'ko-KR'
```

In this example, 'ko-KR' is the culture code for Korean as used in South Korea. You can replace 'ko-KR' with the culture code for any other language or region.

As an alternative to specifying the UICulture when importing the Pode module, you can also change the UICulture within the PowerShell environment itself.

This can be done using the following command:

```powershell
[System.Threading.Thread]::CurrentThread.CurrentUICulture = 'ko-KR'
```

This command changes the UICulture for the current PowerShell session to Korean as used in South Korea.

Please note that this change is temporary and will only affect the current session. If you open a new PowerShell session, it will use the default UICulture.