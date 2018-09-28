# CLI

Pode has some commands that you can utilise from the CLI - when your in a PowerShell terminal, or `pwsh` session. These commands help you to initialise, start, test, build, or install any packages for your repo/server.

All of these commands are centered around the `package.json` format - similar to that of Node.js and Yarn.

!!! info
    At the moment, Pode only uses the `start`, `test`, `build` and `install` properties of the `scripts` section in your `package.json`. You can still have others, like `dependencies` for Yarn

## Commands

### Build

The `build` command will run the script found in the `package.json` file, at the `scripts/build` value:

```powershell
pode build
```

### Init

The `init` command will help you create a new `package.json` file from scratch. It will ask a few questions, such as author/name/etc, and then create the file for you:

```powershell
pode init
```

!!! tip
    By default, Pode will pre-populate the  `test`, `build` and `install` values using `yarn`, `psake` and `pester` respectively

### Install

The `install` command will run the script found in the `package.json` file, at the `scripts/install` value:

```powershell
pode install
```

### Start

The `start` command will run the script found in the `package.json` file, at the `scripts/start` value. If this value is not set, then this command will instead run the value under `main`:

```powershell
pode start
```

### Test

The `test` command will run the script found in the `package.json` file, at the `scripts/test` value:

```powershell
pode test
```

## Package File

The following is an example of a `package.json` file:

```json
{
    "name":  "example",
    "description":  "",
    "version":  "1.0.0",
    "main":  "./server.ps1",
    "scripts":  {
        "start":  "./server.ps1",
        "test":  "invoke-pester ./tests/*.ps1",
        "install":  "yarn install --force --ignore-scripts --modules-folder pode_modules",
        "build": "psake"
    },
    "author":  "Rick Sanchez",
    "license":  "MIT"
}
```