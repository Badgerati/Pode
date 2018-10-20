# Release Notes

## v0.20.0

```plain
### Documentation
* Extended documentation for third-party template engines
* "Building your first app" documentation

### Features
* #103: Adds support for custom static routes

### Enhancements
* #101: Adds a `-Limit` parameter to schedules
* `import` function now supports installed modules

### Clean-Up
* #102: Logging converted to internal `endware` script
```

## v0.19.1

```plain
### Documentation
* #91: This release contains far better documentation for Pode: https://badgerati.github.io/Pode

### Enhancements
* #93: Updates PowerShell Docker image to 6.1.0, so internal restarts now work
* #96: Chocolatey package now contains the module, rather than downloading from GitHub
* Adds more aliases for parameters on core functions
* Renames `script` function to `import` (the former is still supported)
* New CI builder: Travis CI, used to test Pode on *nix and PowerShell Core
* Minor miscellaneous stability fixes
```

## v0.19.0

```plain
### Features
* #84: Session cookie support, with in-mem/custom data storage
* #86: Request authentication support. Currently implemented: Basic, Forms, Custom

### Enhancements
* #88: Enabling Ctrl+R to be pressed on the CLI to trigger a server restart - similar to using `-FileMonitor`.
```

## v0.18.0

```plain
### Features
* #78: Middleware support for web servers, allowing custom logic and extension modules on web request/responses

### Enhancements
* #81: Added aliases onto some of the `Server` parameters
```

## v0.17.0

```plain
### Features
* #43: Ability to generate self-signed certificates, and bind those certs - or pre-installed certs - when using HTTPS
* #71: New `scripts` call to specify external modules that should be imported into each runspace

### Bugs
* #71: Unable to access functions from external scripts
* #73: Calling `pode start` fails to import Pode module into runspaces
```

## v0.16.0

```plain
### Features
* #66: Support for basic rate limiting of requests per x seconds from IPs
* #68: Support for scheduled tasks using cron expressions

### Enhancements
* #62: Helper function to ease URL redirection
* #64: Have a '*' HTTP method so a route can be used on every method
```

## v0.15.0

```plain

### Features
* #31: Support for multithreaded responses on web, smtp and tcp servers using `-Threads` on your Server block

### Misc
* #59: Removal of obsolete functions, such as the older `Write-JsonResponse` which is now just `Json`
* #31: Addition of some minor performance tests using `k6`
* Addition of new icon and logo for Pode
```

## v0.14.0

```plain
### Features
* #21: Ability for Pode to Internally Restart when a File Change is Detected
* #52: Support for Allowing/Denying IP and Subnet Addresses

### Enhancements
* #44: Setup Unit Tests with Pester and run on AppVeyor

### Bugs
* #51: Set Dockerfile to use a fixed version of the PowerShell container, rather than latest
* #55: Setup SMTP/TCP listeners to run in separate runspace like Web
```

## v0.13.0

```plain
### Features
* #40: Ability to add variables to a shared state, so you can re-use variables in timers, loggers, and routes
```

## v0.12.0

```plain
### Features
* #33: Support for logging to the terminal, files, and custom loggers for LogStash/Fluentd/etc
* #35: New `Attach` function to help attach files from the public directory to the response for downloading

### Enhancements
* #32: Ability to listen on a specific IP address using `-IP` on a `Server`
* #36: Support for relative paths on views/public content, when running server script from non-root directory
```

## v0.11.3

```plain
### Bugs and Enhancements
* #22: Proper fix for high CPU usage, by using `Task.Wait` with `CancellationTokens`; A Runspace is setup to monitor for key presses, and on `Ctrl+C` will `Cancel()` the token and terminate Pode
```

## v0.11.2

```plain
### Bugs
* #22: Hot fix patch for reducing high CPU usage when idle
```

## v0.11.1

```plain
### Bugs
* #16: Status and Include functions were missing from module export list
```

## v0.11.0

```plain
### Features
* #5: Async timers to run tasks and processes in a separate thread (see timers sections in README)

### Enhancements
* #7: New `status` function to easily alter the StatusCode of a Response
* #8: New `json`, `xml`, `html`, `csv`, `view` and `tcp` functions to replace current "Write-<Type>Response" - now obsolete - functions (see ticket for explanation, and README for usage)

### Bugs
* #12: Fixed an issue that caused image files (and others) to not render appropriately
```