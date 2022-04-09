# SMTP Server

Pode has an inbuilt SMTP server for receiving emails, with support for non-TLS as well as implicit and explicit TLS. Unlike with web servers that use the Route functions, an SMTP server use the Handler functions, which let you specify logic for handling responses from TCP streams.

!!! tip
    You can setup multiple different Handlers to run different logic for one email.

## Usage

To create a Handler for the SMTP server you can use the following example:

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

Starting this server will listen for incoming email on `localhost:25`. The Handler will have access to an `$SmtpEvent` object (see below), which contains information about the received email.

An example of sending an email to the above server via `Send-MailMessage`:

```powershell
Send-MailMessage -SmtpServer localhost -To 'to@example.com' -From 'from@example.com' -Body 'Hello' -Subject 'Hi there' -Port 25
```

## TLS

You can enable TLS for your endpoints by supplying the normal relevant certificates parameters on [`Add-PodeEndpoint`](../../Functions/Core/Add-PodeEndpoint), and setting the `-Protocol` to `Smtps`. You can also toggle between implicit and explicit TLS by using the `-TlsMode` parameter.

By default the TLS mode is implicit, and the default port for implicit TLS is 465; for explicit TLS it's 587. These can of course be customised using `-Port`.

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address * -Protocol Smtps -SelfSigned -TlsMode Explicit
    Add-PodeEndpoint -Address * -Protocol Smtps -SelfSigned -TlsMode Implicit

    Add-PodeHandler -Type Smtp -Name 'Main' -ScriptBlock {
        Write-Host $SmtpEvent.Email.From
        Write-Host $SmtpEvent.Email.To
        Write-Host $SmtpEvent.Email.Body
    }
}
```

.NET only supports explicit TLS, so an example of sending an email to the explicit TLS endpoint, on port 587, is as follows:

```powershell
# if using a self signed cert, make sure to run the below
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { return $true }

# send the email
Send-MailMessage -SmtpServer localhost -To 'to@pode.com' -From 'from@pode.com' -Body 'Hello' -Subject 'Hi there' -Port 587 -UseSSL
```

## Attachments

The SMTP server also accepts attachments, which are available in a Handler via `$SmtpEvent.Email.Attachments`. This property contains a list of available attachments on the Email, each attachment has a `Name` and `Bytes` properties - the latter being the raw byte content of the attachment.

An attachment also has a `.Save(<path>)` method. For example, if the Email has an a single attachment: an `example.png` file, and you wish to save it, then the following will save the file to `C:\temp\example.png`:

```powershell
Add-PodeHandler -Type Smtp -Name 'Main' -ScriptBlock {
    $SmtpEvent.Email.Attachments[0].Save('C:\temp')
}
```

## Objects

### SmtpEvent

The SMTP Handler will be passed the `$SmtpEvent` object, that contains the Request, Response, and Email properties:

| Name | Type | Description |
| ---- | ---- | ----------- |
| Request | object | The raw Request object |
| Response | object | The raw Response object |
| Lockable | hashtable | A synchronized hashtable that can be used with `Lock-PodeObject` |
| Email | hashtable | An object containing data from the email, as seen below |

### Email

The `Email` property contains the following properties:

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
| Attachments | PodeSmtpAttachment[] | An list of SMTP attachments, containing the Name and Bytes of the attachment |
