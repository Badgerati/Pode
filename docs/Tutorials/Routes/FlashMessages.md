# Flash Messages

Flash messages allow you to pass temporary messages - info/error or other - across multiple web requests via a user's current session.

For example, in sign-up logic you could set a flash error message for an invalid email address; retrieving the message from the session on a redirect for the view, allowing the view to render error messages.

!!! Important
    To use flash messages you need to have [`Session Middleware`](../../Middleware/Sessions) enabled.

## Usage

The [`flash`](../../../Functions/Utility/Flash) function allows you to add, get, and remove messages on a user's session.

The make-up of the `flash` function is as follows:

```powershell
flash <action> [<key> <message>]
```

* Valid `<action>` values are: `Add`, `Clear`, `Get`, `Keys`, `Remove`.
* A `<key>` must be supplied on `Add`, `Get`, `Remove` actions.
* A `<message>` must be supplied on the `Add` action.

If you supply multiple `Add` actions using the same `<key>`, then the messages will be grouped together as an array. The action of `Get` for a `<key>` will remove all messages from the current session for that `<key>`.

The following is an example of adding a flash message to a session, this will add a message under the `email-error` key:

```powershell
flash add 'email-error' 'Invalid email address'
```

Then to retrieve the message, you can do this in a `route` for a `view`:

```powershell
route get '/signup' {
    view 'signup' -d @{
        'errors' = @{
            'email' = (flash get 'email-error')
        }
    }
}
```

## Views

The `view` function has a helper switch (`-FlashMessages`) to load all current flash messages in the session, into the views data - to save time writing lots of `flash get` calls. When used, all messages will be loaded into the `$data` argument supplied to dynamic views, and accessible under `$data.flash`.

For example, somewhere we could have a sign-up flow which fails validation and adds two messages to the session:

```powershell
flash add 'email-error' 'Invalid email address'
flash add 'name-error' 'No first/last name supplied'
```

Then, within your route to load the sign-up view, you can use the switch to automatically load all current flash messages (note: `-fm` is an alias of `-FlashMessages`):

```powershell
route get '/signup' {
    view -fm 'signup'
}
```

With this, the two flash messages for `email-error` and `name-error` are automatically added to a dynamic view's `$data.flash` property. You could get these back in the view, such as the snippet of a possible `signup.pode`:

```html
<html>
    <head>...</head>
    <body>
        <form action="/signup" method="post">

            <!-- The email input control -->
            <label>Email Address:</label>
            <input type="text" id="email" name="email" />

            <!-- Check if there's a flash error, and display it -->
            $(if ($data.flash['email-error']) {
                "<p class='error'>$($data.flash['email-error'])</p>"
            })
        </form>
    </body>
</html>
```

## Authentication

When doing authentication checks, normally if the check fails Pode will throw an error and return with a `401` status code. However, you can tell `auth check` calls to load these errors in the session's flash messages under an `auth-error` key. To do this, you specify the `FailureFlash` option as `$true` to the `auth check` call.

For example, here we have a login page, with the `post` login check. The check flags that any authentication errors should be loaded into the session's flash messages:

```powershell
route 'get' '/login' (auth check login -o @{ 'login' = $true; 'successUrl' = '/' }) {
    view -fm 'auth-login'
}

route 'post' '/login' (auth check login -o @{
    'failureUrl' = '/login';
    'successUrl' = '/';
    'failureFlash' = $true;
}) {}
```

Then, to load the authentication back for the user:

```html
<html>
    <head>...</head>
    <body>
        <form action="/login" method="post">
            <!-- The username control -->
            <label>Username:</label>
            <input type="text" name="username"/>

            <!-- The password control -->
            <label>Password:</label>
            <input type="password" name="password"/>
        </form>

        <!-- Check if there's a flash error, and display it -->
        $(if ($Data.flash['auth-error']) {
            "<p class='error'>$($data.flash['auth-error'])</p>"
        })

    </body>
</html>
```