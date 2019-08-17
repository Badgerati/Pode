# From v0.X to v1.X

This is a brief guide on migrating from Pode v0.X to Pode v1.X.

In Pode v1.X all functions were refactored from short syntax (ie, `route`), to PowerShell syntax (ie, `Add-PodeRoute`). This means some of the older functions, such as `header` have now been split output into 4, or more, different functions.

Also being changed is the `pode.json` configuration file, which is now a `server.<env>.psd1` file.

## Authentication

### Types

### Validators

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

The `gui` function use to take a Name with a hashtable of options. This function has now been renamed to [`Show-PodeGui`], and the options are all now function parameters.

## Handlers

## Headers

Headers use to be done via actions following the `header` function, such as `header add`. These actions are now the following functions:

| Action | Function |
| ------ | -------- |
| header add | [`Add-PodeHeader`] |
| header get | [`Get-PodeHeader`] |
| header set | [`Set-PodeHeader`] |
| header exists | [`Test-PodeHeader`] |

## Logging

### Methods

### Types

## Middleware

### General

### Sessions

### CSRF

## Importing Modules/Scripts

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

### Normal

### Static

## Schedules

Schedules haven't changed too much, though there are now some new functions to remove and clear schedules. The main one is that `schedule` has been changed to [`Add-PodeSchedule`].

| Function |
| -------- |
| [`Add-PodeSchedule`] |
| [`Remove-PodeSchedule`] |
| [`Clear-PodeSchedules`] |

## Server

The `server` function has had a fair overhaul. A lot of the parameters which were old/legacy have now been removed - such as `-Port`, `-IP`, and all of the `-Http` swicthes.

The `server` function itself has been renamed to [`Start-PodeServer`].

## State

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

Timers haven't changed too much, though there are now some new functions to remove and clear timers. The main one is that `timer` has been changed to [`Add-PodeTimer`].

| Function |
| -------- |
| [`Add-PodeTimer`] |
| [`Remove-PodeTimer`] |
| [`Clear-PodeTimers`] |
