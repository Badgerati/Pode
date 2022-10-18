# Endware

Endware in Pode is like [Middleware](../Middleware/Overview), but it runs after a Route. Endware will also run regardless the state of any prior Middleware or Route logic; if a either throws an error (ie: HTTP 500 or 404), then the Endware will still run. Also, if you have multiple Endwares configured, then each will be invoked inturn, but independently of each other - should one of the Endwares fail, the others will still be invoked.

Pode has some inbuilt Endware, namely:

* Any configured [Logging](../Logging/Overview) is invoked as Endware.
* If [Sessions](../Middleware/Types/Sessions) are enabled, then session data is persisted as Endware.

## Creating Endware

To add a new Endware script you can use [`Add-PodeEndware`](../../Functions/Utilities/Add-PodeEndware), and supply a `-ScriptBlock`:

```powershell
Add-PodeEndware -ScriptBlock {
    # logic
}
```

The scriptblock for Endware also has access to the [WebEvent](../WebEvent) variable.
