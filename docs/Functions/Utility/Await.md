# Await

## Description

The `await` function takes a `[System.Threading.Tasks.Task]` object, and waits for it to complete. If running within the context of Pode, a cancellation token will be supplied for when you terminate/restart your server.

If the task's result object is non-null, then a value is returned from the `await` function.

## Examples

### Example 1

The following example will wait on an async call for an `HttpListener`; on completion, the `HttpContext` is returned:

```powershell
Start-PodeServer {
    $context = (await $httpListener.GetContextAsync())
}
```

### Example 2

The following example will async write some bytes to a stream. Since the `WriteAsync` function doesn't return a value, then `await` also doesn't return anything:

```powershell
Start-PodeServer {
    await $stream.WriteAsync($bytes, 0, $bytes.Length)
}
```

## Parameters

| Name | Type | Required | Description | Default |
| ---- | ---- | -------- | ----------- | ------- |
| Task | [System.Threading.Tasks.Task] | true | The task to wait on for completion | null |
