# Logging to File

## Setup

To start logging requests to your server into a file, you can do the following:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Endpoint *:8080 -Protocol HTTP
    logger file
}
```

This will cause Pode to create a new `/logs` directory at the root of your server, and start logging requests in file split down by day - so if you log for 7 days, you'll get 7 files.

When logging to a file, you can configure where Pode stores your logs and for how long to keep them using a hashtable. The following example will log to `D:\` and only keep logs for 3 days:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Endpoint *:8080 -Protocol HTTP
    logger file @{
        'Path' = 'D:\Logs';
        'MaxDays' = 3;
    }
}
```

!!! note
    Pode will automatically clear down logs for you if you specify a maximum number of days to keep them, otherwise they'll be kept forever.

## Options

| Name | Description | Default |
| ---- | ----------- | ------- |
| Path | A relative or absolute path to a directory that your logs should be placed | ./logs |
| MaxDays | The maximum number of days to keep logs | forever |