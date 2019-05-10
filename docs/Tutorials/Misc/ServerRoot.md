# Server Root

The root path for your server, by default, is always defined by `$MyInvocation.PSScriptRoot`.

Normally this is enough, and you'll likely never need to change it however, if you should want to change your server's root path, you can alter it via the `pode.json` file:

```json
{
    "server": {
        "root": "./path"
    }
}
```

The path you supply can be literal, or relative to `$MyInvocation.PSScriptRoot`. If you supply a literal path it will be used instead of the invocation path.