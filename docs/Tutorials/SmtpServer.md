# SMTP Server

Pode has an inbuilt SMTP server which will automatically create a TCP listener on port 25 (unless you pass a different port number to `listen`).

Unlike with web `route` logic, SMTP uses something called a [`handler`](../../Functions/Core/Handler). You can only have one handler per `server`.

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

The SMTP `handler` will be passed the email received, and this object will have the `From` address, the single/multiple `To` addresses, and the raw `Data` of the email body.