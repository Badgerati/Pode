# Anonymous Access

This example builds on top of the [Login Page](../LoginPage) example. This time instead of having a user navigate to the home page, and then be immediately redirected to the login page, this time we'll allow an unauthenticated user to access the home page.

When this unauthenticated user accesses the home page, they'll be a switch in logic to show different content and a login button - rather than a greeting and a logout button.

## Allow Anon

The first thing we need to do is specify that the home page route should allow anonymous access. To achieve this we can use the `-AllowAnon` switch on [`Add-PodeRoute`](../../../../Functions/Routes/Add-PodeRoute). With this switch, if the user isn't authenticated - even if the `-Authentication` parameter supplied - then the home page will still load anyway.

Below is the home page route from the [Login Page](../LoginPage) example, but now with anonymous access allowed:

```powershell
Add-PodeRoute -Method Get -Path '/' -Authentication 'Login' -AllowAnon -ScriptBlock {
    $WebEvent.Session.Data.Views++

    Write-PodeViewResponse -Path 'auth-home' -Data @{
        Username = $WebEvent.Auth.User.Name;
        Views = $WebEvent.Session.Data.Views;
    }
}
```

Now when a user navigates to `http://localhost:8080/` they won't be redirected to `http://localhost:8080/login`.

## Is there a User?

However, now we have an issue: if an authenticated or an unauthenticated user access the home page, they'll both be greeted with the same content! This is hardly desirable, so we need a way to test if whether we have an authenticated user or not.

To achieve this we can use [`Test-PodeAuthUser`](../../../../Functions/Authentication/Test-PodeAuthUser). This function will return whether or not the current request (or `$WebEvent`) has an authenticated user, if it does then we can show the original content and if not we can show different content:

```powershell
Add-PodeRoute -Method Get -Path '/' -Authentication 'Login' -AllowAnon -ScriptBlock {
    if (Test-PodeAuthUser) {
        $session:Views++

        Write-PodeViewResponse -Path 'auth-home' -Data @{
            Username = $WebEvent.Auth.User.Name
            Views = $session:Views
        }
    }
    else {
        Write-PodeViewResponse -Path 'auth-home-anon'
    }
}
```

Now, when an authenticated user hits the page, they're shown the original personal greeting page with view counter. However, when an unauthenticated user hits the page they are shown a generic greeting with a login button.

## Example Code

This is the full code for the server above:

```powershell
Start-PodeServer -Thread 2 {
    Add-PodeEndpoint -Address * -Port 8080 -Protocol Http

    # use pode template engine
    Set-PodeViewEngine -Type Pode

    # setup session middleware
    Enable-PodeSessionMiddleware -Duration 120 -Extend

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
    Add-PodeRoute -Method Get -Path '/' -Authentication 'Login' -AllowAnon -ScriptBlock {
        if (Test-PodeAuthUser) {
            $session:Views++

            Write-PodeViewResponse -Path 'auth-home' -Data @{
                Username = $WebEvent.Auth.User.Name
                Views = $session:Views
            }
        }
        else {
            Write-PodeViewResponse -Path 'auth-home-anon'
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

### Pages

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

*auth-home-anon.pode*
```html
<html>
    <head>
        <title>Auth Home</title>
        <link rel="stylesheet" type="text/css" href="/styles/simple.css">
    </head>
    <body>

        Hello, there! Welcome to the home page, please login below.

        <form action="/login" method="get">
            <div>
                <input type="submit" value="Login"/>
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
