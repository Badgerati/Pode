# Threading

By default Pode deals with incoming requests synchronously in a single thread. You can increase the number of threads/runspaces that Pode uses to handle requests by using the `-Threads` parameter on the [`Start-PodeServer`](../../Functions/Core/Start-PodeServer) function:

```powershell
Start-PodeServer -Threads 2 {
    # logic
}
```

The number of threads supplied only applies to Web, SMTP, and TCP servers. If `-Threads` is not supplied, or is <=0 then the number of threads is forced to the default of 1.
