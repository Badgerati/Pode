# From v0.X to v1.X

This is a brief guide on migrating from Pode v0.X to Pode v1.X.

In Pode v1.X all functions were refactored from short syntax (ie, `route`), to PowerShell syntax (ie, `Add-PodeRoute`). This means some of the older functions, such as `header` have now been split out into 4, or more, different functions.

Also being changed is the `pode.json` configuration file, which is now a `server.<env>.psd1` file.

!!! note
    With all the functions being refactored, the old syntax of not needing to supply parameter names (and relying on position) is gone - for a lot of cases. It's now worth referencing parameters by name (`-Name`, `-ScriptBlock`, etc.).

## Authentication

([Tutorial](../../../Tutorials/Authentication/Overview))

The old `auth use` has been split into two to make it easier - there are now functions that define authentication types (which retrieve credentials from the request object), and validators (which take the credentials and ensure the user is valid).

For `auth check`, this has now been replaced with [`Get-PodeAuthMiddleware`](../../../Functions/Authentication/Get-PodeAuthMiddleware), and the hashtable is now function parameters.

### Types

Using inbuilt authentication types, and creating custom types, is now possible use the [`New-PodeAuthType`](../../../Functions/Authentication/New-PodeAuthType) function. This function will return valid Basic, Form, or Custom authentication types for use with [`Add-PodeAuth`](../../../Functions/Authentication/Add-PodeAuth) and [`Add-PodeAuthWindowsAd`](../../../Functions/Authentication/Add-PodeAuthWindowsAd).

### Validators

Configuring an authentication validator is now a case of using the [`Add-PodeAuth`](../../../Functions/Authentication/Add-PodeAuth) function with a `-Name` and a `-ScriptBlock`.

For inbuilt validators, like Windows AD, you can use [`Add-PodeAuthWindowsAd`](../../../Functions/Authentication/Add-PodeAuthWindowsAd).

In both cases, the `-Type` parameter comes from using [`New-PodeAuthType`](../../../Functions/Authentication/New-PodeAuthType).

| Functions |
| -------- |
| [`Add-PodeAuth`](../../../Functions/Authentication/Add-PodeAuth) |
| [`Add-PodeAuthWindowsAd`](../../../Functions/Authentication/Add-PodeAuthWindowsAd) |
| [`Remove-PodeAuth`](../../../Functions/Authentication/Remove-PodeAuth) |
| [`Clear-PodeAuth`](../../../Functions/Authentication/Clear-PodeAuth) |

## Cookies

Cookies use to be done via actions following the `cookie` function, such as `cookie set`. These actions are now the following functions:

| Action | Function |
| ------ | -------- |
| cookie check | [`Test-PodeCookieSigned`](../../../Functions/Cookies/Test-PodeCookieSigned) |
| cookie exists | [`Test-PodeCookie`](../../../Functions/Cookies/Test-PodeCookie) |
| cookie extend | [`Update-PodeCookieExpiry`](../../../Functions/Cookies/Update-PodeCookieExpiry) |
| cookie get | [`Get-PodeCookie`](../../../Functions/Cookies/Get-PodeCookie) |
| cookie remove | [`Remove-PodeCookie`](../../../Functions/Cookies/Remove-PodeCookie) |
| cookie secrets | [`Get-PodeCookieSecret`](../../../Functions/Cookies/Get-PodeCookieSecret) and [`Set-PodeCookieSecret`](../../../Functions/Cookies/Set-PodeCookieSecret) |
| cookie set | [`Set-PodeCookie`](../../../Functions/Cookies/Set-PodeCookie) |

## Configuration

([Tutorial](../../../Tutorials/Configuration))

The `config` function has simply been renamed to [`Get-PodeConfig`](../../../Functions/Utilities/Get-PodeConfig).

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
| flash add | [`Add-PodeFlashMessage`](../../../Functions/Flash/Add-PodeFlashMessage) |
| flash clear | [`Clear-PodeFlashMessages`](../../../Functions/Flash/Clear-PodeFlashMessages) |
| flash get | [`Get-PodeFlashMessage`](../../../Functions/Flash/Get-PodeFlashMessage) |
| flash keys | [`Get-PodeFlashMessageNames`](../../../Functions/Flash/Get-PodeFlashMessageNames) |
| flash remove | [`Remove-PodeFlashMessage`](../../../Functions/Flash/Remove-PodeFlashMessage) |
| flash test | [`Test-PodeFlashMessage`](../../../Functions/Flash/Test-PodeFlashMessage) |

