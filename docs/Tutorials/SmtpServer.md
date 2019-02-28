# SMTP Server

Pode has an inbuilt SMTP server which will automatically creates a TCP listener on port 25 (unless you specify a different port via the [`listen`](../../Functions/Core/Listen) function).

Unlike with web servers that use the `route` function, SMTP servers use the [`handler`](../../Functions/Core/Handler) function, which lets you specify logic for handling responses from TCP streams. Just note that you can only have one `handler` per `server`.

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

The SMTP `handler` will be passed the current email object, and this will have the following properties:

| Name | Type | Description |
| ---- | ---- | ----------- |
| From | string | The email address of the person sending the email |
| To | string[] | The email addresses receiving the email (this is to, cc, and bcc) |
| Subject | string | The subject of the email |
| Body | string | The body of the email, decoded depending on content type/encoding |
| IsUrgent | boolean | This will be true if the Priority/Importance of the email is High, otherwise false |
| ContentType | string | The content type of the original email body |
| ContentEncoding | string | The content encoding of the original email body |
| Headers | hashtable | A list of all the headers received for the email |
| Data | string | The full raw data of the email |