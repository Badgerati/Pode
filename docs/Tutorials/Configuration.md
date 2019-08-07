# Configuration

There is an *optional* configuration file that can be used with Pode called called `server.psd1`, and should be located at the root directory of your server script.

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

Within your scripts you can use the `Get-PodeConfig` function, which will return the values of the relevant configuration file.

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
    Add-PodeEndpoint -Address *:$port -Protocol Http
}
```

## Environments

Besides the default `server.psd1` file, Pode also supports environmental files based on the `$env:PODE_ENVIRONMENT` environment variable.

For example, if you set the `PODE_ENVIRONMENT` variable to `dev`, then Pode will look for `server.dev.psd1` first. If `server.dev.psd1` does not exist, then the default `server.psd1` is loaded instead.