## GUI

([Tutorial](../../../Tutorials/Misc/DesktopApp))

The `gui` function use to take a Name with a hashtable of options. This function has now been renamed to [`Show-PodeGui`](../../../Functions/Core/Show-PodeGui), and the options are all now function parameters.

## Handlers

([Tutorial](../../../Servers/SMTP))

The biggest change the Handlers is that you can now create multiple handlers for each of SMTP, TCP and Service - rather than just one. With this, the new [`Add-PodeHandler`](../../../Functions/Handlers/Add-PodeHandler) requires a `-Name` to be supplied.

| Functions |
| -------- |
| [`Add-PodeHandler`](../../../Functions/Handlers/Add-PodeHandler) |
| [`Remove-PodeHandler`](../../../Functions/Handlers/Remove-PodeHandler) |
| [`Clear-PodeHandlers`](../../../Functions/Handlers/Clear-PodeHandlers) |

## Headers

Headers use to be done via actions following the `header` function, such as `header add`. These actions are now the following functions:

| Action | Function |
| ------ | -------- |
| header add | [`Add-PodeHeader`](../../../Functions/Headers/Add-PodeHeader) |
| header get | [`Get-PodeHeader`](../../../Functions/Headers/Get-PodeHeader) |
| header set | [`Set-PodeHeader`](../../../Functions/Headers/Set-PodeHeader) |
| header exists | [`Test-PodeHeader`](../../../Functions/Headers/Test-PodeHeader) |

## Logging

([Tutorial](../../../Tutorials/Logging/Overview))

Logging in Pode has had by far the biggest refactor, so big it's completely different - so it may just be worth looking at the tutorial.

The old `logging` used to only support logging Requests, whereas now it can log Requests, Errors, and anything else you feel like! You can also write to a custom log using the new write function.

### Methods

Logging methods define how a log item should be logged. The inbuilt File and Terminal logging methods are now reusable, with the ability to now more easily create custom logging methods using [`New-PodeLoggingMethod`](../../../Functions/Logging/New-PodeLoggingMethod). The output from this function can be used when enabling or adding logging types, such as with [`Add-PodeLogger`](../../../Functions/Logging/Add-PodeLogger).

### Types

Request and Error logging are inbuilt logging types that can be enabled using [`Enable-PodeRequestLogging`](../../../Functions/Logging/Enable-PodeRequestLogging) and [`Enable-PodeErrorLogging`](../../../Functions/Logging/Enable-PodeErrorLogging). To create a custom logger you can use the [`Add-PodeLogger`](../../../Functions/Logging/Add-PodeLogger) function. In each case, the `-Method` comes from using [`New-PodeLoggingMethod`](../../../Functions/Logging/New-PodeLoggingMethod).

| Functions |
| -------- |
| [`Enable-PodeRequestLogging`](../../../Functions/Logging/Enable-PodeRequestLogging) |
| [`Enable-PodeErrorLogging`](../../../Functions/Logging/Enable-PodeErrorLogging) |
| [`Add-PodeLogger`](../../../Functions/Logging/Add-PodeLogger) |
| [`Disable-PodeRequestLogging`](../../../Functions/Logging/Disable-PodeRequestLogging) |
| [`Disable-PodeErrorLogging`](../../../Functions/Logging/Disable-PodeErrorLogging) |
| [`Remove-PodeLogger`](../../../Functions/Logging/Remove-PodeLogger) |
| [`Clear-PodeLoggers`](../../../Functions/Logging/Clear-PodeLoggers) |

### Writing Logs

You can now write items from anywhere in your server to a custom logger, including the inbuilt Error log.

| Functions |
| -------- |
| [`Write-PodeErrorLog`](../../../Functions/Logging/Write-PodeErrorLog) |
| [`Write-PodeLog`](../../../Functions/Logging/Write-PodeLog) |

## Middleware

([Tutorial](../../../Tutorials/Middleware/Overview))

### General

