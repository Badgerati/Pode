# SMTP Server

Pode has an inbuilt SMTP server which automatically creates a TCP listener on port 25 (unless you specify a different port via the [`Add-PodeEndpoint`](../../Functions/Core/Add-PodeEndpoint) function).

Unlike with web servers that use the Route functions, SMTP servers use the Handler functions, which let you specify logic for handling responses from TCP streams.

To create a Handler for the inbuilt SMTP server you can use the following example:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address * -Port 25 -Protocol Smtp

    Add-PodeHandler -Type Smtp -Name 'Main' -ScriptBlock {
        Write-Host $SmtpEvent.Email.From
        Write-Host $SmtpEvent.Email.To
        Write-Host $SmtpEvent.Email.Body
    }
}
```

The SMTP Handler will be passed the a `$SmtpEvent` object, that conatins te Request, Response, and Email:

| Name | Type | Description |
| ---- | ---- | ----------- |
| Request | object | The raw Request object |
| Response | object | The raw Response object |
| Lockable | hashtable | A synchronized hashtable that can be used with `Lock-PodeObject` |
| Email | hashtable | An object containing data from the email, as seen below |

The `Email` property contains the following:

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
