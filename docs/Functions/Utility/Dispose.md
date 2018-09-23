# Dispose

## Description

The `dispose` function takes a disposable object and will optionally close the object, and then dispose of the object.

## Examples

### Example 1

The following example takes a `StreamReader`, and then closes and disposes of the object:

```powershell
Server {
    $reader = [System.IO.StreamReader]::new($stream)

    # logic that uses the reader

    dispose $reader -close
}
```

## Parameters

| Name | Type | Required | Description | Default |
| ---- | ---- | -------- | ----------- | ------- |
| InputObject | IDisposable | true | A disposable object that will be optionally closed, and then disposed | null |
| Close | switch | false | If passed, the object will first be closed before being disposed | false |
| CheckNetwork | switch | false | If passed, any exceptions thrown will be checked; if they are one of the validated network errors the exception will be ignored | false |

!!! info
    The network errors ignored by the `-CheckNetwork` flag are:

    * `network name is no longer available`
    * `nonexistent network connection`
    * `broken pipe`