# Invoke-ScriptBlock

## Description

The `Invoke-ScriptBlock` function takes a scriptblock and invokes it. You can specify arguments, and whether a value should be returned.

By default the scriptblock will have the `GetNewClosure()` method called, and will be invoked in the current scope; these can be toggled via `-NoNewClosure` and `-Scoped` respectively.

If any arguments are supplied, they will be supplied as a single argument to the scriptblock. By using the `-Splat` switch, then if the arguments are an array/hashtable they will be passed as multiple arguments instead.

## Examples

### Example 1

The following example will invoke a scriptblock outside of the current scope:

```powershell
Server {
    Invoke-ScriptBlock -Scoped {
        Write-Host 'Hello, world!'
    }
}
```

### Example 2

The following example will invoke a scriptblock, passing it arguments and returning a value:

```powershell
Server {
    $ht = @{
        'Name' = 'Bob';
        'Age' = 32;
    }

    $value = (Invoke-ScriptBlock -Arguments $ht {
        param($opts)
        return "Hello, $($opts.Name)! You're $($opts.Age) years old."
    })
}
```

### Example 3

The following example will invoke a scriptblock, passing it arguments and splatting them to the scriptblock:

```powershell
Server {
    $ht = @{
        'Name' = 'Bob';
        'Age' = 32;
    }

    Invoke-ScriptBlock -Arguments $ht -Splat {
        param($name, $age)
        Write-Host "Hello, $($name)! You're $($age) years old."
    })
}
```

## Parameters

| Name | Type | Required | Description | Default |
| ---- | ---- | -------- | ----------- | ------- |
| ScriptBlock | scriptblock | true | ... | null |
| Arguments | hashtable/array | false | ... | null |
| Scoped | switch | false | ... | false |
| Return | switch | false | ... | false |
| Splat | switch | false | ... | false |
| NoNewClosure | switch | false | ... | false |
