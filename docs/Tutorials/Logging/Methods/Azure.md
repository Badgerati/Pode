# Azure

The Azure Log Method allows you to send logs to Azure Log Analytics. This Log Method uses the general [`New-PodeLogApiMethod`](../../../../Functions/Logging/New-PodeLogApiMethod) under-the-hood.

This Log Method supports 2 approaches in which to send logs to Azure:

1. The legacy Workspace approach, requiring a WorkspaceId and SharedKey.
2. The current Data Collection approach, requiring Endpoint/ImmutableId and App Registration.

## Creation

To create a new Azure Log Method use [`New-PodeLogAzureMethod`](../../../../Functions/Logging/New-PodeLogAzureMethod), and then supply the appropriate parameters depending on you approach your Log Analytics supports.

If you wish to ignore any certificate checks, you may supply `-SkipCertificateCheck`.

**Workspace**

The legacy approach requires a `-WorkspaceId`, `-SharedKey`, and `-LogType` from you Azure Analytics.

**Data Collection**

The current approach, whereby you setup Data Collection Endpoints and Rules, requires the DCE `-Endpoint`, and the DCR `-ImmutableId` and `-StreamName`.

You'll also be required to supply the `-ClientId`, `-ClientSecret`, and `-TenantId` of an App Registration with the `Monitoring Metrics Publisher` role on your DCR. This App Registration will be used to automatically generate OAuth2 access tokens, and renew them, so that Pode can send logs to your Azure Log Analytics.

Further info can be [found here](https://learn.microsoft.com/en-us/azure/azure-monitor/logs/tutorial-logs-ingestion-portal).

When sending logs via Data Collection, you can expect the top-level format of those logs to be JSON:

```json
[
    {
        "Data": "<transformed or raw log item>",
        "Level": "Error",
        "TimeGenerated": "2026-07-05T15:56:00Z",
        "Source": "Pode"
    }
]
```

### Source

The default source for your logs sent by Pode is the [Server's App Name](../../../../Basic#app-name). If you wish to supply an explicit source different from the server's, then you can do so via the `-Source` parameter.

## Examples

### Workspace

The following example will send Request logs to Azure Log Analytics using the Workspace approach.

```powershell
$method = New-PodeLogAzureMethod `
    -WorkspaceId '<workspace-id>' `
    -SharedKey '<key>' `
    -LogType 'MyCustomLog'

$method | Enable-PodeLogRequestType
```

### Data Collection

The following example will send JSON serialised Error logs to Azure Log Analytics using the Data Collection approach.

```powershell
$method = New-PodeLogAzureMethod `
    -Endpoint 'https://logs-ingestion-0000.eastus2-1.ingest.monitor.azure.com' `
    -ImmutableId 'dcr-0000000000000000000000000000000' `
    -StreamName 'Custom-Json-Test' `
    -ClientId '<client-id>' `
    -ClientSecret '<client-secret>' `
    -TenantId '<tenant-id>'

$method | Enable-PodeLogErrorType -SerialiseFormat Json
```
