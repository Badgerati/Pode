# From v0.X to v1.X

This is a brief guide on migrating from Pode v0.X to Pode v1.X.

In Pode v1.X all functions were refactored from short syntax (ie, `route`), to PowerShell syntax (ie, `Add-PodeRoute`). This means some of the older functions, such as `header` have now been split out into 4, or more, different functions.

Also being changed is the `pode.json` configuration file, which is now a `server.<env>.psd1` file.

!!! note
    With all the functions being refactored, the old syntax of not needing to supply parameter names (and relying on position) is gone - for a lot of cases. It's now worth referencing parameters by name (`-Name`, `-ScriptBlock`, etc.).

## Authentication

([Tutorial](../../../Tutorials/Authentication/Overview))

The old `auth use` has been split into two to make it easier - there are now two functions that define authentication types (which retrieve credentials from the request object), and validators (which take the credentials and ensure the user is valid).

For `auth check`, this has now been replaced with [`Get-PodeAuthMiddleware`], and the hashtable is now function parameters.

### Types

Using inbuilt authentication types, and creating custom types, is now possible use the [`New-PodeAuthType`] function. This function will return valid Basic, Form, or Custom authentication types for use with [`Add-PodeAuth`] and [`Add-PodeAuthWindowsAd`].

### Validators

Configuring an authentication validator is now a case of using the [`Add-PodeAuth`] function with a `-Name` and a `-ScriptBlock`.

For inbuilt validators, like Windows AD, you can use [`Add-PodeAuthWindowsAd`].

In both cases, the `-Type` parameter comes from using [`New-PodeAuthType`].

| Function |
| -------- |
| [`Add-PodeAuth`] |
| [`Add-PodeAuthWindowsAd`] |
| [`Remove-PodeAuth`] |
| [`Clear-PodeAuth`] |

## Cookies

Cookies use to be done via actions following the `cookie` function, such as `cookie set`. These actions are now the following functions:

| Action | Function |
| ------ | -------- |
| cookie check | [`Test-PodeCookieSigned`] |
| cookie exists | [`Test-PodeCookie`] |
| cookie extend | [`Update-PodeCookieExpiry`] |
| cookie get | [`Get-PodeCookie`] |
| cookie remove | [`Remove-PodeCookie`] |
| cookie secrets | [`Get-PodeCookieSecret`] and [`Set-PodeCookieSecret`] |
| cookie set | [`Set-PodeCookie`] |

## Configuration

([Tutorial](../../../Tutorials/Configuration))

The `config` function has simply been renamed to [`Get-PodeConfig`].

### PSD1

The `pode.<env>.json` configuration files have been changed from `json` to `psd1` format, and their name changed from `pode` to `server`.

The structure of the file name still uses the environment format: `server.<env>.psd1`.

The structure of the file itself is basically a PowerShell hashtable, so the following:

```json
{
    "server": {
        "fileMonitor": {
            "enable": true
        }
    }
}
```

would now be:

```powershell
@{
    Server = @{
        FileMonitor = @{
            Enable = $true
        }
    }
}
```

## Flash Messages

([Tutorial](../../../Tutorials/Routes/Utilities/FlashMessages))

Flash messages use to be done via actions following `flash` function, such as `flash add`. These actions are now the following functions:

| Action | Function |
| ------ | -------- |
| flash add | [`Add-PodeFlashMessage`] |
| flash clear | [`Clear-PodeFlashMessages`] |
| flash get | [`Get-PodeFlashMessage`] |
| flash keys | [`Get-PodeFlashMessageNames`] |
| flash remove | [`Remove-PodeFlashMessage`] |
| flash test | [`Test-PodeFlashMessage`] |

## GUI

([Tutorial](../../../Tutorials/Misc/DesktopApp))

The `gui` function use to take a Name with a hashtable of options. This function has now been renamed to [`Show-PodeGui`], and the options are all now function parameters.

## Handlers

([Tutorial](../../../Tutorials/SmtpServer))

The biggest change the Handlers is that you can now create multiple handlers for each of SMTP, TCP and Service - rather than just one. With this, the new [`Add-PodeHandler`] requires a `-Name` to be supplied.

| Function |
| -------- |
| [`Add-PodeHandler`] |
| [`Remove-PodeHandler`] |
| [`Clear-PodeHandlers`] |

## Headers

Headers use to be done via actions following the `header` function, such as `header add`. These actions are now the following functions:

| Action | Function |
| ------ | -------- |
| header add | [`Add-PodeHeader`] |
| header get | [`Get-PodeHeader`] |
| header set | [`Set-PodeHeader`] |
| header exists | [`Test-PodeHeader`] |

## Logging

([Tutorial](../../../Tutorials/Logging/Overview))

Logging in Pode has had by far the biggest refactor, so big it's completely different - so it may just be worth looking at the tutorial.

The old `logging` used to only support logging Requests, whereas now it can log Requests, Errors, and anything else you feel like! You can also write to a custom log using the new write function.

### Methods

Logging methods define how a log item should be logged. The inbuilt File and Terminal logging methods are now reusable, with the ability to now more easily create custom logging methods using [`New-PodeLoggingMethod`]. The output from this function can be used when enabling or adding logging types, such as with [`Add-PodeLogger`].

### Types

Request and Error logging are inbuilt logging types that can be enabled using [`Enable-PodeRequestLogging`] and [`Enable-PodeErrorLogging`]. To create a custom logger you can use the [`Add-PodeLogger`] function. In each case, the `-Method` comes from using [`New-PodeLoggingMethod`].

