# Configuration

There is an *optional* configuration file that can be used with Pode called called `pode.json`, and should be located at the root directory of your server script.

!!! note
    When a server restart occurs, the `pode.json` file will be reloaded.

## Structure

The configuration file is just plain JSON, so normal JSON syntax applies. Within the file you can put any settings you want however, there are 5 defined sections that should ideally be left for Pode:

```json
{
    "server": { },
    "service": { },
    "web": { },
    "smtp": { },
    "tcp": { }
}
```

These 5 sections apply to the different server types you can build with Pode, and could be used for later inbuilt options (such as the current `web/static/defaults` for defining [default static pages](../Routes/Overview#default-pages)).

After this, you can put whatever else you want into the configuration file.

## Usage

The configuration file is automatically loaded when you start your server. Pode will look in the root directory of your server for a `pode.json` file, and if found it will be loaded internally.

Within your scripts you can use the [`config`](../../Functions/Core/Config) function, which will return the contents of the relevant config file.

For example, say you have the following `pode.json`:

```json
{
    "port": 8080
}
```

Then you can get and use the port number via:

```powershell
Server {
    $port = (config).port
    listen *:$port http
}
```

## Environments

Besides the default `pode.json` file, Pode also supports environmental files based on the `$env:PODE_ENVIRONMENT` environment variable.

For example, if you set the `PODE_ENVIRONMENT` variable to `dev`, then Pode will look for `pode.dev.json` first. If `pode.dev.json` does not exist, then the default `pode.json` is loaded instead.