# Release Notes

## v1.4.0

```plain
### Enhancements
* #447: Sessions can now be used via Headers for better CLI support
* #448: `-EndpointName` on routes can now take an array of endpoint names
* #454: New wrapper function, `Start-PodeStaticServer`, for simple static websites

### Bugs
* #446: Fixes functions that were not in accordence with Coding Guidelines (thanks @jhainau!)

### Documentation
* #445: Improved documentation on using CSRF middleware
```

## v1.3.0

```plain
### Enhancements
* #421: Adds a new `-FilePath` parameter to the `Add-PodeTimer` and `Add-PodeSchedule` functions
* #422: Adds a new `-FilePath` parameter to the `Start-PodeServer` function
* #423: New `Edit-PodeSchedule` and `Edit-PodeSchedule` functions
* #431: Support for the `WWW-Authenticate` header on failed Authentication (401) responses
* #433: Support in custom Authentication types to allow returning extra Headers on the response
* #435: New `Set-PodeScheduleConcurrency` function to set the max number of concurrent schedules
* #440: Adds support in the `package.json` for custom PowerShell Repositories

### Bugs
* #429: Running `pode start` failed to invoke server script on some platforms
* #441: Fixes an issue where local modules failed to resolve correct path
```

## v1.2.1

```plain
### Enhancements
* #415: New functions for invoking Timer and Schedules adhoc

### Bugs
* #416: Fix for using `*/INT` in cron-expressions

### Documentation
* #418: Docs and examples typo fixes
```

## v1.2.0

```plain
### Features
* #395: Built-in support for using Server-to-Client websockets
* #389: Support for defining custom body/payload parsers for specific ContentTypes

### Enhancements
* #401: Support for running a Schedule/Timer's logic when the server starts/restarts
* #400: Helper wrapper method `Out-PodeHost` to output data to the main host terminal
* #390: Support for setting a Status Code on all "Write-Pode[Type]Response" functions
* #386: Support to set a fixed ContentType on `Set-PodeResponseAttachment` (thanks @Windos!)
* #383: If a called route exists but for a different HTTP method, then return a 405 not a 404
* #382: Support on Unix environments to terminate/restart a server using Shift+C/R

### Documentation
* #405: How to create a server that has endpoints accessible externally
* #399: Reference to the literal parameter names on Schedules
* #396: How to return a custom Status Code and/or message from an Authenticator
```

## v1.1.0

```plain
### Features
* #376: *Experimental* support for cross-platform HTTPS!

### Bugs
* #372: Fixed an issue when getting the length of strings in `Get-PodeCount` (thanks @Fraham!)
* #384: Fixed `Set-PodeResponseAttachment` not setting the ContentLength (plus support of literal paths)

### Packaging
* #375: Update the Dockerfiles to PowerShell 6.2.3
* #253: Publish the Docker images on the GitHub Package Registry
```

## v1.0.1

```plain
### Bugs
* #367: If a "server.psd1" file is not present, Logging will not work
* #368: Logging will attempt to mask everything if no mask patterns are supplied
```

## v1.0.0

```plain
### Features
* #228: Support for rendering Markdown as HTML (Fully supported in PowerShell 7+)
* #334: New "ConvertTo-PodeRoute" function to automatically make Routes from Functions/Modules
* #344: New "Add-PodePage" function to more easily make GET Routes for simple pages

### Enhancements
* #328: New "Get-PodeAuthADUser" parameter -NoGroups, to skip retrieving groups from AD
* #330: Allow for -ArgumentList on Routes, Handlers, Timers, Schedules, etc - now they can be more dynamic
* #341: Allow Show-PodeGui to work under PowerShell 7 on Windows
* #343: Ability to mask data in logs using Regex
* #352: On "Add-PodeEndpoint", split the -Address parameter into -Address/-Port parameters
* #354: Two new functions for Sessions to Save and Remove them
* #355: Support on "Add-PodeEndpoint" for a -RedirectTo parameter, to automatically build a redirect Route

### Bugs
* #312: On Static Routes, don't create a PSDrive when the Source is a File Share
* #318: For Cron Expressions, split the DayOfWeek and DayOfMonth
* #324: Setting Authentication middleware globally didn't save the Session object
* #347: Route parameters fail if the value contains a dot, or other special characters
* #351: Stop the "Done" message appearing when the server errors

### Packaging
* #338: Update the version of MkDocs Material Theme to v4.4.0
* #349: Update the Dockerfiles to PowerShell 6.2.2

### Internal Code
* #279, #279, #287, #289, #290, #291, #292, #294, #295, #296, #297, #305, #306, #314, #315
    - Convert all functions to PowerShell Syntax
* #303: Change from using "pode.<env>.json" files to "server.<env>.psd1" files

### Documentation
* #299: Rebuild Documentation's Functions section using PlatyPS
* #316: Write a migration guide for going from v0.X to v1.0
* #321: Go through all documentation, ensuring it's up-to-date with new Syntax
```

## v0.32.0

```plain
### Enhancements
* #270: Support on `gui` to specify the width and height of the window
* #280: Support when file monitoring to output the files that caused the server to restart
* #282: New actions on `state` to save and restore to to/from a file

### Bugs
* #271: Fix in `Convert-PodePathPatternsToRegex` when converting file names - thanks @Fraham!

### Documentation
* #284: Notes in documention about referencing JSON payload data in PowerShell 4/5
```

## v0.31.0

```plain
### Features
* #264: Support for Azure Functions and AWS Lambda
* #264: New `header` function for adding/setting and getting header values from the Request/Response

### Enhancements
* #264: Cookies are now done via the "Set-Cookie" header, meaning `cookie` now appropriately sets multiple cookies
* #266: Have a `-Browse` flag on the `server` to auto-launch the website in a browser

### Bugs
* #264: The `text` function now sets the content-type to "text/plain" by default
```

