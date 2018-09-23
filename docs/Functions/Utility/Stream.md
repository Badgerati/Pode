# Stream

## Description

The `stream` function allows you to use streams, utilise them, and then automatically dispose of the stream object for you.

## Examples

### Example 1

The following example opens a `StreamReader`, reads in the content of the stream, and then automatically disposes of the stream for you. The content is then placed into the `$data` variable:

```powershell
Server {
    $data = stream ([System.IO.StreamReader]::new($stream)) {
        return $args[0].ReadToEnd()
    }
}
```

## Parameters

| Name | Type | Required | Description | Default |
| ---- | ---- | -------- | ----------- | ------- |
| InputObject | IDisposable | true | A disposable object that will be used, and then disposed. This works much the same as `using` in C# .NET | null |
| ScriptBlock | scriptblock | true | The logic that will utilise the disposable stream object, of which the stream itself is passed as an argument to the scriptblock | null |
