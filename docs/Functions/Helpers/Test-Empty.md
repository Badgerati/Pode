# Test-Empty

## Description

The `Test-Empty` function will return whether the value supplied is either `empty`, `$null` or its length is zero.

!!! tip
    The function supports virtually every type from `array` to `string`, even `scriptblock`.

!!! note
    The function will automatically return `$false` if the value is a `ValueType`, such as `float`, `int`, `bool` etc.

## Examples

### Example 1

The following example will return `$true` and run the logic because the `array` is empty:

```powershell
Server {
    if (Test-Empty @()) {
        # logic
    }
}
```

### Example 2

The following example will return `$false` and not run the logic because the `string` is not empty:

```powershell
Server {
    if (Test-Empty 'contains a value') {
        # logic
    }
}
```

### Example 3

The following example will return `$true` and run the logic because the `hashtable` is empty:

```powershell
Server {
    if (Test-Empty @{}) {
        # logic
    }
}
```

## Parameters

| Name | Type | Required | Description | Default |
| ---- | ---- | -------- | ----------- | ------- |
| Value | object | false | The value to check if it is empty, null or zero-length | null |
