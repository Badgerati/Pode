# Contributing to Pode

:star2::tada: First of all, thank you for taking the time and contributing to Pode! :tada::star2:

The following is a set of guidelines for contributing to Pode on GitHub. These are mostly guidelines, not rules. Use your best judgment, and feel free to propose changes to this document in a pull request.

## Table of Contents

* [Code of Conduct](#code-of-conduct)
* [I just have a Question](#i-just-have-a-question)
* [About Pode](#about-pode)
* [How to Contribute](#how-to-contribute)
  * [Issues](#issues)
  * [Branch Names](#branch-names)
  * [Pull Requests](#pull-requests)
  * [Testing](#testing)
  * [Documentation](#documentation)
* [Styleguide](#styleguide)
  * [Code](#code)
  * [Comments](#comments)
    * [General](#general)
    * [Help](#help)
  * [PowerShell Commandlets](#powershell-commandlets)
    * [Foreach-Objech](#foreach-object)
    * [Where-Object](#where-object)
    * [Select-Object](#select-object)
    * [Measure-Object](#measure-object)

## Code of Conduct

This project and everyone participating in it is governed by the Pode's [Code of Conduct](../.github/CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code.

## I just have a Question

[![Gitter](https://badges.gitter.im/Badgerati/Pode.svg)](https://gitter.im/Badgerati/Pode?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge)

If you have a question, feel free to either ask it on [GitHub Issues](https://github.com/Badgerati/Pode/issues), or head over to Pode's [Gitter](https://gitter.im/Badgerati/Pode?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge) channel.

## About Pode

Pode is a PowerShell framework, and the aim is to make it purely PowerShell only with *no* external dependencies. This allows Pode to be very lightweight, and just work out-of-the-box when the module is installed on any platform.

## How to Contribute

When contributing, please try and raise an issue first before working on the issue. This allows us, and other people, to comment and help. If you raise an issue that you're intending on doing yourself, please state this within the issue - to above somebody else picking the issue up.

### Issues

You can raise new issues, for bugs, enhancements, feature ideas; or you can select an issue currently not being worked on.

### Branch Names

Branches should be named after the issue you are working on, such as `Issue-123`.

If you're working on an issue that hasn't been raised (such as a typo, tests, docs, etc), branch names should be descriptive.

### Pull Requests

When you open a new Pull Request, please ensure:

* The Pull Request must be done against the `develop` branch.
* The title of the Pull Request contains the original issue number (or is descriptive if there isn't one).
* Details of the change are explained within the description of the Pull Request.
* Where possible, include examples of how to use (if it's a new feature especially).

Once opened GitHub will automatically run CI on Windows, Linux and MacOS, as well as Code Coverage.

### Testing

Pode has Unit Tests, there are also some Performance Tests but you do not need to worry about them. There are also currently no Integration Tests.

Where possible, please try to create/update new Unit Tests especially for features. Don't worry too much about decreasing the Code Coverage.

The Unit Tests can be found at `/tests/unit/` from the root of the repository.

To run the tests, you will need [`Invoke-Build`](https://github.com/nightroman/Invoke-Build). Once installed, run the following to run the tests:

```powershell
Invoke-Build Test
```

### Documentation

Where possible, please add new, or update, Pode's documentation. This documentation is in the form of:

* The main `/docs` directory. These are markdown files that are built using mkdocs. The `/docs/Functions` directory is excluded as these are compiled using PlatyPS.
* All functions within the `/src/Public` directory need to have documentation.

To see the docs you'll need to have the [`Invoke-Build`](https://github.com/nightroman/Invoke-Build) installed, then you can run the following:

```powershell
Invoke-Build Docs
```

## Styleguide

### Code

In general, observe the coding style used within the file/project and mimic that as best as you can. Some standards that are typical are:

* Bracers (`{}`) on the function header should be on a new line.
* Bracers  (`{}`) should be on the same line of other calls, such as `foreach`, `if`, etc.
* **Never** use inline parameters on functions. Such as: `function New-Function($param1, $param2)`
  * Always use the param block within the function.
  * Ensure public functions always declare `[CmdletBinding()]` attribute.
  * Ensure parameter names, types, and attributes are declared on new lines - not all on one line.
* **Never** use the following commandlets ([see below](#powershell-commandlets) for details):
  * `Foreach-Object`
  * `Where-Object`
  * `Select-Object`
  * `Measure-Object`

### Comments

#### General

Comments are always useful for new people reading code. Where possible, try to place comments that describe what some code-block is doing (or why it's there).

* Try not to write a comment for every line of code, as it makes the code messy and harder to read.
* Try to avoid comments such as, on a `foreach`, of `this line loops through the users`.

#### Help

On public functions, new and existing, these should always have Help comments:

* Help comments should be placed above the function header.
* Help comments should be updated if a new parameter is added to/removed from the function.

### PowerShell Commandlets

For performance reasons, the following PowerShell commandlets should be avoided at all costs. Instead use the replacement stated for each.

#### Foreach-Object

Instead of using the `Foreach-Object` commandlet, please use the `foreach` keyword. This is orders of magnitude more performant than `Foreach-Object`.

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

Instead of using the `Where-Object` commandlet, please use the `foreach` adn `if` keywords. This is orders of magnitude more performant than `Where-Object`.

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

Instead of using the `Select-Object` commandlet to expand a property, or to select the first/last elements, please use the following. These is orders of magnitude more performant than `Measure-Object`.

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

Instead of using the `Measure-Object` commandlet, please use either the `.Length` or `.Count` properties. These is orders of magnitude more performant than `Measure-Object`.

```powershell
# instead of these
(@(1, 2, 3) | Measure-Object).Count
(@{ Name = 'Rick' } | Measure-Object).Count

# use these instead
(@(1, 2, 3)).Length
(@{ Name = 'Rick' }).Count
```