Middleware has changed a fair bit, however, generally you'll just be using the [`Add-PodeMiddleware`](../../../Functions/Middleware/Add-PodeMiddleware) function with a `-ScriptBlock` which replaces the old `middleware` function. The only difference now is you're required to supply a `-Name` for the new [`Remove-PodeMiddleware`](../../../Functions/Middleware/Remove-PodeMiddleware) function.

There is a new [`New-PodeMiddleware`](../../../Functions/Middleware/New-PodeMiddleware) function which wil return a valid middleware object to re-use - such as piping into [`Add-PodeMiddleware`](../../../Functions/Middleware/Add-PodeMiddleware), or using as `-Middleware` for Routes.

| Functions |
| -------- |
| [`Add-PodeMiddleware`](../../../Functions/Middleware/Add-PodeMiddleware) |
| [`New-PodeMiddleware`](../../../Functions/Middleware/New-PodeMiddleware) |
| [`Remove-PodeMiddleware`](../../../Functions/Middleware/Remove-PodeMiddleware) |
| [`Clear-PodeMiddlewares`](../../../Functions//Clear-PodeMiddlewares) |

### Sessions

([Tutorial](../../../Tutorials/Middleware/Types/Sessions))

The `session` function has now been replaced by the new [`Enable-PodeSessionMiddleware`](../../../Functions/Middleware/Enable-PodeSessionMiddleware) function. With the new function, not only will it automatically enabled session middleware for you, but the old `-Options` hashtable has now been converted into proper function parameters.

### CSRF

([Tutorial](../../../Tutorials/Middleware/Types/CSRF))

The `csrf` function used to take actions that defined what it did, such as `csrf token`. Now, each of these actions has been split up into their own functions:

| Action | Function |
| ------ | -------- |
| csrf middleware | [`Enable-PodeCsrfMiddleware`](../../../Functions/Middleware/Enable-PodeCsrfMiddleware) |
| csrf setup | [`Initialize-PodeCsrf`](../../../Functions/Middleware/Initialize-PodeCsrf) |
| csrf check | [`Get-PodeCsrfMiddleware`](../../../Functions/Middleware/Get-PodeCsrfMiddleware) |
| csrf token | [`New-PodeCsrfToken`](../../../Functions/Middleware/New-PodeCsrfToken) |

!!! note
    Similar to the old setup, the [`Initialize-PodeCsrf`](../../../Functions/Middleware/Initialize-PodeCsrf) function must be called before you can use [`Get-PodeCsrfMiddleware`](../../../Functions/Middleware/Get-PodeCsrfMiddleware) or [`New-PodeCsrfToken`](../../../Functions/Middleware/New-PodeCsrfToken). The [`Enable-PodeCsrfMiddleware`](../../../Functions/Middleware/Enable-PodeCsrfMiddleware) does automatically call [`Initialize-PodeCsrf`](../../../Functions/Middleware/Initialize-PodeCsrf)  as well as configure CSRF globally.

## Importing Modules/Scripts

([Tutorial](../../../Tutorials/ImportingModules))

The functions to import and load Modules, Scripts and SnapIns have all changed to the following:

| Old | Function |
| --- | -------- |
| import | [`Import-PodeModule`](../../../Functions/Utilities/Import-PodeModule) and [`Import-PodeSnapIn`](../../../Functions/Utilities/Import-PodeSnapIn) |
| load | [`Use-PodeScript`](../../../Functions/Utilities/Use-PodeScript) |

## Response Helpers

The old response helpers have all been updated:

| Old | Function |
| --- | -------- |
| engine | [`Set-PodeViewEngine`](../../../Functions/Responses/Set-PodeViewEngine) |
| view | [`Write-PodeViewResponse`](../../../Functions/Responses/Write-PodeViewResponse) |
| json | [`Write-PodeJsonResponse`](../../../Functions/Responses/Write-PodeJsonResponse) |
| text | [`Write-PodeTextResponse`](../../../Functions/Responses/Write-PodeTextResponse) |
| xml | [`Write-PodeXmlResponse`](../../../Functions/Responses/Write-PodeXmlResponse) |
| csv | [`Write-PodeCsvResponse`](../../../Functions/Responses/Write-PodeCsvResponse) |
| html | [`Write-PodeHtmlResponse`](../../../Functions/Responses/Write-PodeHtmlResponse) |
| file | [`Write-PodeFileResponse`](../../../Functions/Responses/Write-PodeFileResponse) |
| attach | [`Set-PodeResponseAttachment`](../../../Functions/Responses/Set-PodeResponseAttachment) |
| save | [`Save-PodeRequestFile`](../../../Functions/Responses/Save-PodeRequestFile) |
| status | [`Set-PodeResponseStatus`](../../../Functions/Responses/Set-PodeResponseStatus) |
| include | [`Use-PodePartialView`](../../../Functions/Responses/Use-PodePartialView) |
| redirect | [`Move-PodeResponseUrl`](../../../Functions/Responses/Move-PodeResponseUrl) |
| tcp | [`Write-PodeTcpClient`](../../../Functions/Responses/Write-PodeTcpClient) and [`Read-PodeTcpClient`](../../../Functions/Responses/Read-PodeTcpClient) |

## Routes

([Tutorial](../../../Tutorials/Routes/Overview))

### Normal

Normal routes defined via `route` can now be done using [`Add-PodeRoute`](../../../Functions/Routes/Add-PodeRoute). The parameters are practically the same, such as `-Method`, `-Path` and `-ScriptBlock`.

| Functions |
| -------- |
| [`Add-PodeRoute`](../../../Functions/Routes/Add-PodeRoute) |
| [`Remove-PodeRoute`](../../../Functions/Routes/Remove-PodeRoute) |
| [`Clear-PodeRoutes`](../../../Functions/Routes/Clear-PodeRoutes) |

### Static

Static routes that used to be setup using `route static` are now setup using the new [`Add-PodeStaticRoute`](../../../Functions/Routes/Add-PodeStaticRoute).

| Functions |
| -------- |
| [`Add-PodeStaticRoute`](../../../Functions/Routes/Add-PodeStaticRoute) |
| [`Remove-PodeStaticRoute`](../../../Functions/Routes/Remove-PodeStaticRoute) |
| [`Clear-PodeStaticRoutes`](../../../Functions/Routes/Clear-PodeStaticRoutes) |

## Schedules

([Tutorial](../../../Tutorials/Schedules))

Schedules haven't changed too much, though there are now some new functions to remove and clear schedules. The main one is that `schedule` has been changed to [`Add-PodeSchedule`](../../../Functions/Schedules/Add-PodeSchedule).

| Functions |
| -------- |
| [`Add-PodeSchedule`](../../../Functions/Schedules/Add-PodeSchedule) |
| [`Remove-PodeSchedule`](../../../Functions/Schedules/Remove-PodeSchedule) |
| [`Clear-PodeSchedules`](../../../Functions/Schedules/Clear-PodeSchedules) |

## Server

([Tutorial](../../../Tutorials/Basics))

The `server` function has had a fair overhaul. A lot of the parameters which were old/legacy have now been removed - such as `-Port`, `-IP`, and all of the `-Http` swicthes.

The `server` function itself has been renamed to [`Start-PodeServer`](../../../Functions/Core/Start-PodeServer).

## State

([Tutorial](../../../Tutorials/SharedState))

The shared state use to be done via actions following the `state` function, such as `state set`. These actions are now the following functions:

| Action | Function |
| ------ | -------- |
| state set | [`Set-PodeState`](../../../Functions/State/Set-PodeState) |
| state get | [`Get-PodeState`](../../../Functions/State/Get-PodeState) |
| state remove | [`Remove-PodeState`](../../../Functions/State/Remove-PodeState) |
| state save | [`Save-PodeState`](../../../Functions/State/Save-PodeState) |
| state restore | [`Restore-PodeState`](../../../Functions/State/Restore-PodeState) |
| state test | [`Test-PodeState`](../../../Functions/State/Test-PodeState) |

## Timers

([Tutorial](../../../Tutorials/Timers))

Timers haven't changed too much, though there are now some new functions to remove and clear timers. The main one is that `timer` has been changed to [`Add-PodeTimer`](../../../Functions/Timers/Add-PodeTimer).

| Functions |
| -------- |
| [`Add-PodeTimer`](../../../Functions/Timers/Add-PodeTimer) |
| [`Remove-PodeTimer`](../../../Functions/Timers/Remove-PodeTimer) |
| [`Clear-PodeTimers`](../../../Functions/Timers/Clear-PodeTimers) |
