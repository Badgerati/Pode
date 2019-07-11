# Tcp

## Description

The `tcp` function allows you to read/write messages to/from a TCP stream. By default Pode's TCP server stream is used, but you can specify a custom TCP stream to read/write.

## Examples

### Example 1

The following example will write a message onto the TCP stream:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address *:30 -Protocol TCP

    handler tcp {
        tcp write 'Hello, world!'
    }
}
```

### Example 2

The following example will read a message from the TCP stream:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address *:30 -Protocol TCP

    handler tcp {
        $msg = (tcp read)
    }
}
```

## Parameters

| Name | Type | Required | Description | Default |
| ---- | ---- | -------- | ----------- | ------- |
| Action | string | true | The action to perform on the TCP stream (Values: Write, Read) | empty |
| Message | string | false | A message to write on the TCP stream | empty |
| Client | object | false | A custom other TCP stream, otherwise the global stream will be used | global stream |
