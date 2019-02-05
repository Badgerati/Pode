# SMTP Server

Pode has an inbuilt SMTP server which will automatically creates a TCP listener on port 25 (unless you pass a different port number to `listen` function).

Unlike with web `route` logic, SMTP uses the [`handler`](../../Functions/Core/Handler) function, which lets you specify logic for handling responses from TCP streams. Just note that you can only have one `handler` per `server`.

To create a `handler` for the inbuilt SMTP server you can use the following example:

```powershell
Server {
    listen *:25 smtp

    handler smtp {
        param($email)

        Write-Host $email.From
        Write-Host $email.To
        Write-Host $email.Data
    }
}
```

The SMTP `handler` will be passed the received email, and this object will have the following properties:

| Name | Type | Description |
| ---- | ---- | ----------- |
| From | string | The email address of the person sending the email |
| To | string[] | The email addresses receiving the email (this is to, cc, and bcc) |
| Subject | string | The subject of the email |
| Body | string | The body of the email, decoded depending on content type/encoding |
| ContentType | string | The content type of the original email body |
| ContentEncoding | string | The content encoding of the original email body |
| Data | string | The full raw data of the email |