## v0.30.0

```plain
### Enhancements
* #245: Support for Windows AD group validation on the inbuilt 'windows-ad' authentication validator
* #250: Support for bulk importing/loading scripts and modules
* #251: Support on routes to supply a FilePath to a script that contains the route's scriptblock
* #252: Support on the server function to supply a custom RootPath

### Performance
* #258: Performance improvements to all aspects of a web request, reducing response times

### Packaging
* #261: Docker images updated to PowerShell Core v6.2.1
```

## v0.29.0

```plain
### Enhancements
* #216: Multi-content-type support on Error Pages
* #232: Support for setting/forcing default content types on routes
* #243: Support on Static Routes to flag them as "Download Only"
* #248: Ability to alter the server's root path

### Packaging
* #227: Docker images updated to PowerShell Core v6.2.0
* #233: New ARM32 docker image, enabling support for Raspberry Pi

### Build
* #237, #238, #239: Updates to CI tools
```

## v0.28.1

```plain
### Bugs
* #226: Adds the "gui" function to export list
```

## v0.28.0

```plain
### Features
* #210: New "cookie" function added, to support setting/getting cookies - including signing them
* #211: Support for CSRF via the new "csrf" function, which generates valid middleware and random tokens

### Enhancements
* #204: Support on the "import" function to import PSSnapIns
* #223: Support for using a Thumbprint on the "listen" function instead of Certificate name

### Bugs
* #206: When disposing/restarting the SMTP server, send a "QUIT" message if still connected

### Clean-Up
* #209: Rename of internal function to avoid collisions, and change "Get-PodeConfiguration" to "config"
```

## v0.27.3

```plain
### Bugs
* #217: Binding to hostname throws error
```

## v0.27.2

```plain
### Bugs
* #212: Incorrect variable name used in html, csv, xml and json functions when referencing files
```

## v0.27.1

```plain
### Bugs
* #199: Fix issues with relative paths when running server as a service
* #200: Fix issue with file monitor, where folder patterns fail to match on new files
```

## v0.27.0

```plain
### Features
* #185: Support for Server Restarts either Periodically or at specific Times, with support for cron expressions
* #188: Support for Custom Error pages, with inbuilt Pode error pages

### Enhancements
* #189: SMTP server to parse data headers and have them set on the event object

### Performance
* #196: Massive improvements to performance when loading static content

### Bugs
* #181: Importing modules into the current scope should be done Globally, making them instantly accessible
* #183: TCP Reads and Writes should be Async so they can be terminated more easily
* #184: SMTP and TCP servers fail to Restart
* #196: Default paths on Static Content fail when using nested directories

### General
* #194: Update Dockerfile from using PSCore 6.1.0 to 6.1.3
```

## v0.26.0

```plain
### Features
* #162: Basic support for local modules in "package.json" on "pode install"
* #175: Support for flash messages on sessions, and in authentication

### Bugs
* #72: RunspacePools aren't being recreated during a restart, and modules fail to import into other RunspacePools
```

## v0.25.0

```plain
### Features
* #170: Support for Static Content Caching, with ability to include/exclude routes/extensions

### Enhancements
* #161: New method to return configuration from the pode.json file, plus improved docs and support for environment configs
* #165: Support on the inbuilt SMTP server for Subject and decoded Body
* #168: Ability to exclude/include paths/extensions when triggering an Internal Restart

### Documentation
* #45: Add "Known Issues" pages to documentation

### Clean-Up
* #160: Internally, rename occurrences of $PodeSession to $PodeContext
```

## v0.24.0

```plain
### Features
* #125: Helper support function for uploading files from a web form

### Enhancements
* #149: Inbuilt support for Windows AD Authentication

### Bugs
* #152: Fix the Choco install script so it installs the module for PowerShell Core as well
* #155: After an Internal Restart, the View Engine is not set back to the default
* #158: If views/public directories don't exist, the creation of PSDrive fails
```

## v0.23.0

```plain
### Features
* #77: Ability to run a web server, and view it through a Desktop Application (Windows only)

### Enhancements
* #137: Don't require admin privileges when listening on Localhost
* #140: Add a Custom switch to the Logger function - no need to use the "custom_<name>" format any more!
* #142: Ability to listen on multiple endpoints - especially useful for hostnames against a single IP address
* #143: Support on routes to allow them to be bound against specific hostnames/protocols
* #146: Listen function to have Name parameter - so we can select which one to bind a Route/Gui to better
```

## v0.22.0

```plain
### Enhancements
* #123: Ability to remove a `route`
* #124: Views, Public and custom static routes now use `New-PSDrive` to prevent directory tranversing
* #128: Ability to `listen` using a host name
* #130: `auth` now allows re-using inbuilt/custom parsers. Rather than `name` the type, the name is now any custom name you want to use and yuo specify the `-type` (like basic, etc). If no `-type` supplied, `name` is used as the type instead
* #131: There's now a route parameter on `middleware`, so you can define global middleware that only run on requests for specific routes.
```

## v0.21.0

```plain
### Enhancements
* #110: Return a 401 for inaccessible files
* #116: Support on custom static content, for returning `index.html` or `default.html` (plus others), if a directory is requested

### Bugs
* #111: Separate out the `service` server type into own runspace
* #112: Server should return a 500 if middleware/route fails unexpectedly, rather than a 200

### Documentation
* #120: Added examples of running scripts as Windows or Linux services [here](https://badgerati.github.io/Pode/Getting-Started/RunAsService/)

### Clean-Up
* #118: Rename `$WebSession` to `$WebEvent` - internal references only
```

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
