# Logging Overview

Logging in Pode allows you to log web requests onto the terminal, into a file, or into some custom logging platform (such as LogStash or Splunk). To start logging requests to your server you use the [`logger`](../../Functions/Core/Logger) function.

!!! tip
    You can have many loggers defined, so you could log to the terminal, a file, and other custom tools - you aren't restricted to just one logger!

When logging to the terminal, or a file, Pode will write logs using [Combined Log Format](https://httpd.apache.org/docs/1.3/logs.html#combined). For custom loggers Pode will pass to your scriptblock a single argument that contains the relevant request information; this log object will look like the following:

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