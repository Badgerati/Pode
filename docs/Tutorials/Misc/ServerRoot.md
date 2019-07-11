# Server Root

The root path for your server, by default, is always defined by `$MyInvocation.PSScriptRoot`.

Normally this is enough, and you'll likely never need to change it however, if you should want to change your server's root path, you can alter it in the following ways.

!!! note
    The path you supply in both cases can be literal, or relative to `$MyInvocation.PSScriptRoot`. If you supply a literal path it will be used instead of the invocation path.

## Code

The main way to alter the root path of you server is to use the `-RootPath` parameter on the `server` function:

```powershell
Start-PodeServer -RootPath '../server' {
    # logic
}
```

With this, everything from your `pode.json`, `/views`, `/public`, etc will need to be within the `../server` directory.

## Configuration

The other way to alter the root path is via the `pode.json` file:

```json
{
    "server": {
        "root": "../server"
    }
}
```

In this case, the `pode.json` file will need to be located at `$MyInvocation.PSScriptRoot`. Everything else will need to be located in `../server`.