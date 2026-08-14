# Event Viewer

You can log items to the Windows Event Viewer, using Pode's unbuilt Event Viewer Log Method, via [`New-PodeLogEventViewerMethod`](../../../../Functions/Logging/New-PodeLogEventViewerMethod). You can log anything, but it's best to use this in conjunction with [`Enable-PodeLogErrorType`](../../../../Functions/Logging/Enable-PodeLogErrorType) and [`Write-PodeErrorLog`](../../../../Functions/Logging/Write-PodeErrorLog).

!!! note
    Errors will be logged using an appropriate error level, but other log items will be logged as Informational.

!!! important
    By default, Pode will log to the Application log with a source of Pode, and an Event ID of 0.

!!! important
    The `New-PodeLoggingMethod` function is now deprecated, please use [`New-PodeLogEventViewerMethod`](../../../../Functions/Logging/New-PodeLogEventViewerMethod) instead.

## Usage

When using this Log Method, Pode will first check if the source exists, and will then attempt to create it. To do this, you will need to be running Pode as an administrator.

If however you're running Pode locally, or in a situation where you can't run Pode as a full admin - like in IIS - then you will first have to create the source yourself manually. Assuming a source of `Pode` and in the `Application` log, you can use the following:

```powershell
[System.Diagnostics.EventLog]::CreateEventSource('Pode', 'Application')
```

Once the source is created, Pode can log to the Event Viewer without being an admin!

To enable and log errors to the Event Viewer, the following will work:

```powershell
New-PodeLogEventViewerMethod | Enable-PodeLogErrorType
```

This will log to the `Application` log using `Pode` as the source.

## Event Log

To log to a different event log, other than Application, you can specify the log via `-EventLogName`:

```powershell
New-PodeLogEventViewerMethod -EventLogName SomeLogName | Enable-PodeLogErrorType
```

## Event Source

To log using a different source, other than Pode, you can specify the source via `-Source`:

```powershell
New-PodeLogEventViewerMethod -Source WebsiteName | Enable-PodeLogErrorType
```

## Override

You can use [`New-PodeLogEventViewerOverride`](../../../../Functions/Logging/New-PodeLogEventViewerOverride) to override certain properties of the Event Viewer Log Method, when calling either [`Write-PodeErrorLog`](../../../../Functions/Logging/Write-PodeErrorLog) or [`Write-PodeLog`](../../../../Functions/Logging/Write-PodeLog).

You can override the `-EventID`, as well as specify `-Ignore`, which allows you to specify that certain log items will not be logged to Event Viewer.

If you don't specify an `-Id` then the override will apply to all Event Viewer Log Methods configured for a Log Type.

```powershell
# override the Event ID when logging to Event Viewer
$_ | Write-PodeErrorLog -Override @(
    New-PodeLogEventViewerOverride -EventId 1337
)

# if you have an error log method configured with event viewer and terminal logging,
# the below will only log the error to the terminal and ignore logging to event viewer
$_ | Write-PodeErrorLog -Override @(
    New-PodeLogEventViewerOverride -Ignore
)
```
