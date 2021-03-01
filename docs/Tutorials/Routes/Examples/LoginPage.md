# Creating a Login Page

This is an example of having a website with a login and home page - with a logout button. The pages will all be done using `.pode` files, and authentication will be done using Form Authentication with Sessions.

!!! info
    The full example can be seen on GitHub in [`examples/web-auth-form.ps1`](https://github.com/Badgerati/Pode/blob/develop/examples/web-auth-form.ps1).

## File Structure

Firstly, the file structure of this example will look as follows:

```plain
server.ps1
/views
    auth-home.pode
    auth-login.pode
/public
    styles/main.css
```

## Server

To start off this script, you'll need to have the main [`Start-PodeServer`](../../../../Functions/Core/Start-PodeServer) function; here we'll use 2 threads to handle requests:

```powershell
Start-PodeServer -Thread 2 {
    # the rest of the logic goes here!
}
```

Next, we'll need to use the [`Add-PodeEndpoint`](../../../../Functions/Core/Add-PodeEndpoint) function to listen on an endpoint and then specify the View Engine as using `.pode` files:

```powershell
Add-PodeEndpoint -Address * -Port 8080 -Protocol Http
Set-PodeViewEngine -Type Pode
```

To use sessions for our authentication (so we can stay logged in), we need to setup Session Middleware using the [`Enable-PodeSessionMiddleware`](../../../../Functions/Middleware/Enable-PodeSessionMiddleware) function. Here our sessions will last for 2 minutes, and will be extended on each request:

```powershell
Enable-PodeSessionMiddleware -Secret 'schwifty' -Duration 120 -Extend
```

Once we have the Session Middleware initialised, we need to setup Form Authentication - the username/password here are hard-coded, but normally you would validate against some database. We also specify a `-FailureUrl`, which is the URL to redirect a user to if they try to access a page un-authenticated. The `-SuccessUrl` is the URL to redirect to on successful authentication.

```powershell
New-PodeAuthScheme -Form | Add-PodeAuth -Name 'Login' -FailureUrl '/login' -SuccessUrl '/' -ScriptBlock {
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

Below is the Route for the root (`/`) endpoint. This will check the cookies in the request for a signed session cookie, if one is found then the `index.pode` page is displayed - after incrementing a page-view counter. However, if there is no session, or authentication fails, the user is redirected to the login page:

```powershell
Add-PodeRoute -Method Get -Path '/' -Authentication 'Login' -ScriptBlock {
    $WebEvent.Session.Data.Views++

    Write-PodeViewResponse -Path 'auth-home' -Data @{
        Username = $WebEvent.Auth.User.Name;
        Views = $WebEvent.Session.Data.Views;
    }
}
```

Next we have the login Route, which is actually two routes. The `GET /login` is the page itself, whereas the `POST /login` is the authentication part (the endpoint the `<form>` element's action will hit).

For the `POST` Route, if Authentication passes the user is logged in and redirected to the home page, but if it failed they're taken back to the login page.

For the `GET` and `POST` login Route we supply the `-Login` switch, this flags that if the user navigates to the login page with an already verified session then they're automatically redirected to the home page (the `-SuccessUrl`). However, if they have no session or authentication fails then instead of a `403` being displayed, the login page is displayed instead (to prevent continuously trying to redirect to the `/login` page).

```powershell
# the login page itself
Add-PodeRoute -Method Get -Path '/login' -Authentication 'Login' -Login -ScriptBlock {
    Write-PodeViewResponse -Path 'auth-login' -FlashMessages
}

# the POST action for the <form>
Add-PodeRoute -Method Post -Path '/login' -Authentication 'Login' -Login
```

Finally, we have the logout Route. Here we have another switch of `-Logout`, which just means to kill the session and redirect the user to the login page:

```powershell
Add-PodeRoute -Method Post -Path '/logout' -Authentication 'Login' -Logout
```

## Full Server

This is the full code for the server above:

```powershell
Start-PodeServer -Thread 2 {
    Add-PodeEndpoint -Address * -Port 8080 -Protocol Http

    # use pode template engine
    Set-PodeViewEngine -Type Pode

    # setup session middleware
    Enable-PodeSessionMiddleware -Secret 'schwifty' -Duration 120 -Extend

    # setup form authentication
    New-PodeAuthScheme -Form | Add-PodeAuth -Name 'Login' -FailureUrl '/login' -SuccessUrl '/' -ScriptBlock {
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

    # the "GET /" endpoint for the homepage
    Add-PodeRoute -Method Get -Path '/' -Authentication 'Login' -ScriptBlock {
        $WebEvent.Session.Data.Views++

        Write-PodeViewResponse -Path 'auth-home' -Data @{
            Username = $WebEvent.Auth.User.Name;
            Views = $WebEvent.Session.Data.Views;
        }
    }

    # the "GET /login" endpoint for the login page
    Add-PodeRoute -Method Get -Path '/login' -Authentication 'Login' -Login -ScriptBlock {
        Write-PodeViewResponse -Path 'auth-login' -FlashMessages
    }

    # the "POST /login" endpoint for user authentication
    Add-PodeRoute -Method Post -Path '/login' -Authentication 'Login' -Login

    # the "POST /logout" endpoint for ending the session
    Add-PodeRoute -Method Post -Path '/logout' -Authentication 'Login' -Logout
}
```

## Pages

The following are the web pages used above, as well as the CSS style. The web pages have been created using [`.pode`](../../../Views/Pode) files, which allows you to embed PowerShell into the files.

*auth-home.pode*
```html
<html>
    <head>
        <title>Auth Home</title>
        <link rel="stylesheet" type="text/css" href="/styles/main.css">
    </head>
    <body>
        Hello, $($data.Username)! You have view this page $($data.Views) times!

        <form action="/logout" method="post">
            <div>
                <input type="submit" value="Logout"/>
            </div>
        </form>

    </body>
</html>
```

*auth-login.pode*
```html
<html>
    <head>
        <title>Auth Login</title>
        <link rel="stylesheet" type="text/css" href="/styles/main.css">
    </head>
    <body>
        Please Login:

        <form action="/login" method="post">
            <div>
                <label>Username:</label>
                <input type="text" name="username"/>
            </div>
            <div>
                <label>Password:</label>
                <input type="password" name="password"/>
            </div>
            <div>
                <input type="submit" value="Login"/>
            </div>
        </form>

    </body>
</html>
```

*styles/main.css*
```css
body {
    background-color: rebeccapurple;
}
```
