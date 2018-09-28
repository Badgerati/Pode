# Lock

## Description

The `lock` function takes an object that will be locked so that it is threadsafe. The supplied ScriptBlock will be invoked within the scope of the locked object.

!!! tip
    The session object supplied to a `route`, `timer`, `schedule` and `logger` each contain a `.Lockable` resource that can be supplied to the `lock` function.

## Examples

### Example 1

The following example will lock an object, and increment a counter on the session and write it to the response in a threadsafe scope:

```powershell
Server {
    listen *:8080 http

    route get '/count' {
        param($s)

        lock $s.Lockable {
            $s.Session.Data.Views++
            json @{ 'Views' = $s.Session.Data.Views }
        }
    }
}
```

## Parameters

| Name | Type | Required | Description | Default |
| ---- | ---- | -------- | ----------- | ------- |
| InputObject | object | true | The object to lock, so that it is threadsafe within the supplied ScriptBlock | null |
| ScriptBlock | scriptblock | true | The logic that will utilise the locked object | null |
