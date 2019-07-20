# SMTP Server

Pode has an inbuilt SMTP server which automatically creates a TCP listener on port 25 (unless you specify a different port via the `Add-PodeEndpoint` function).

Unlike with web servers that use the Route functions, SMTP servers use the Handler functions, which let you specify logic for handling responses from TCP streams.

To create a `handler` for the inbuilt SMTP server you can use the following example:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address *:25 -Protocol SMTP

    Add-PodeHandler -Type Smtp -Name 'Main' -ScriptBlock {
        param($email)

        Write-Host $email.From
        Write-Host $email.To
        Write-Host $email.Data
    }
}
```

The SMTP Handler will be passed the current email object, and this will have the following properties:

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
