# Scoped Variables

You can create custom Scoped Variables within Pode, to allow for easier/quicker access to values without having to supply function calls every time within ScriptBlocks - such as those supplied to Routes, Middleware, etc.

For example, the inbuilt `$state:` Scoped Variable is a quick way of calling `Get-PodeState` and `Set-PodeState`, but without having to write out those functions constantly!

Pode has support for the following inbuilt Scoped Variables:

* `$cache:`
* `$secret:`
* `$session:`
* `$state:`
* `$using:`

The `$using:` Scoped Variable is a special case, as it only allows for the retrieval of a value, and not the setting of the value as well.

## Creation

To create a custom Scoped Variable you can use [`Add-PodeScopedVariable`](../../Functions/ScopedVariables/Add-PodeScopedVariable) with a unique Name. There are two ways to add a Scoped Variable:

* A [simple](#simple-replace) Replacement conversion from `$var:` syntax to Get/Set function syntax.
* A more [advanced](#advanced) conversion strategy using a ScriptBlock.

### Simple Replace

The simple Replacement conversion using [`Add-PodeScopedVariable`](../../Functions/ScopedVariables/Add-PodeScopedVariable) requires you to supply a `-GetReplace` and an optional `-SetReplace` template strings. These template strings will be used appropriately replace `$var:` calls with the template Get/Set function calls.

Within the template strings there is a special placeholder, `{{name}}`, which can be used. This placeholder is where the "name" from `$var:<name>` will be used within the Get/Set replacement.

Using the inbuilt `$state` Scoped Variable as an example, this conversion is done using the Get/Set replacement method. For this Scoped Variable we want:

```powershell
$value = $state:Name
# to be replaced with
$value = (Get-PodeState -Name 'Name')

$state:Name = 'Value'
# to be replace with
Set-PodeState -Name 'Name' -Value 'Value'
```

to achieve this, we can call [`Add-PodeScopedVariable`](../../Functions/ScopedVariables/Add-PodeScopedVariable) as follows:

```powershell
Add-PodeScopedVariable -Name 'state' `
    -SetReplace "Set-PodeState -Name '{{name}}' -Value " `
    -GetReplace "Get-PodeState -Name '{{name}}'"
```

### Advanced

A more advanced conversion can be achieved using [`Add-PodeScopedVariable`](../../Functions/ScopedVariables/Add-PodeScopedVariable) by supplying a `-ScriptBlock` instead of the Replace parameters. This ScriptBlock will be supplied with:

* The ScriptBlock that needs converting.
* A SessionState object for when scoping is required for retrieving values (like `$using:`).
* A "Get" pattern which can be used for finding `$var:Name` syntaxes within the supplied ScriptBlock.
* A "Set" pattern which can be used for finding `$value = $var:Name` syntaxes within the supplied ScriptBlock.

The ScriptBlock supplied to [`Add-PodeScopedVariable`](../../Functions/ScopedVariables/Add-PodeScopedVariable) should return a converted version of the ScriptBlock supplied to it. It should also return an optional array of values which need to be supplied to the converted ScriptBlock first.

For example, if you wanted to add a custom `$config:` Scoped Variable, to simplify calling [`Get-PodeConfig`](../../Functions/Utilities/Get-PodeConfig), but you wanted to do this using [`Add-PodeScopedVariable`](../../Functions/ScopedVariables/Add-PodeScopedVariable)'s `-ScriptBlock` instead of the Replacement parameters, then you could do the following:

```powershell
Add-PodeScopedVariable -Name 'config' -ScriptBlock {
    param($ScriptBlock, $SessionState, $GetPattern, $SetPattern)

    # convert the scriptblock to a string, for searching
    $strScriptBlock = "$($ScriptBlock)"

    # the "get" template to be used, to convert "$config:Name" syntax to "(Get-PodeConfig).Name"
    $template = "(Get-PodeConfig).'{{name}}'"

    # loop through the scriptblock, replacing "$config:Name" syntax
    while ($strScriptBlock -imatch $GetPattern) {
        $getReplace = $template.Replace('{{name}}', $Matches['name'])
        $strScriptBlock = $strScriptBlock.Replace($Matches['full'], "($($getReplace))")
    }

    # convert string back to scriptblock, and return
    return [scriptblock]::Create($strScriptBlock)
}
```

## Conversion

If you have a ScriptBlock that you need to convert, in an ad-hoc manner, you can manually call [`Convert-PodeScopedVariables`](../../Functions/ScopedVariables/Convert-PodeScopedVariables) yourself. You should supply the `-ScriptBlock` to wish to convert, as well as an optional `-PSSession` SessionState from `$PSCmdlet.SessionState`, to this function:

```powershell
# convert the scriptblock's scoped variables
$ScriptBlock, $usingVars = Convert-PodeScopedVariables -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState

# invoke the converted scriptblock, and supply any using variable values
$result = Invoke-PodeScriptBlock -ScriptBlock $ScriptBlock -UsingVariables $usingVars -Splat -Return
```

!!! note
    If you don't supply a `-PSSession` then no `$using:` Scoped Variables will be converted.

You can also supply one or more Scoped Variable Names to `-Exclude`, which will skip over converting these Scoped Variables in the supplied `-ScriptBlock`.
