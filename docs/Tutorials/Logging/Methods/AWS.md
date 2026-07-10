# AWS

The AWS Log Method allows you to send logs to AWS CloudWatch. This Log Method uses the general [`New-PodeLogApiMethod`](../../../../Functions/Logging/New-PodeLogApiMethod) under-the-hood.

## Creation

To create a new AWS Log Method use [`New-PodeLogAwsMethod`](../../../../Functions/Logging/New-PodeLogAwsMethod), and supply the `-LogGroupName`, `-LogStreamName`, and `-Region` parameters. You'll also need to supply a Bearer `-Token` for authentication.

If you wish to ignore any certificate checks, you may supply `-SkipCertificateCheck`.

### Source Type

The default source type sent by Pode is empty, allowing AWS to automatically select the best fit. However, if you wish to supply an explicit source type you can do so via the `-SourceType` parameter.

### Source

The default source for your logs sent by Pode is the [Server's App Name](../../../../Basic#app-name). If you wish to supply an explicit source different from the server's, then you can do so via the `-Source` parameter.

### Index

The default index supplied by Pode is empty, which usually equates to the main index in AWS. However, if you wish to supply an explicit index you can do so via the `-Index` parameter.

## Examples

### Send Request Logs

The following example will send Request logs to AWS CloudWatch.

```powershell
$method = New-PodeLogAwsMethod `
    -LogGroupName 'my-log-group' `
    -LogStreamName 'my-log-stream' `
    -Region 'us-east-1' `
    -Token '<token>'

$method | Enable-PodeLogRequestType
```

### Send Error Logs

The following example will send JSON serialised Error logs to Aws CloudWatch.

```powershell
$method = New-PodeLogAwsMethod `
    -LogGroupName 'my-log-group' `
    -LogStreamName 'my-log-stream' `
    -Region 'us-east-1' `
    -Token '<token>'

$method | Enable-PodeLogErrorType -SerialiseFormat Json
```
