# Logger

## Description

The `logger` function allows you to define inbuilt/custom log tools within your server that will send [Combined Log Format](https://httpd.apache.org/docs/1.3/logs.html#combined) rows to either the terminal, a file, or a custom script that will allow you to log to a variety of services - e.g. Splunk/FluentD/LogStash.

When logging to a file, you can specify a custom path to create the log files, as well as a defined number of days to keep the log files.

## Examples

### Example 1

The following example will log web events to the terminal:

```powershell
Start-PodeServer {
    logger terminal
}
```

### Example 2

The following example will log web events to a file. The log files will be placed at `c:\logs` (default is `/logs` at the root), and will be split down by day; they will also only be kept for 7 days (default is forever) - any log file older than 7 days will automatically be deleted:

```powershell
Start-PodeServer {
    logger file @{
        'Path' = 'c:/logs/';
        'MaxDays' = 7;
    }
}
```

!!! info
    The `hashtable` supplied to `logger file` is optional. If no `Path` is supplied then a `/logs` directory will be created at the server script root path, and if `MaxDays` is <= 0 then the log files will be kept forever.

### Example 3

The following example will create a custom log tool that outputs the request method/resource to the terminal. For custom loggers a scriptblock *must* be supplied - the script will be supplied a single argument, which is a log object contains details of the request/response:

```powershell
Start-PodeServer {
    logger -c terminal {
        param($obj)

        $method = $obj.Log.Request.Method
        $resource = $obj.Log.Request.Resource

        "[$($method)] $($resource)" | Out-Default
    }
}
```

The `.Log` object will have the following structure:

```powershell
@{
    'Host' = '10.10.0.3';
    'RfcUserIdentity' = '-';
    'User' = '-';
    'Date' = '14/Jun/2018:20:23:52 +01:00';
    'Request' = @{
        'Method' = 'GET';
        'Resource' = '/api/users';
        'Protocol' = "HTTP/1.1";
        'Referrer' = '-';
        'Agent' = '<user-agent>';
    };
    'Response' = @{
        'StatusCode' = '200';
        'StautsDescription' = 'OK'
        'Size' = '9001';
    };
}
```

## Parameters

| Name | Type | Required | Description | Default |
| ---- | ---- | -------- | ----------- | ------- |
| Name | string | true | The name of the logger; inbuilt loggers are `terminal` and `file`. Custom loggers can have any name, but the `-Custom` switch must be supplied | empty |
| Details | object | false | For inbuilt loggers this should be a `hashtable`. For custom loggers this should be the custom `scriptblock` to define how the logger works | null |
| Custom | switch | false | When supplied, will configure the logger defined as being custom | false |
