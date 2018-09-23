# Stopwatch

## Description

The `stopwatch` function lets you wrap logic in a scriptblock, and have the amount of time the logic took to execute outputted to the CLI.

## Examples

### Example 1

The following example will wrap a `stopwatch` around reading in files and converting them to JSON:

```powershell
Server {
    stopwatch 'files' {
        Get-ChildItem 'c:/temp/*.json' | Foreach-Object {
            $content = Get-Content -Raw $_
            $json = $content | ConvertFrom-Json
        }
    }
}
```

The above will run, and output something similar to the below, on the CLI:

```
[Stopwatch]: 00:00:08.136788 [files]
```

## Parameters

| Name | Type | Required | Description | Default |
| ---- | ---- | -------- | ----------- | ------- |
| Name | string | true | The name of the logic the stopwatch is wrapped around | empty |
| ScriptBlock | scriptblock | true | The logic the stopwatch should time | null |
