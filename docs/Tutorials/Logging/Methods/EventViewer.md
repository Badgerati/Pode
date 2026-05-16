# Event Viewer

You can log items to the Windows Event Viewer, using Pode's unbuilt Event Viewer logging Method, via [`New-PodeLogEventViewerMethod`](../../../../Functions/Logging/New-PodeLogEventViewerMethod). You can log anything, but it's best to use this in conjunction with [`Enable-PodeErrorLogType`](../../../../Functions/Logging/Enable-PodeErrorLogType) and [`Write-PodeErrorLog`](../../../../Functions/Logging/Write-PodeErrorLog).

!!! note
    Errors will be logged using an appropriate error level, but other log items will be logged as Informational.

!!! important
    By default, Pode will log to the Application log with a source of Pode, and an Event ID of 0.

## Usage

When using this log method, Pode will first check if the source exists, and will then attempt to create it. To do this, you will need to be running Pode as an administrator.

If however you're running Pode locally, or in a situation where you can't run Pode as a full admin - like in IIS - then you will first have to create the source yourself manually. Assuming a source of `Pode` and in the `Application` log, you can use the following:

```powershell
[System.Diagnostics.EventLog]::CreateEventSource('Pode', 'Application')
```

Once the source is created, Pode can log to the Event Viewer without being an admin!

To enable and log errors to the Event Viewer, the following will work:

```powershell
New-PodeLogEventViewerMethod | Enable-PodeErrorLogType
```

This will log to the `Application` log using `Pode` as the source.

## Event Log

To log to a different event log, other than Application, you can specify the log via `-EventLogName`:

```powershell
New-PodeLogEventViewerMethod -EventLogName SomeLogName | Enable-PodeErrorLogType
```

## Event Source

To log using a different source, other than Pode, you can specify the source via `-Source`:

```powershell
New-PodeLogEventViewerMethod -Source WebsiteName | Enable-PodeErrorLogType
```