| Function |
| -------- |
| [`Enable-PodeRequestLogging`] |
| [`Enable-PodeErrorLogging`] |
| [`Add-PodeLogger`] |
| [`Disable-PodeRequestLogging`] |
| [`Disable-PodeErrorLogging`] |
| [`Remove-PodeLogger`] |
| [`Clear-PodeLoggers`] |

### Writing Logs

You can now write items from anywhere in your server to a custom logger, including the inbuilt Error log.

| Function |
| -------- |
| [`Write-PodeErrorLog`] |
| [`Write-PodeLog`] |

## Middleware

([Tutorial](../../../Tutorials/Middleware/Overview))

### General

Middleware has changed a fair bit, however, generally you'll just be using the [`Add-PodeMiddleware`] function with a `-ScriptBlock` which replaces the old `middleware` function. The only difference now is you're required to supply a `-Name` for the new [`Remove-PodeMiddleware`] function.

There is a new [`New-PodeMiddleware`] function which wil return a valid middleware object to re-use - such as piping into [`Add-PodeMiddleware`], or using as `-Middleware` for Routes.

| Function |
| -------- |
| [`Add-PodeMiddleware`] |
| [`New-PodeMiddleware`] |
| [`Remove-PodeMiddleware`] |
| [`Clear-PodeMiddlewares`] |

### Sessions

([Tutorial](../../../Tutorials/Middleware/Types/Sessions))

The `session` function has now been replaced by the new [`Enable-PodeSessionMiddleware`] function. With the new function, not only will it automatically enabled session middleware for you, but the old `-Options` hashtable has now been converted into proper function parameters.

### CSRF

([Tutorial](../../../Tutorials/Middleware/Types/CSRF))

The `csrf` function used to take actions that defined what it did, such as `csrf token`. Now, each of these actions has been split up into their own functions:

| Action | Function |
| ------ | -------- |
| csrf middleware | [`Enable-PodeCsrfMiddleware`] |
| csrf setup | [`Initialize-PodeCsrf`] |
| csrf check | [`Get-PodeCsrfMiddleware`] |
| csrf token | [`New-PodeCsrfToken`] |

!!! note
    Similar to the old setup, the [`Initialize-PodeCsrf`] function must be called before you can use [`Get-PodeCsrfMiddleware`] or [`New-PodeCsrfToken`]. The [`Enable-PodeCsrfMiddleware`] does automatically call [`Initialize-PodeCsrf`], as well as configure CSRF globally.

## Importing Modules/Scripts

([Tutorial](../../../Tutorials/ImportingModules))

The functions to import and load Modules, Scripts and SnapIns have all changed to the following:

| Old | Function |
| --- | -------- |
| import | [`Import-PodeModule`] and [`Import-PodeSnapIn`] |
| load | [`Use-PodeScript`] |

## Response Helpers

The old response helpers have all been updated:

| Old | Function |
| --- | -------- |
| engine | [`Set-PodeViewEngine`] |
| view | [`Write-PodeViewResponse`] |
| json | [`Write-PodeJsonResponse`] |
| text | [`Write-PodeTextResponse`] |
| xml | [`Write-PodeXmlResponse`] |
| csv | [`Write-PodeCsvResponse`] |
| html | [`Write-PodeHtmlResponse`] |
| file | [`Write-PodeFileResponse`] |
| attach | [`Set-PodeResponseAttachment`] |
| save | [`Save-PodeRequestFile`] |
| status | [`Set-PodeResponseStatus`] |
| include | [`Use-PodePartialView`] |
| redirect | [`Move-PodeResponseUrl`] |
| tcp | [`Write-PodeTcpClient`] and [`Read-PodeTcpClient`] |

## Routes

([Tutorial](../../../Tutorials/Routes/Overview))

### Normal

Normal routes defined via `route` can now be done using [`Add-PodeRoute`]. The parameters are practically the same, such as `-Method`, `-Path` and `-ScriptBlock`.

| Function |
| -------- |
| [`Add-PodeRoute`] |
| [`Remove-PodeRoute`] |
| [`Clear-PodeRoutes`] |

### Static

Static routes that used to be setup using `route static` are now setup using the new [`Add-PodeStaticRoute`].

| Function |
| -------- |
| [`Add-PodeStaticRoute`] |
| [`Remove-PodeStaticRoute`] |
| [`Clear-PodeStaticRoutes`] |

## Schedules

([Tutorial](../../../Tutorials/Schedules))

Schedules haven't changed too much, though there are now some new functions to remove and clear schedules. The main one is that `schedule` has been changed to [`Add-PodeSchedule`].

| Function |
| -------- |
| [`Add-PodeSchedule`] |
| [`Remove-PodeSchedule`] |
| [`Clear-PodeSchedules`] |

## Server

([Tutorial](../../../Tutorials/Basics))

The `server` function has had a fair overhaul. A lot of the parameters which were old/legacy have now been removed - such as `-Port`, `-IP`, and all of the `-Http` swicthes.

The `server` function itself has been renamed to [`Start-PodeServer`].

## State

([Tutorial](../../../Tutorials/SharedState))

The shared state use to be done via actions following the `state` function, such as `state set`. These actions are now the following functions:

| Action | Function |
| ------ | -------- |
| state set | [`Set-PodeState`] |
| state get | [`Get-PodeState`] |
| state remove | [`Remove-PodeState`] |
| state save | [`Save-PodeState`] |
| state restore | [`Restore-PodeState`] |
| state test | [`Test-PodeState`] |

## Timers

([Tutorial](../../../Tutorials/Timers))

Timers haven't changed too much, though there are now some new functions to remove and clear timers. The main one is that `timer` has been changed to [`Add-PodeTimer`].

| Function |
| -------- |
| [`Add-PodeTimer`] |
| [`Remove-PodeTimer`] |
| [`Clear-PodeTimers`] |
