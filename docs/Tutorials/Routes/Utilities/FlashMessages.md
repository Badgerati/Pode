# Flash Messages

Flash messages allow you to pass temporary messages - info/error or otherwise - across multiple web requests via a user's current session.

For example, in sign-up logic you could set a flash error message for an invalid email address; retrieving the message from the session on a redirect for the view, allowing the view to render error messages.

!!! Important
    To use flash messages you need to have [`Session Middleware`](../../../Middleware/Sessions) enabled.

## Usage

The flash functions allow you to add, get, and remove messages on a user's session.

If you call `Add-PodeFlashMessage` using the same Name multiple times, then the messages will be appended as an array. Calling `Get-PodeFlashMessage` for a Name will remove all messages from the current session for the Name supplied.

The following is an example of adding a flash message to a session, this will add a message under the `email-error` key:

```powershell
Add-PodeFlashMessage -Name 'email-error' -Message 'Invalid email address'
```

Then to retrieve the message, you can do this in a Route for a View:

```powershell
Add-PodeRoute -Method Get -Path '/signup' -ScriptBlock {
    Write-PodeViewResponse -Path 'signup' -Data @{
        Errors = @{
            Email = (Get-PodeFlashMessage -Name 'email-error')
        }
    }
}
```

## Views

The `Write-PodeViewResponse` function has a helper switch (`-FlashMessages`) to load all current flash messages in the session, into the views data - to save time writing lots of `Get-PodeFlashMessage` calls. When used, all messages will be loaded into the `$data` argument supplied to dynamic views, and accessible under `$data.flash`.

For example, somewhere we could have a sign-up flow which fails validation and adds two messages to the session:

```powershell
Add-PodeFlashMessage -Name 'email-error' -Message 'Invalid email address'
Add-PodeFlashMessage -Name 'name-error' -Message 'No first/last name supplied'
```

Then, within your route to load the sign-up view, you can use the switch to automatically load all current flash messages:

```powershell
Add-PodeRoute -Method Get -Path '/signup' -ScriptBlock {
    Write-PodeViewResponse 'signup' -FlashMessages
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

When doing authentication checks, normally if the check fails Pode will throw an error and return with a `401` status code. However, you can tell `Get-PodeAuthMiddleware` to load these errors in the Session's Flash messages under an `auth-error` key. To do this, you specify the `-EnableFlash` switch.

For example, here we have a login page, with the `POST` login check. The check flags that any authentication errors should be loaded into the session's flash messages:

```powershell
$auth_login = Get-PodeAuthMiddleware -Name 'Login' -AutoLogin -SuccessUrl '/'
Add-PodeRoute -Method Get -Path '/login' -Middleware $auth_login -ScriptBlock {
    Write-PodeViewResponse -Path 'auth-login' -FlashMessages
}

Add-PodeRoute -Method Post -Path '/login' -Middleware (Get-PodeAuthMiddleware `
    -Name 'Login' `
    -FailureUrl '/login' `
    -SuccessUrl '/' `
    -EnableFlash)
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
