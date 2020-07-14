# REST APIs and Sessions

Sessions in Pode are normally done using cookies, but you can also use them via headers as well. This way you can have two endpoints for authentication login/logout, and the rest of your routes depend on a valid SessionId.

!!! info
    The full example can be seen on GitHub in `examples/web-auth-basic-header.ps1`.

## Server

To start off, you'll need the main [`Start-PodeServer`](../../../../Functions/Core/Start-PodeServer) function; here we'll use 2 threads to handle requests:

```powershell
Start-PodeServer -Thread 2 {
    # the rest of the logic goes here!
}
```

Next, we'll need an endpoint to listen on. Using the [`Add-PodeEndpoint`](../../../../Functions/Core/Add-PodeEndpoint) function will let you specify and endpoint for your server to listen on, such as `http://localhost:8080`:

```powershell
Add-PodeEndpoint -Address * -Port 8080 -Protocol Http
```

## Enabling Sessions

To use sessions with headers for our authentication, we need to setup Session Middleware using the [`Enable-PodeSessionMiddleware`](../../../../Functions/Middleware/Enable-PodeSessionMiddleware) function. Here our sessions will last for 2 minutes, and will be extended on each request:

```powershell
Enable-PodeSessionMiddleware -Secret 'schwifty' -Duration 120 -Extend -UseHeaders
```

## Authentication

Once we have the Sessions enabled, we need to setup Basic Authentication - the username/password here are hard-coded, but normally you would validate against some database:

```powershell
New-PodeAuthScheme -Basic | Add-PodeAuth -Name 'Login' -ScriptBlock {
    param($username, $password)

    # here you'd check a real user storage, this is just for example
    if ($username -eq 'morty' -and $password -eq 'pickle') {
        return @{
            User = @{
                ID ='M0R7Y302'
                Name = 'Morty'
                Type = 'Human'
            }
        }
    }

    # aww geez! no user was found
    return @{ Message = 'Invalid details supplied' }
}
```

## Login and Logout

The first two routes will be two POST routes to login/logout a user. This first route will authenticate the user, and then respond back with a session in the response's `pode.sid` header:

```powershell
Add-PodeRoute -Method Post -Path '/login' -Authentication 'Login'
```

For the login endpoint, you would the request and supply the normal `Authorization` header.

The second route will require the session to be sent in the request's `pode.sid` header, and will expire and destroy the session:

```powershell
Add-PodeRoute -Method Post -Path '/logout' -Authentication 'Login' -Logout
```

The first route on success will return with a 200 response, the logout route will respond with a 401 since the session no longer exists. And other routes called using the same session will also return with a 401.

## Routes

This is a very basic POST route, but it will return a list of users if a valid `pode.sid` header has been supplied on the request:

```powershell
Add-PodeRoute -Method Post -Path '/users' -Authentication 'Login' -ScriptBlock {
    Write-PodeJsonResponse -Value @{
        Users = @(
            @{
                Name = 'Deep Thought'
                Age = 42
            },
            @{
                Name = 'Leeroy Jenkins'
                Age = 1337
            }
        )
    }
}
```

If you don't supply a session, or supply an invalid one, then a 401 in returned. You could also just straight-up supply the `Authorization` header on the request instead.

## Web Requests

If you use the exact endpoint and dummy credentials above, then the follow are calls you can do on the PowerShell CLI.

### Login

This call will authenticate and create a session:

```powershell
$session = (Invoke-WebRequest -Uri http://localhost:8080/login -Method Post -Headers @{ Authorization = 'Basic bW9ydHk6cGlja2xl' }).Headers['pode.sid'][0]
```

### Users

This call will use the above session from logging in, and return a list of users:

```powershell
Invoke-RestMethod -Uri http://localhost:8080/users -Method Post -Headers @{ 'pode.sid' = "$session" }
```

### Logout

This call will use the same session, but will time it out:

```powershell
Invoke-WebRequest -Uri http://localhost:8085/logout -Method Post -Headers @{ 'pode.sid' = "$session" }
```
