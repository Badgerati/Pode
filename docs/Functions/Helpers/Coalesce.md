# Coalesce

## Description

The `coalesce` function will return the first argument if it's not `$null` or `empty`, otherwise the second argument is returned.

## Examples

### Example 1

The following example will use the second value and output `Hello!`, because the first is `$null`:

```powershell
Server {
    $msg = (coalesce $null 'Hello!')
    Write-Host $msg
}
```

## Parameters

| Name | Type | Required | Description | Default |
| ---- | ---- | -------- | ----------- | ------- |
| Value1 | object | false | The first value to check if it's `$null` | null |
| Value2 | object | false | The second value to use if the first is `$null` | null |
