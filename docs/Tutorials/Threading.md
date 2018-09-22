# Threading

By default Pode deals with incoming request synchronously in a single thread. You can increase the number of threads/runspaces that Pode uses to handle requests by using the `-Threads` parameter on your [`Server`](../../Functions/Server):

```powershell
Server -Threads 2 {
    # logic
}
```

The number of threads supplied only applies to Web, SMTP, and TCP servers. If `-Threads` is not supplied, or is <=0 then the number of threads is forced to the default of 1.