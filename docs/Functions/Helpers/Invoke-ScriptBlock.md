# Invoke-PodeScriptBlock

## Description

The `Invoke-PodeScriptBlock` function takes a scriptblock and invokes it. You can specify arguments to pass to the script, and whether a value should be returned.

By default the scriptblock will have the `GetNewClosure()` method called, and will be invoked in the current scope; these can be toggled via `-NoNewClosure` and `-Scoped` respectively.

If any arguments are supplied, they will be supplied as a single argument to the scriptblock. By using the `-Splat` switch, then if the arguments are an array/hashtable they will be passed as multiple arguments instead.

## Examples

### Example 1

The following example will invoke a scriptblock outside of the current scope:

```powershell
Start-PodeServer {
    Invoke-PodeScriptBlock -Scoped {
        Write-Host 'Hello, world!'
    }
}
```

### Example 2

The following example will invoke a scriptblock, passing it arguments and returning a value:

```powershell
Start-PodeServer {
    $ht = @{
        'Name' = 'Bob';
        'Age' = 32;
    }

    $value = (Invoke-PodeScriptBlock -Arguments $ht -Return {
        param($opts)
        return "Hello, $($opts.Name)! You're $($opts.Age) years old."
    })
}
```

### Example 3

The following example will invoke a scriptblock, passing it arguments and splatting them to the scriptblock:

```powershell
Start-PodeServer {
    $ht = @{
        'Name' = 'Bob';
        'Age' = 32;
    }

    Invoke-PodeScriptBlock -Arguments $ht -Splat {
        param($name, $age)
        Write-Host "Hello, $($name)! You're $($age) years old."
    })
}
```

## Parameters

| Name | Type | Required | Description | Default |
| ---- | ---- | -------- | ----------- | ------- |
| ScriptBlock | scriptblock | true | The script to be invoked | null |
| Arguments | hashtable/array | false | Any arguments that need to be passed to the script | null |
| Scoped | switch | false | If passed, the script will be invoked within its own scope; otherwise it will be invoked within the current scope | false |
| Return | switch | false | If passed, will attempt to return any value from the script; otherwise nothing is returned, even if the script returns a value | false |
| Splat | switch | false | If passed, the arguments array/hastable will be split-up and passed as mutliple arguments; otherwise it will be passed as a single argument | false |
| NoNewClosure | switch | false | If passed, the script will not have its `GetNewClosure()` method called | false |
