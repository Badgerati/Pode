# Endware

## Description

The `endware` function allows you to add endware scripts, that run after all `middleware` and `route` logic - even if a `middleware` has ended the pipeline early. They allow you to do things like logging, further data storage, etc.

Endware in Pode allows you to observe the request/response objects at the very end of the middleware/route pipeline for a current web event. This way you will have the most up-to-date information on the objects for any logging you may wish to perform.

!!! info
    Unlike `middleware` which has a return value to halt execution, each endware will run in turn without the need for returning anything. So if there are 4 endware configured and 1 fails in the middle, the other later ones will still run.

## Examples

### Example 1

The following example is `endware` that observes the content length of the response, as well as the status code, and records them in some custom data storage for later analysis:

```powershell
Server {
    endware {
        param($event)

        $status = $event.Response.StatusCode
        $length = $event.Response.ContentLength64

        Save-ContentStatus -ContentLength $length -Status $status
    }
}
```

## Parameters

| Name | Type | Required | Description | Default |
| ---- | ---- | -------- | ----------- | ------- |
| ScriptBlock | scriptblock | true | The main logic for the endware; this scriptblock will be supplied a single parameter for the current event which contains the `Request` and `Response` objects | null |
