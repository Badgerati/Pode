# Configuration

There is an *optional* configuration file that can be used with Pode called `server.psd1`, and should be located at the root directory of your server script.

!!! note
    When a server restart occurs, the `server.psd1` file will always be reloaded.

## Structure

The configuration file is basically just a `hashtable`, so normal `hashtable` syntax applies. Within the file you can put any settings you want however, there are 5 defined sections that should ideally be left for Pode:

```powershell
@{
    Server = @{ }
    Service = @{ }
    Web = @{ }
    Smtp = @{ }
    Tcp = @{ }
}
```

These 5 sections apply to the different server types you can build with Pode, and could be used for later inbuilt options (such as the current `Web/Static/Defaults` for defining [default static pages](../Routes/Overview#default-pages)).

After this, you can put whatever else you want into the configuration file.

## Usage

The configuration file is automatically loaded when you start your server. Pode will look in the root directory of your server for a `server.psd1` file, and if found it will be loaded internally.

Within your scripts you can use the [`Get-PodeConfig`](../../Functions/Utilities/Get-PodeConfig) function, which will return the values of the configuration file.

For example, say you have the following `server.psd1`:

```powershell
@{
    Port = 8080
}
```

Then you can get and use the port number via:

```powershell
Start-PodeServer {
    $port = (Get-PodeConfig).Port
    Add-PodeEndpoint -Address * -Port $port -Protocol Http
}
```

## Environments

Besides the default `server.psd1` file, Pode also supports environmental files based on the `$env:PODE_ENVIRONMENT` environment variable.

For example, if you set the `PODE_ENVIRONMENT` variable to `dev`, then Pode will look for `server.dev.psd1` first. If `server.dev.psd1` does not exist, then the default `server.psd1` is loaded instead.

## Options

The following table details all of the currently available, inbuilt, `server.psd1` options that can be used.

A "path" like `Server.Ssl.Protocols` looks like the below in the file:

```powershell
@{
    Server = @{
        Ssl= @{
            Protocols = @('TLS', 'TLS11', 'TLS12')
        }
    }
}
```

| Path | Description | Docs |
| ---- | ----------- | ---- |
| Server.Ssl.Protocols | Indicates the SSL Protocols that should be used | [link](../Certificates) |
| Server.Request | Defines request timeout and maximum body size | [link](../RequestLimits) |
| Server.AutoImport | Defines the AutoImport scoping rules for Modules, SnapIns and Functions | [link](../Scoping) |
| Server.Logging | Defines extra configuration for Logging, like masking sensitive data | [link](../Logging/Overview) |
| Server.Root | Overrides root path of the server | [link](../Misc/ServerRoot) |
| Server.Restart | Defines configuration for automatically restarting the server | [link](../Restarting/Types/AutoRestarting) |
| Server.FileMonitor | Defines configuration for restarting the server based on file updates | [link](../Restarting/Types/FileMonitoring) |
| Web.TransferEncoding | Sets the Request TransferEncoding | [link](../Compression/Requests) |
| Web.Compression | Sets any compression to use on the Response | [link](../Compression/Responses) |
| Web.ContentType | Define expected Content Types for certain Routes | [link](../Routes/Utilities/ContentTypes) |
| Web.ErrorPages | Defines configuration for custom error pages | [link](../Routes/Utilities/ErrorPages) |
| Web.Static | Defines configuration for static content, such as caching | [link](../Routes/Utilities/StaticContent) |
