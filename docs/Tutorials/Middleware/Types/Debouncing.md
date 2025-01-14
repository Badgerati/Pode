# Debouncing

Debouncing is a programming concept used to limit the frequency of execution for a function or operation. It ensures that repeated triggers, such as user input events or network requests, are handled only once within a specified time frame. This is particularly useful to prevent overwhelming a system with excessive operations, reduce redundant processing, and optimize resource usage.

For example, in web development, debouncing is commonly applied to search inputs to limit API calls, or in scroll events to avoid excessive recalculations. On the server-side, like in Pode, debouncing helps manage client requests effectively, ensuring that excessive, rapid calls from the same client are appropriately throttled.

## Usage

To implement debouncing in Pode, you use the `Add-PodeDebounce` function. This function allows you to set a debounce timeout for requests and ensures that repeated calls within this timeout period are blocked, responding with a `429 Too Many Requests` status.

### Debouncing Requests

You can debounce requests to endpoints by specifying a timeout period. For example, the following will block repeated requests from a client to any endpoint within 500 milliseconds:

```powershell
Add-PodeDebounce -DebounceTimeoutMilliseconds 500
```

In this example, if a client sends a request to the server and sends another within 500 milliseconds, the second request will be blocked.

### Advanced Configuration

#### Cleanup Interval

You can define a cleanup interval to periodically remove expired entries from the debounce table, ensuring efficient memory usage. For instance, the following command sets a cleanup interval of 300 seconds:

```powershell
Add-PodeDebounce -DebounceTimeoutMilliseconds 500 -CleanupIntervalSeconds 300
```

#### Entry Expiration

You can also specify how long debounce entries should remain before expiring. This is useful for long-running servers to avoid unnecessary memory consumption. The following example sets an expiration time of 60 seconds for debounce entries:

```powershell
Add-PodeDebounce -DebounceTimeoutMilliseconds 500 -ExpirationSeconds 60
```

### Combining Options

You can combine all options for comprehensive configuration. For example:

```powershell
Add-PodeDebounce -DebounceTimeoutMilliseconds 1000 -CleanupIntervalSeconds 300 -ExpirationSeconds 120
```

This setup applies a debounce timeout of 1000 milliseconds, runs a cleanup every 300 seconds, and expires entries after 120 seconds.

## Removing Debouncing

To disable the debouncing mechanism, you can use the `Remove-PodeDebounce` function. This removes the middleware and the associated cleanup timer:

```powershell
Remove-PodeDebounce
```
