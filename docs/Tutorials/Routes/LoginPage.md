# Creating a Login Page

This is mostly a pure example of having a website with a login and home page - with a logout button. The pages will all be done using `.pode` files, and authentication will be done using Form authentication with sessions.

!!! info
    This full example can be seen on GitHub in `examples/web-auth-form.ps1`.

## File Structure

Firstly, the file structure of this example will look as follows:

```plain
server.ps1
/views
    index.pode
    login.pode
/public
    styles/main.css
```

## Server

To start off this script, you'll need to have the main [`server`](../../../Functions/Core/Server) wrapper; here we'll use 2 threads to handle requests:

```powershell
Import-Module Pode

Start-PodeServer -Thread 2 {
    # the rest of the logic goes here!
}
```

Next, we'll need to [`listen`](../../../Functions/Core/Listen) on an endpoint and then specify the [`engine`](../../../Functions/Core/Engine) as using `.pode` files:

```powershell
Add-PodeEndpoint -Address *:8080 -Protocol HTTP

Set-PodeViewEngine -Type Pode
```

To use sessions for our authentication (so we can stay logged in), we need to setup [`session`](../../../Functions/Middleware/Session) [`middleware`](../../../Functions/Core/Middleware). Here our sessions will last for 2 minutes, and will be extended on each request:

```powershell
middleware (session @{
    'secret' = 'schwify';
    'duration' = 120;
    'extend' = $true;
})
```

Once we have the sessions in, we need to configure the Form [`authentication`](../../../Functions/Middleware/Auth) - the username/password here are hardcoded, but normally you would validate against a database:

```powershell
auth use form -v {
    param($username, $password)

    if ($username -eq 'morty' -and $password -eq 'pickle') {
        return @{ 'user' = @{
            'ID' ='M0R7Y302';
            'Name' = 'Morty';
            'Type' = 'Human';
        } }
    }

    # aww geez! no user was found
    return $null
}
```

This is where it gets interesting, below is the [`route`](../../../Functions/Core/Route) for the root (`/`) endpoint. This will check the cookies in the request for a signed session cookie, if one is found then the `index.pode` page is displayed - after incrementing a page-view counter. However, if there is no session, or authentication fails, the user is redirected to the login page:

```powershell
route get '/' (auth check form -o @{ 'failureUrl' = '/login' }) {
    param($s)

    $s.Session.Data.Views++

    Write-PodeViewResponse -Path 'index' -Data @{
        'Username' = $s.Auth.User.Name;
        'Views' = $s.Session.Data.Views;
    }
}
```

Next we have the login `route`, which is actually two routes. The `GET /login` is the page itself, whereas the `POST /login` is the authentication part (the endpoint the `<form>` element will hit).

For the `POST` route, if authentication passes the user is logged in and redirected to the home page, but if it failed they're taken back to the login page.

For the `GET` route we have a `<"login" = $true>` option; this basically means if the user navigates to the login page with an already validated session they're automatically taken back to the home page (the `successUrl`). However if they have no session or authentication fails then instead of a `403` being displayed, the login page is displayed instead.

```powershell
route get '/login' (auth check form -o @{ 'login' = $true; 'successUrl' = '/' }) {
    param($s)
    Write-PodeViewResponse -Path 'login'
}

route post '/login' (auth check form -o @{
    'failureUrl' = '/login';
    'successUrl' = '/';
}) {}
```

Finally, we have the logout `route`. Here we have another option of `<"logout" = $true>`, which basically just means to kill the session and redirect to the login page:

```powershell
route 'post' '/logout' (auth check form -o @{
    'logout' = $true;
    'failureUrl' = '/login';
}) {}
```

## Full Server

This is the full code for the server above:

```powershell
Import-Module Pode

Start-PodeServer -Thread 2 {
    Add-PodeEndpoint -Address *:8080 -Protocol HTTP

    # use pode template engine
    engine pode

    # setup session middleware
    middleware (session @{
        'secret' = 'schwify';
        'duration' = 120;
        'extend' = $true;
    })

    # setup form authentication
    auth use form -v {
        param($username, $password)

        if ($username -eq 'morty' -and $password -eq 'pickle') {
            return @{ 'user' = @{
                'ID' ='M0R7Y302';
                'Name' = 'Morty';
                'Type' = 'Human';
            } }
        }

        # aww geez! no user was found
        return $null
    }

    # the "GET /" endpoint for the homepage
    route get '/' (auth check form -o @{ 'failureUrl' = '/login' }) {
        param($s)

        $s.Session.Data.Views++

        Write-PodeViewResponse -Path 'index' -Data @{
            'Username' = $s.Auth.User.Name;
            'Views' = $s.Session.Data.Views;
        }
    }

    # the "GET /login" endpoint for the login page
    route get '/login' (auth check form -o @{ 'login' = $true; 'successUrl' = '/' }) {
        param($s)
        Write-PodeViewResponse -Path 'login'
    }

    # the "POST /login" endpoint for user authentication
    route post '/login' (auth check form -o @{
        'failureUrl' = '/login';
        'successUrl' = '/';
    }) {}

    # the "POST /logout" endpoint for ending the session
    route 'post' '/logout' (auth check form -o @{
        'logout' = $true;
        'failureUrl' = '/login';
    }) {}
}
```

## Pages

The following are the web pages used above, as well as the CSS style. The web pages have been created using [`.pode`](../../ViewEngines/Pode) files, which allows you to embed PowerShell into the files.

*index.pode*
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

*login.pode*
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