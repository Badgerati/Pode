# Cookie

## Description

The `header` function allows you to add/set, get, and test headers on requests/responses.

You can use `header` to add multiple headers with the same name, or use the set action to override and set a single header.

!!! important
    When running in a serverless context (Lambda/Functions), you cannot have multiple headers with the same name

## Examples

### Example 1

The following example will add multiple headers with the same name to the response:

```powershell
header add 'Set-Cookie' 'key1=value1'
header add 'Set-Cookie' 'key2=value2'
```

### Example 2

The following example will set a single header to the response, removing any headers with the same name that may have been previously added:

```powershell
header set 'Content-Type' 'application/json'
```

### Example 3

The following example will retrieve the value of a header from the request:

```powershell
$value = (header get 'Content-Encoding')
```

### Example 4

The following example will test that a header exists on the request:

```powershell
if ((header test 'Content-Encoding')) {
    # logic
}
```

## Parameters

| Name | Type | Required | Description | Default |
| ---- | ---- | -------- | ----------- | ------- |
| Action | string | true | The action to perform on the header (Values: Add, Exists, Get, Set) | empty |
| Name | string | true | The name of the header | empty |
| Value | string | false | The value to assign to the header | empty |