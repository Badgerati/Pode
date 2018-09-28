# Handler

## Description

The `handler` function allows you to bind logic onto incoming TCP streams, or onto SMTP requests.

The SMTP handler type will use Pode's inbuilt simple SMTP server, which will automatically create a TCP listener on port 25 (unless you specific a different port to `listen` on). The handler logic in this case will be passed an argument containing information about the Email.

The TCP handler will have the TCP client itself passed to the handler's logic, this way you can build your own custom TCP handler.

!!! warning
    You can only have 1 `handler` per type. Ie, TCP can only have one handler defined, as well as SMTP.

## Examples

### Example 1

The following example will setup the inbuilt simple SMTP server, writing to the terminal the content of the email:

```powershell
Server {
    listen *:25 smtp

    handler smtp {
        param($email)
        Write-Host $email.Data
    }
}
```

!!! tip
    The `$email` argument supplied to the SMTP handler contains the `From` and `To` address, as well as the `Data` of the email.

### Example 2

The following example will setup a TCP server, having the TCP client passed to the handler's logic. It will read in a message from the stream, then write one back:

```powershell
Server {
    listen *:30 tcp

    handler tcp {
        $msg = (tcp read)

        if ($msg -ieq 'HELO') {
            tcp write 'HEY'
        }
    }
}
```

## Parameters

| Name | Type | Required | Description | Default |
| ---- | ---- | -------- | ----------- | ------- |
| Type | string | true | The type of 'TCP' to bind onto the handler (Values: TCP, SMTP) | empty |
| ScriptBlock | scriptblock | true | The main handler logic that will be invoked when the an incoming TCP stream is detected | null |
