# Custom Logging

Sometimes you don't want to log to a file, or the terminal; instead you want to log to something better, like LogStash, Splunk, or any other central logging platform. Although Pode doesn't have these inbuilt (yet!) it is possible to create a custom `logger`, where you define a scriptblock with logic to send logs to these platforms.

## Setup

To create a custom logger you need to supply a scriptblock to the `logger` function, as well as the `-Custom` (`-c`) flag. The following example will output the web request method/resource to the terminal; the scriptblock will be supplied a single argument that has a log object which contains details of the request/response:

```powershell
Server {
    listen *:8080 http

    logger -c terminal {
        param($event)

        $method = $event.Log.Request.Method
        $resource = $event.Log.Request.Resource

        "[$($method)] $($resource)" | Out-Default
    }
}
```

The object supplied to the scriptblock will have a `.Log` object, which will look something similar to the below hashtable:

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