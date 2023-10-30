# Contributing to Pode

:star2::tada: First of all, thank you for taking the time and contributing to Pode! :tada::star2:

The following is a set of guidelines for contributing to Pode on GitHub. These are mostly guidelines, not rules. Use your best judgment, and feel free to propose changes to this document in a pull request.

## Table of Contents

- [Contributing to Pode](#contributing-to-pode)
  - [Table of Contents](#table-of-contents)
  - [Code of Conduct](#code-of-conduct)
  - [I just have a Question](#i-just-have-a-question)
  - [About Pode](#about-pode)
  - [How to Contribute](#how-to-contribute)
    - [Issues](#issues)
    - [Branch Names](#branch-names)
    - [Pull Requests](#pull-requests)
    - [Building](#building)
    - [Testing](#testing)
    - [Documentation](#documentation)
    - [Importing](#importing)
  - [Styleguide](#styleguide)
    - [Editor](#editor)
    - [Code](#code)
    - [Comments](#comments)
      - [General](#general)
      - [Help](#help)
    - [PowerShell Commandlets](#powershell-commandlets)
      - [Foreach-Object](#foreach-object)
      - [Where-Object](#where-object)
      - [Select-Object](#select-object)
      - [Measure-Object](#measure-object)

## Code of Conduct

This project, and everyone participating in it, is governed by the Pode's [Code of Conduct](../.github/CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code.

## I just have a Question

[![Discord](https://img.shields.io/discord/887398607727255642)](https://discord.gg/fRqeGcbF6h)

If you have a question, feel free to either ask it on [GitHub Issues](https://github.com/Badgerati/Pode/issues), or head over to Pode's [Discord](https://discord.gg/fRqeGcbF6h) channel.

## About Pode

Pode is a PowerShell framework/web server. The aim is to make it purely PowerShell, with *no* external dependencies - other than what is available in .NET. This allows Pode to be very lightweight, and just work out-of-the-box when the module is installed on any platform.

The only current exception to the "all PowerShell" rule is the socket listener Pode uses. This listener is a part of Pode, but is written in .NET.

## How to Contribute

When contributing, please try and raise an issue first before working on the issue. This allows us, and other people, to comment and help. If you raise an issue that you're intending on doing yourself, please state this within the issue - to avoid somebody else picking the issue up.

### Issues

You can raise new issues, for bugs, enhancements, feature ideas; or you can select an issue currently not being worked on.

### Branch Names

Branches should be named after the issue you are working on, such as `Issue-123`. If you're working on an issue that hasn't been raised (such as a typo, tests, docs, etc), branch names should be descriptive.

When branching, please create your branches from `develop` - unless another branch is far more appropriate.

### Pull Requests

When you open a new Pull Request, please ensure:

* The Pull Request must be done against the `develop` branch.
* The title of the Pull Request contains the original issue number (or is descriptive if there isn't one).
* Details of the change are explained within the description of the Pull Request.
* Where possible, include examples of how to use (if it's a new feature especially).

Once opened GitHub will automatically run CI on Windows, Linux and MacOS, as well as Code Coverage.

### Building

Before running any of Pode's examples, you will need to compile the Listener first. To do so you will need [`Invoke-Build`](https://github.com/nightroman/Invoke-Build). Once installed, run the following:

```powershell
Invoke-Build Build
```

### Testing

Pode has Unit and Integration Tests, there are also some Performance Tests but you do not need to worry about them.

Where possible, please try to create/update new Unit/Integration Tests especially for features. Don't worry too much about decreasing the Code Coverage.

The Unit Tests can be found at `/tests/unit/` from the root of the repository, and the Integration Tests can be found at `tests/integration`.

To run the tests, you will need [`Invoke-Build`](https://github.com/nightroman/Invoke-Build) (running the tests will compile Pode's listener). Once installed, run the following to run the tests:

```powershell
Invoke-Build Test
```

### Documentation

Where possible, please add new, or update, Pode's documentation. This documentation is in the form of:

* The main `/docs` directory. These are markdown files that are built using mkdocs. The `/docs/Functions` directory is excluded as these are compiled using PlatyPS.
* All functions within the `/src/Public` directory need to have help comment documentation added/updated.
  * Synopsis and Parameter descriptions should be descriptive.
  * Examples should only contain a single line of code to use the function. (This is due a limitation in PlatyPS where it currently doesn't support multi-line examples).

To see the docs you'll need to have the [`Invoke-Build`](https://github.com/nightroman/Invoke-Build) installed, then you can run the following:

```powershell
Invoke-Build Docs
```

### Importing

When editing Pode and you need to import the local dev module for testing, you will need to import the `Pode.psm1` in the `/src` directory. This is the same as importing Pode's `.psd1` file, but will avoid errors for an invalid version number.

## Styleguide

### Editor

You can use whatever editor you like, but it's recommended to use Visual Studio Code. To help with this style guide, specifically for PowerShell, Pode has code formatting workspace setting which will automatically format the files on save.

### Code

In general, observe the coding style used within the file/project and mimic that as best as you can. Some standards that are typical are:

* Bracers  (`{}`) should be on the same line of the statement they following, such as `function`, `foreach`, `if`, etc.
```powershell
function Add-Something {
    foreach ($item in $items) {
        # logic
    }
}
```

* **Never** use inline parameters on functions, such as: `function New-Function($param1, $param2)`
  * Always use the `param` block within the function.
  * Ensure public functions always declare `[CmdletBinding()]` attribute.
  * Ensure parameter names, types, and attributes are declared on new lines - not all on one line.
```powershell
function Add-Something {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Item
    )
}
```

* **Never** use the following commandlets ([see below](#powershell-commandlets) for details):
  * `Foreach-Object`
  * `Where-Object`
  * `Select-Object`
  * `Measure-Object`

* Avoid using `-not`, and use `!` instead:
```powershell
if (!(Test-Path $Path)) {
    # logic
}
```

* Don't end lines with semi-colons (`;`).

### Comments

#### General

Comments are always useful for new people reading code. Where possible, try to place comments that describe what some code-block is doing (or why it's there).

* Try not to write a comment for every line of code, as it makes the code messy and harder to read.
* Try to avoid comments such as, on a `foreach`, of `this line loops through the users`.

#### Help

On public functions, new and existing, these should always have Help comments:

* They should be placed above the function header.
* They should be updated if a new parameter is added to/removed from the function.
* Parameter descriptions should be descriptive.
* Examples should only contain a single line of code to use the function. (This is due a limitation in PlatyPS where it currently doesn't support multi-line examples).

### PowerShell Commandlets

For performance reasons, the following PowerShell commandlets should be avoided at all costs. Instead use the replacement stated for each.

#### Foreach-Object

Instead of using the `Foreach-Object` commandlet, please use the `foreach` keyword. This is orders of magnitude faster than `Foreach-Object`.

```powershell
# instead of this
@(1, 2, 3) | Foreach-Object {
    # do stuff
}

# do this instead
foreach ($i in @(1, 2, 3)) {
    # do stuff
}
```

#### Where-Object

Instead of using the `Where-Object` commandlet, please use the `foreach` and `if` keywords. These are orders of magnitude faster than `Where-Object`.

```powershell
# instead of this
$array = @(1, 2, 3, 1, 3, 4) | Where-Object {$_ -eq 1 }

# do this instead
$array = @(foreach ($i in @(1, 2, 3, 1, 3, 4)) {
    if ($i -eq 1) {
        $i
    }
})
```

#### Select-Object

Instead of using the `Select-Object` commandlet to expand a property, or to select the first/last elements, please use the following. These are orders of magnitude faster than `Measure-Object`.

```powershell
# instead of these
$services | Select-Object -ExpandProperty Name
$services | Select-Object -First 1
$services | Select-Object -Last 1

# use these instead
($services).Name
(@($services))[0] # first item
(@($services))[-1] # last item
```

#### Measure-Object

Instead of using the `Measure-Object` commandlet, please use either the `.Length` or `.Count` properties. These are orders of magnitude faster than `Measure-Object`.

```powershell
# instead of these
(@(1, 2, 3) | Measure-Object).Count
(@{ Name = 'Rick' } | Measure-Object).Count

# use these instead
(@(1, 2, 3)).Length
(@{ Name = 'Rick' }).Count
```
