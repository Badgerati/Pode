# Outputs

## Variables

You can tell Pode to create variables with values when the server stops by using [`Out-PodeVariable`](../../../Functions/Utilities/Out-PodeVariable), for example:

```powershell
Out-PodeVariable -Name VariableName -Value 'Some_Variable_Value'
```

The `-Value` of the variable can be any object type, and when the server is stopped these variables will be created and available in the command line.

If you were to run the able example, this means that when the server is stopped, you will have access to a `$VariableName` variable on the CLI.
