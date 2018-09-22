# Pode

[![MIT licensed](https://img.shields.io/badge/license-MIT-blue.svg)](https://raw.githubusercontent.com/Badgerati/Pode/master/LICENSE.txt)
[![Documentation](https://img.shields.io/badge/docs-latest-blue.svg)](https://badgerati.github.io/pode)
[![Build](https://ci.appveyor.com/api/projects/status/nvl1xmh31crp10ea/branch/develop?svg=true)](https://ci.appveyor.com/project/Badgerati/pode/branch/develop)
[![Gitter](https://badges.gitter.im/Badgerati/Pode.svg)](https://gitter.im/Badgerati/Pode?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge)

[![Chocolatey](https://img.shields.io/chocolatey/v/pode.svg?colorB=a1301c)](https://chocolatey.org/packages/pode)
[![Chocolatey](https://img.shields.io/chocolatey/dt/pode.svg?label=downloads&colorB=a1301c)](https://chocolatey.org/packages/pode)

[![PowerShell](https://img.shields.io/powershellgallery/v/pode.svg?label=powershell&colorB=085298)](https://www.powershellgallery.com/packages/Pode)
[![PowerShell](https://img.shields.io/powershellgallery/dt/pode.svg?label=downloads&colorB=085298)](https://www.powershellgallery.com/packages/Pode)

[![Docker](https://img.shields.io/docker/stars/badgerati/pode.svg)](https://hub.docker.com/r/badgerati/pode/)
[![Docker](https://img.shields.io/docker/pulls/badgerati/pode.svg)](https://hub.docker.com/r/badgerati/pode/)

Pode is a Cross-Platform PowerShell framework that allows you to host [REST APIs](#rest-api), [Web Pages](#web-pages) and [SMTP/TCP](#smtp-server) servers. It also allows you to render dynamic files using [Pode](#pode-files) files, which is effectively embedded PowerShell, or other [Third-Party](#third-party-view-engines) template engines.

## Contents

* [Install](#install)
* [Documentation](#documentation)
    * [Setup](#setup)
    * [Docker](#docker)
    * [Frontend](#frontend)
    * [Basics](#basics)
        * [Specific IP](#specific-ip-address)
        * [Threading](#threading)
    * [Timers](#timers)
    * [Schedules](#schedules)
        * [Cron Expressions](#cron-expressions)
        * [Advanced Cron](#advanced-cron)
    * [REST API](#rest-api)
    * [Web Pages](#web-pages)
    * [Middleware](#middleware)
        * [Order of Running](#order-of-running)
        * [Overriding Inbuilt Logic](#overriding-inbuilt-logic)
        * [Sessions](#sessions)
    * [Authentication](#authentication)
        * [Basic](#basic-auth)
        * [Form](#form-auth)
        * [Custom](#custom-auth)
    * [SMTP Server](#smtp-server)
    * [Misc](#misc)
        * [Logging](#logging)
        * [Shared State](#shared-state)
        * [File Monitor](#file-monitor)
        * [Access Rules](#access-rules)
        * [Rate Limiting](#rate-limiting)
        * [External Scripts](#external-scripts)
        * [Certificates](#certificates)
    * [Helpers](#helpers)
        * [Attach File](#attach-file)
        * [Status Code](#status-code)
        * [Redirect](#redirect)
* [Pode Files](#pode-files)
    * [Non-View Pode Files](#non-view-pode-files)
    * [Third-Party Engines](#third-party-view-engines)
* [FAQ](#faq)

## Features

* Can run on Unix environments using PowerShell Core
* Host REST APIs and Web Pages
* Host TCP and SMTP server - great for tests and mocking
* Multiple threads can be used to response to incoming requests
* Use the full power of PowerShell, want a REST API for NUnit? Go for it!
* Ability to write dynamic files in PowerShell using Pode, or other third-party template engines
* Can use yarn package manager to install bootstrap, or other frontend libraries
* Setup async timers to be used as one off tasks, or for housekeeping services
* Ability to schedule async tasks using cron expressions
* Supports logging to CLI, Files, and custom loggers to other services like LogStash, etc.
* Cross-state runspace variable access for timers, routes and loggers
* Optional file monitoring to trigger internal server restart on file changes
* Ability to allow/deny requests from certain IP addresses and subnets
* Basic rate limiting for IP addresses and subnets
* Support for generating/binding self-signed certificates, and binding signed certificates
* Support for middleware on web servers
* Session middleware support on web requests
* Can use authentication on requests, which can either be sessionless or session persistant

## Install

You can install Pode from either Chocolatey, the PowerShell Gallery, or Docker:

```powershell
# chocolatey
choco install pode

# powershell gallery
Install-Module -Name Pode

# docker
docker pull badgerati/pode
```

## Documentation

This documentation will cover the basics on how to use Pode to create a simple REST API, Web Page, and SMTP Server. Further examples can be found in the examples folder.

### Setup

Pode has a couple of useful commands that you can use on the CLI, to help you initialise, start, test, build, or install any packages for your repo. These commands all utilise the `package.json` structure - as seen in Node and Yarn.

> At the moment, Pode only uses the `start`, `test`, `build` and `install` properties of the `scripts` section in your `package.json`. You can still have others, like `dependencies` for Yarn

```powershell
# similar to yarn and node, init will help you create a new package.json
pode init

# if you have a "start" script this will run that property; otherwise will run the script in "main"
pode start

# if you have a "test" script this will run that property
pode test

# if you have a "install" script this will run that property
pode install

# if you have a "build" script this will run that property
pode build
```

> By default, Pode will pre-populate `test`, `build` and `install` using `yarn`, `psake` and `pester` respectively

Following is an example `package.json`

```json
{
    "name":  "example",
    "description":  "",
    "version":  "1.0.0",
    "main":  "./file.ps1",
    "scripts":  {
        "start":  "./file.ps1",
        "test":  "invoke-pester ./tests/*.ps1",
        "install":  "yarn install --force --ignore-scripts --modules-folder pode_modules",
        "build": "psake"
    },
    "author":  "",
    "license":  "MIT"
}
```

### Docker

This is an example of using Docker to host your Pode scripts, using the `examples/web-pages.ps1` example from the examples directory. Below is an example `Dockerfile` to pull down the base container image, copy over the example files and then run the website (assuming this is run from the examples directory):

```dockerfile
# File: Dockerfile
FROM badgerati/pode
COPY . /usr/src/app/
EXPOSE 8085
CMD [ "pwsh", "-c", "cd /usr/src/app; ./web-pages-docker.ps1" ]
```

To build and run this, use the following commands:

```bash
docker build -t pode/example .
docker run -p 8085:8085 -d pode/example
```

Now try navigating to `localhost:8085` (or calling `curl localhost:8085`) and you should be greeted with a "Hello, world!" page.

### Frontend

You can host web-pages using Pode, and to help you can also use package managers like `yarn` to help install frontend libraries (like bootstrap).

```powershell
choco install yarn -y
yarn init
yarn add bootstrap
```

When run, Pode will tell `yarn` to install the packages to a `pode_modules` directory. Other useful packages could include `gulp`, `lodash`, `moment`, etc.

### Basics

Pode, at its heart, is a PowerShell module. In order to use Pode, you'll need to start off your script by importing it:

```powershell
Import-Module Pode
```

After that, all of your main server logic must be wrapped in a `Server` block. This lets you specify port numbers, server type, and any key logic: (you can only have one `Server` declared in your script)

```powershell
# server.ps1
Server {
    # attach to port 8080
    listen *:8080 http

    # logic for routes, timers, schedules, etc
}
```

The above `Server` script will start a basic HTTP listener on port 8080. To start the above server you can either:

* Directly run the `./server.ps1` script, or
* If you've created a `package.json` file, ensure the `./server.ps1` script is set as your `main` or `scripts/start`, then just run `pode start`

Once Pode has started, you can exit out at any time using `Ctrl+C`. For some environments you probably don't want to allow exiting, so you can disable the `Ctrl+C` by setting the `-DisableTermination` switch on the `Server`:

```powershell
# server.ps1
Server {
    # logic
} -DisableTermination
```

> By default `Ctrl+C` is disabled in Docker containers due to the way input is treated. Supplying `-t` when running the container will allow exiting

#### Specific IP Address

You can use `listen` within your `Server` block to specify a specific IP, Port and Protocol:

```powershell
Server {
    # listen on everything for http
    listen *:8080 http

    # listen on localhost for smtp
    listen 127.0.0.1:25 smtp

    # listen on ip for https (and create a self-signed cert)
    listen 10.10.1.4:8443 https -cert self
}
```

#### Threading

Pode deals with incoming request synchronously, by default, in a single thread. You can increase the number of threads/processes that Pode uses to handle requests by using the `-Threads` parameter on your `Server`.

```powershell
Server -Threads 2 {
    # logic
}
```

The number of threads supplied only applies to Web, SMTP, and TCP servers. If `-Threads` is not supplied, or is <=0 then the number of threads is forced to the default of 1.

### Timers

Timers are supported in all `Server` types, they are async processes that run in a separate runspace along side your main server logic. The following are a few examples of using timers, more can be found in `examples/timers.ps1`:

```powershell
Server {

    listen *:8080 http

    # runs forever, looping every 5secs
    timer 'forever' 5 {
        # logic
    }

    # run once after 2mins
    timer 'run-once' 120 {
        # logic
    } -skip 1 -limit 1

    # create a new timer via a route
    route 'get' '/api/timer' {
        param($session)
        $query = $session.Query

        timer $query['Name'] $query['Seconds'] {
            # logic
        }
    }
}
```

> All timers are created and run within the same runspace, one after another when their trigger time occurs. You should ensure that a timer's defined logic does not take a long time to process (things like heavy database tasks or reporting), as this will delay other timers from being run. For timers that might take a much longer time to run, try using `schedule` instead

### Schedules

Schedules are supports in all `Server` types, like `timers` they are async processes that run in separate runspaces. Unlike timer however, when a `schedule` is triggered it's logic is run in its own runspace - so they don't affect each other if they take a while to process.

Schedule triggers are defined using cron expressions, basic syntax is supported as well as some predefined expressions. They can start immediately, have a delayed start time, and also have a a defined end time.

A couple examples are below, more can seen in the examples directory:

```powershell
Server {
     # schedule to run every tuesday at midnight
    schedule 'tuesdays' '0 0 * * TUE' {
        # logic
    }

    # schedule to run every 5 past the hour, starting in 2hrs
    schedule 'hourly-start' '5 * * * *' {
        # logic
    } -StartTime ([DateTime]::Now.AddHours(2))
}
```

#### Cron Expressions

Pode supports basic cron expressions in the format: `<min> <hour> <day-of-month> <month> <day-of-week>`. For example, running every Tuesday at midnight: `0 0 * * TUE`.

Pode also supports some common predefined expressions:

| Predefined | Expression |
| ---------- | ---------- |
| @minutely | * * * * *' |
| @hourly | 0 * * * *' |
| @daily | 0 0 * * *' |
| @weekly | 0 0 * * 0' |
| @monthly | 0 0 1 * *' |
| @quaterly | 0 0 1 1,4,8,7,10' |
| @yearly | 0 0 1 1 *' |
| @annually | 0 0 1 1 *' |
| @twice-hourly | 0,30 * * * *' |
| @twice-daily | 0,12 0 * * *' |
| @twice-weekly | 0 0 * * 0,4' |
| @twice-monthly | 0 0 1,15 * *' |
| @twice-yearly | 0 0 1 1,6 *' |
| @twice-annually | 0 0 1 1,6 *' |

#### Advanced Cron

* `R`: using this on an atom will use a random value between that atom's constraints. When the expression is triggered the atom is re-randomised. You can force an intial trigger using `/R`. For example, `30/R * * * *` will trigger on 30mins, then random afterwards.

### REST API

When creating an API in Pode, you specify logic for certain routes for specific HTTP methods. Methods supported are: DELETE, GET, HEAD, MERGE, OPTIONS, PATCH, POST, PUT, and TRACE.

> There is a special `*` method you can use, which means a route applies to every HTTP method

The method to create new routes is `route`, this will take your HTTP method, route, and logic. For example, let's say you want a basic GET `ping` endpoint to just return `pong`:

```powershell
Server {
    listen *:8080 http

    route 'get' '/api/ping' {
        param($session)
        json @{ 'value' = 'pong'; }
    }
}
```

The scriptblock requires a `param` section for just one argument: `$session`. This argument will contain the `Request` and `Response` objects; `Data` (from POST), and the `Query` (from the query string of the URL), as well as any `Parameters` from the route itself (eg: `/:accountId`).

The last line is to write the JSON response. Anyone hitting `http://localhost:8080/api/ping` will be greeted back with `{ "value": "pong" }`.

If you wanted a POST endpoint that created a user, and a GET endpoint to get details of a user (returning a 404 if the user isn't found), then it would roughly look as follows:

```powershell
Server {
    listen *:8080 http

    route 'post' '/api/users' {
        param($session)

        # create the user
        $userId = New-DummyUser $session.Data.Email $session.Data.Name $session.Data.Password

        # return with userId
        json @{ 'userId' = $userId; }
    }

    route 'get' '/api/users/:userId'{
        param($session)

        # get the user
        $user = Get-DummyUser -UserId $session.Parameters['userId']

        # return the user
        if ($user -eq $null) {
            status 404
        }
        else {
            json @{ 'user' = $user; }
        }
    }
}
```

> More can be seen in the examples under `rest-api.ps1`, and `nunit-rest-api.ps1`

### Web Pages

It's actually possible for Pode to serve up webpages - css, fonts, and javascript included. They pretty much work exactly like the above REST APIs, except Pode has inbuilt logic to handle css/javascript and other files.

Pode also has its own format for writing dynamic HTML pages. There are examples in the example directory, but in general they allow you to dynamically generate HTML, CSS or any file type using embedded PowerShell.

All static and dynamic HTML content *must* be placed within a `/views/` directory, which is in the same location as your Pode script. In here you can place your view files, so when you call the `view` function in Pode, it will automatically look in the `/views/` directory. For example, if you call `view 'simple'` then Pode will look for `/views/simple.html`. Likewise for `/views/main/simple.html` if you pass `'main/simple'` instead.

> Pode uses a View Engine to either render HTML, Pode, or other types. Default is HTML, and you can change it to Pode by calling `engine pode` at the top of your Server scriptblock

Any other file types, from css to javascript, fonts and images, must all be placed within a `/public/` directory - again, in the same location as your Pode script. Here, when Pode sees a request for a path with a file extension, it will automatically look for that path in the `/public/` directory. For example, if you reference `<link rel="stylesheet" type="text/css" href="styles/simple.css">` in your HTML file, then Pode will look for `/public/styles/simple.css`.

A quick example of a single page site on port 8085:

```powershell
Server {
    listen *:8085 http

    # default view engine is already HTML, so following can left out
    engine html

    route 'get' '/' {
        param($session)
        view 'simple'
    }
}
```

> This can be seen in the examples under `web-pages.ps1`

### Middleware

When working with web servers in Pode - rest apis, routes, web-pages, etc. - then it does have support for using `middleware`. Middleware in Pode allows you to observe and edit the request/response objects for a current web request - you can alter the response, add custom objects to the request for later use, or terminate the response without processing the `route`.

Middleware is supported as a general `middleware` function, as well as on the `route` function for custom middleware - like authentication. Pode itself has some inbuilt middleware, which is overriable so you can use your own custom middleware; for example, Pode has inbuilt middleware for rate limiting, but you can override this with `middleware` and the name `@limit` (more further down).

The general `middleware` function takes a `scriptblock`, which accepts a single parameter for the current web session (similar to `route`s). The session object contains the `Request` and `Response` objects; you can also add more custom objects as the session is just a `hashtable`. If you want to keep processing the next middleware then `return $true`, otherwise `return $false` and the response will be closed immediately.

The following example is `middleware` that observes the user agent of the request. If the request comes from a PowerShell session then stop processing and return forbidden, otherwise create a new `Agent` key on the session for later `middleware`/`route`:

```powershell
Server {
    middleware {
        # session parameter which contains the Request/Response, and any other
        # keys added in any prior middleware
        param($session)

        # if the user agent is powershell, deny access
        if ($session.Request.UserAgent -ilike '*powershell*') {
            # forbidden
            status 403

            # stop processing
            return $false
        }

        # create a new key on the session for the next middleware/route
        $session.Agent = $session.Request.UserAgent

        # continue processing other middleware
        return $true
    }
}
```

Custom middleware on a `route` is basically the same as above. Normally a route is defined as "`route <method> <path> <logic>`", but you can also add custom middleware to a route as follows: "`route <method> <path> <middleware> <logic>`". The middleware on a route can either be a single `scriptblock` or an an array of `scriptblock`s.

The following example defines a `scriptblock` to reject calls that come from a specific IP address on a specific `route`:

```powershell
Server {
    # custom middleware to reject access to a specific IP address
    $reject_ip = {
        param($session)

        if ($session.Request.RemoteEndPoint.Address.IPAddressToString -ieq '10.10.1.8') {
            status 403
            return $false
        }

        return $true
    }

    # the middleware above is linked to this route, and checked before running the route logic
    route get '/users' $reject_ip {
        # route logic
    }

    # this route has no custom middleware, and just runs the route logic
    route get '/alive' {
        # route logic
    }
}
```

#### Order of Running

Middleware in Pode is executed in a specific order, this order of running is as follows:

* Access control    - allowing/denying IP addresses (if `access` logic is defined)
* Rate limiting     - limiting access to IP addresses (if `limit` logic is defined)
* Public content    - content such as images/css/js in the `public` directory
* Body parsing      - parsing request payload a JSON or XML
* Querystring       - getting any query string parameters currently on the request URL
* Custom middleware - runs any defined `middleware` in the order it was created
* Route middleware  - runs any `route` middleware for the current route being processed
* Route             - finally, the route itself is processed

> This order will be fully customisable in future releases, which will also remove the overriding logic below

#### Overriding Inbuilt Logic

Pode has some inbuilt middleware, as defined in the order of running above. Sometimes you probably don't want to use the inbuilt rate limiting, and use a custom rate limiting library that utilises REDIS. Each of the inbuilt middlewares have a defined name, that you can pass to the `middleware` function:

* Access control    - `@access`
* Rate limiting     - `@limit`
* Public content    - `@public`
* Body parsing      - `@body`
* Querystring       - `@query`

The following example uses rate limiting, and defines `middleware` that will override the inbuilt rate limiting logic:

```powershell
Server {
    # attach to port 8080
    listen *:8080 http

    # assign rate limiting to localhost, and allow 8 request per 5 seconds
    limit ip @('127.0.0.1', '[::1]') 8 5

    # create middleware to override the inbuilt rate limiting (to stop the limiting)
    middleware -Name '@limit' {
        return $true
    }

    # basic route
    route get '/' {
        # logic
    }
}
```

#### Sessions

Session `middleware` is supported in Pode on web requests/responses, in the form of signed-cookies and server-side data storage. When configured, the middleware will check for a session-cookie on the request; if a cookie is not found on the request, or the session is not in the store, then a new session is created and attached to the response. If there is a session, then the appropriate data is loaded from the store.

The age of the session-cookie can be specified (and whether to extend the duration each time), as well as a secret-key to sign cookies, and the ability to specify custom data stores - the default is in-mem, custom could be anything like redis/mongo.

The following is an example of how to setup session middleware:

```powershell
Server {

    middleware (session @{
        'Secret' = 'schwifty';  # secret-key used to sign session cookie
        'Name' = 'pode.sid';    # session cookie name (def: pode.sid)
        'Duration' = 120;       # duration of the cookie, in seconds
        'Extend' = $true;       # extend the duration of the cookie on each call
        'GenerateId' = {        # custom SessionId generator (def: guid)
            return [System.IO.Path]::GetRandomFileName()
        };
        'Store' = $null;        # custom object with required methods (def: in-mem)
    })

}
```

##### GenerateId

If supplied, the `GenerateId` must be a scriptblock that returns a valid string. The string itself should be a random unique value, that can be used as a session identifier. The default `sessionId` is a `guid`.

##### Store

If supplied, the `Store` must be a valid object with the following required functions:

```powershell
[hashtable] Get([string] $sessionId)
[void]      Set([string] $sessionId, [hashtable] $data, [datetime] $expiry)
[void]      Delete([string] $sessionId)
```

If no store is supplied, then a default in-memory store is used - with auto-cleanup for expired sessions.

To add data to a session you can utilise the `.Session.Data` object within a `route`. The data will be saved at the end of the route logic autmoatically using `endware`. When a request comes in using the same session, the data is loaded from the store. An example of using a `session` in a `route` to increment a views counter could be as follows (the counter will continue to increment on each call to the route until the session expires):

```powershell
Server {

    route 'get' '/' {
        param($s)
        $s.Session.Data.Views++
        json @{ 'Views' = $s.Session.Data.Views }
    }

}
```

### Authentication

Using middleware and sessions, Pode has support for authentication on web requests. This authentication can either be session-persistant (ie, logins on websites), or sessionless (ie, auths on rest api calls). Examples of both types can be seen in the `web-auth-basic.ps1` and `web-auth-forms.ps1` example scripts.

To use authentication in Pode there are two key commands: `auth use` and `auth check`.

* `auth use` is used to setup an auth type (basic/form/custom); this is where you specify a validator script (to check the user exists in your storage), any options, and if using a custom type a parser script (to parse headers/payloads to pass to the validator). An example:

    ```powershell
    Server {
        # auth use <type> -v {} [-o @{}]

        auth use basic -v {
            param($user, $pass)
            # logic to check user
            return @{ 'user' = $user }
        }
    }
    ```

    The validator (`-v`) script is used to find a user, checking if they exist and the password is correct. If the validator passes, then a `user` needs to be returned from the script via `@{ 'user' = $user }` - if `$null` or a null user are returned then the validator is assumed to have failed, and a 401 status will be thrown.

    Some auth methods also have options (`-o`) that can be supplied as a hashtable, such as field name or encoding overrides - more below.

* `auth check` is used in `route` calls, to check a specific auth method against the incoming request. If the validator defined in `auth use` returns no user, then the check fails with a 401 status; if a user is found, then it is set against the session (if session middleware is enabled) and the route logic is invoked. An example:

    ```powershell
    Server {
        # auth check <type> [-o @{}]

        route get '/users' (auth check basic) {
            param($session)
            # route logic
        }
    }
    ```

    This is the most simple call to check authentication, the call also accepts options (`-o`) in a hashtable:

    | Name | Description |
    | --- | ----------- |
    | FailureUrl | URL to redirect to should auth fail |
    | SuccessUrl | URL to redirect to should auth succeed |
    | Session | When true: check if the session already has a validated user, and store the validated user in the session (def: true) |
    | Login | When true: check the auth status in session and redirect to SuccessUrl, else proceed to the page with no auth required (def: false) |
    | Logout | When true: purge the session and redirect to the FailureUrl (def: false) |

If you have defined session-middleware to be used in your script, then when an `auth check` call succeeds the user with be authenticated against that session. When the user makes another call using the same session-cookie, then the `auth check` will detect the already authenticated session and skip the validator script. If you're using sessions and you don't want the `auth check` to check the session, or store the user against the session, then pass `-o @{ 'Session' = $false }` to the `auth check`.

> Not defining session middleware is basically like always having `Session = $false` set on `auth check`

#### Basic Auth

> Example with comments in `examples/web-auth-basic.ps1`

Basic authentication is when you pass a encoded username:password value on the header of your requests: `@{ 'Authorization' = 'Basic <base64 encoded username:password>' }`. To setup basic auth in Pode, you specify `auth use basic` in your server script; the validator script will have the username/password supplied as parameters:

```powershell
Server {
    auth use basic -v {
        param($username, $password)
    }
}
```

##### Options

| Name | Description |
| ---- | ----------- |
| Encoding | Defines which encoding to use when decoding the auth header (def: `ISO-8859-1`) |
| Name | Defines the name part of the header, infront of the encoded sting (def: Basic) |

#### Form Auth

> Example with comments in `examples/web-auth-form.ps1`

Form authentication is for when you're using a `<form>` in HTML, and you submit the form. The type expects a `username` and a `password` to be passed from the form input fields. To setup form auth in Pode, you specify `auth use form` in your server script; the validator script will have the username/password supplied as parameters:

```powershell
Server {
    auth use form -v {
        param($username, $password)
    }
}
```

```html
<form action="/login" method="post">
    <div>
        <label>Username:</label>
        <input type="text" name="username"/>
    </div>
    <div>
        <label>Password:</label>
        <input type="password" name="password"/>
    </div>
    <div>
        <input type="submit" value="Login"/>
    </div>
</form>
```

##### Options

| Name | Description |
| ---- | ----------- |
| UsernameField | Defines the name of field which the username will be passed in from the form (def: username) |
| PasswordField | Defines the name of field which the password will be passed in from the form (def: password) |

#### Custom Auth

Custom authentication works much like the above inbuilt types, but allows you to specify your own parsing logic. For example, let's say we wanted something similar to `form` authentication but it requires a third piece of information: ClientName. To setup a custom authentication, you can use any name and specify the `-c` flag; you'll also be required to specify the parsing scriptblock under `-p`:

```powershell
Server {
    auth use -c client -p {
        # the current web-session (same data as supplied to routes), and options supplied
        param($session, $opts)

        # get client/user/pass field names to get from payload
        $clientField = (coalesce $opts.ClientField 'client')
        $userField = (coalesce $opts.UsernameField 'username')
        $passField = (coalesce $opts.PasswordField 'password')

        # get the client/user/pass from the post data
        $client = $session.Data.$clientField
        $username = $session.Data.$userField
        $password = $session.Data.$passField

        # return the data, to be passed to the validator script
        return @($client, $username, $password)
    } `
    -v {
        param($client, $username, $password)

        # find the user
        # if not found, return null - for a 401

        # return the user
        return  @{ 'user' = $user }
    }

    route get '/users' (auth check client) {
        param($session)
    }
}
```

### SMTP Server

Pode can also run as an SMTP server - useful for mocking tests. There are two options, you can either use Pode's inbuilt simple SMTP logic, or write your own using Pode as a TCP server instead.

If you're using Pode's unbuilt SMTP logic, then you need to state so when creating the server: `Server -Smtp`. This will automatically create a TCP listener on port 25 (unless you pass a different port number).

Unlike with HTTP Routes, TCP and SMTP can only have one handler. To create a handler for the inbuilt logic:

```powershell
Server -Smtp {
    handler 'smtp' {
        param($session)
        Write-Host $session.From
        Write-Host $session.To
        Write-Host $session.Data
    }
}
```

The SMTP Handler will be passed a session already populated with the `From` address, the single or multiple `To` addresses, and the raw `Data` of the mail body.

> This can be seen in the examples under `mail-server.ps1`

If you want to create you own SMTP server, then you'll need to set Pode up as a TCP listener and manually read the SMTP stream yourself:

```powershell
Server {
    listen *:25 tcp

    handler 'tcp' {
        param($session)
        $client = $session.Client
        # your stream writing/reading here
    }
}
```

To help with writing and reading from the client stream, Pode has a helper function with two actions for `read` and `write`:

* `tcp write $msg`
* `$msg = (tcp read)`

### Misc

#### Logging

Allows you to define `Logger`s within a Server that will send [Combined Log Format](https://httpd.apache.org/docs/1.3/logs.html#combined) rows to either the terminal, a file, or a custom scriptblock that allows you to log to a variety of services - e.g. Splunk/FluentD/LogStash

An example of logging to the terminal, and to a file with removal of old log files after 7 days:

```powershell
Server {
    listen *:8085 http

    logger 'terminal'
    logger 'file' @{
        'Path' = '<path_to_put_logs>';
        'MaxDays' = 7;
    }

    # GET "localhost:8085/"
    route 'get' '/' {
        param($session)
        view 'simple' -Data @{ 'numbers' = @(1, 2, 3); }
    }
}
```

The hashtable supplied to `logger 'file'` is completely optional. If no Path is supplied then a `logs` directory will be created at the server script root path, and if `MaxDays is <= 0` then log files will be kept forever.

* If `Path` is supplied, then the logs will be placed at that location (and any directories along that path are created).
* If `MaxDays` is supplied, then once a day Pode will clean-up log files older than that many days.

Custom loggers must have a name like `custom_*` and have a supplied scriptblock. When the scriptblock is invoked, the log request object will be passed to it:

```powershell
logger 'custom_output' {
    param($session)
    $session.Log.Request.Resource | Out-Default
}
```

The `$session` object passed contains a `Log` which will have the following structure:

```powershell
@{
    'Host' = '10.10.0.3';
    'RfcUserIdentity' = '-';
    'User' = '-';
    'Date' = '14/Jun/2018:20:23:52 +01:00';
    'Request' = @{
        'Method' = 'GET';
        'Resource' = '/api/users';
        'Protocol' = "HTTP/1.1";
        'Referrer' = '-';
        'Agent' = '<user-agent>';
    };
    'Response' = @{
        'StatusCode' = '200';
        'StautsDescription' = 'OK'
        'Size' = '9001';
    };
}
```

#### Shared State

Routes, timers, and loggers in Pode all run within separate runspaces; this means normally you can't create a variable in a timer and then access that variable in a route.

Pode overcomes this by allowing you to set/get/remove custom variables on the session state shared between runspaces. This means you can create a variable in a timer and set it against the shared state; then you can retrieve that variable from the state in a route.

To do this, you use the `state` function with an action of `set`, `get` or `remove`, in combination with the `lock` function to ensure thread safety. Each  state action requires you to supply a name, and `set` takes the variable itself.

The following example is a simple `timer` to create and update a `hashtable`, and then retrieve that variable in a `route` (this can also be seen in `examples/shared-state.ps1`):

> If you omit the use of `lock`, you will run into errors due to multi-threading. Only omit if you are absolutely confident you do not need locking. (ie: you set in state once and then only ever retrieve, never updating the variable). Routes, timers, and custom loggers are all supplied a `Lockable` resource you can use with `lock`.

```powershell
Server {
    listen *:8085 http

    # create timer to update a hashtable and make it globally accessible
    timer 'forever' 2 {
        param($session)
        $hash = $null

        # create a lock on a pode lockable resource for safety
        lock $session.Lockable {

            # first, attempt to get the hashtable from the state
            $hash = (state get 'hash')

            # if it doesn't exist yet, set it against the state
            if ($hash -eq $null) {
                $hash = (state set 'hash' @{})
                $hash['values'] = @()
            }

            # every 2secs, add a random number
            $hash['values'] += (Get-Random -Minimum 0 -Maximum 10)
        }
    }

    # route to retrieve and return the value of the hashtable from global state
    route get '/get-array' {
        param($session)

        # create another lock on the same lockable resource
        lock $session.Lockable {

            # get the hashtable defined in the timer above, and return it as json
            $hash = (state get 'hash')
            json $hash
        }
    }

}
```

> You can put any type of variable into the global state, including `scriptblock`s

#### File Monitor

> Note: For docker you'll need to use any of the tags labeled "-ps.6.1.0-preview", and on Unix you will need dotnet-core 2.1 installed

Pode has inbuilt file monitoring that can be enabled, whereby Pode will trigger an internal server restart if it detects file changes within the same directory as your Pode script. To enable the monitoring supply the `-FileMonitor` switch to your `Server`:

```powershell
Server {
    # logic
} -FileMonitor
```

Once enabled, Pode will actively monitor all file changes within the directory of your script - if your script was at `C:/Apps/Pode/server.ps1`, then Pode will monitor the `C:/Apps/Pode` directory and sub-directories. When a change is detected, Pode will wait a couple of seconds before triggering the restart; this is so multiple rapid changes don't trigger multiple restarts.

Changes being monitored are:

* Updates
* Creation
* Deletion

Please note that if you change the main server script itself, those changes will not be picked up. It's best to import/dot-source other modules/scripts into your `Server` scriptblock, as the internal restart re-executes this scriptblock. If you do make changes to the main server script, you'll need to terminate and restart the server.

#### Access Rules

Access rules in Pode allow you to specify allow/deny rules for IP addresses and subnet masks. This means you can deny certain IPs from accessing the server, and vice-versa by allowing them. You use `access` within your `Server`, specifying the permission, type and IP/subnet:

```powershell
Server {
    # allow access from localhost
    access allow ip 127.0.0.1

    # allow access from multiple IPs
    access allow ip @('192.168.1.1', '192.168.1.2')

    # deny access from a subnet
    access deny ip '10.10.0.0/24'

    # deny access from everything
    access deny ip all
}
```

If an IP hits your server that you've denied access, then a `403` response is returned and the connection immediately closed. For SMTP/TCP servers the connection is just closed with no response.

#### Rate Limiting

Pode has basic support for rate limiting requests for IP addresses and subnet masks. This allows you to cap the number of requests for an IP/subnet over a given number of seconds. When limiting a subnet you can choose to either individually limit each IP address in a subnet, or you can group all IPs in a subnet together under a single cap.

To start rate limiting, you can use `limit` within your `Server`, specifying the type, IP/subnet, limit and number of seconds the limit lasts for:

```powershell
Server {
    # limit localhost to 5 requests per second
    limit ip 127.0.0.1 -limit 5 -seconds 1

    # limit multiple IPs to 5 request per 10secs
    limit ip @('192.168.1.1', '192.168.1.2') 5 10

    # limit a subnet to 5reqs per 1sec, per IP
    limit ip '10.10.0.0/24' 5 1

    # limit a subnet to 5reqs per 1sec, all IPs as one
    limit ip '10.10.0.0/24' 5 1 -group

    # limit everything to 10reqs per 1min
    limit ip all 10 60
}
```

If an IP/subnet hits the limit within the given period, then a `429` response is returned and the connection immediately closed. For SMTP/TCP servers the connection is just closed with no response.

#### External Scripts

Because Pode runs most things in isolated runspaces, importing and using external scripts/modules to Pode can be quite bothersome. To overcome this, Pode has an inbuilt `script` call that will allow you to declare modules that need to be imported into each runspace.

The `script` takes a path to a module (`.psm1` file), can be literal or relative, and adds it to the session state for each runspace pool.

```powershell
Server {
    script './path/to/module.psm1'
}
```

> This will now allow the functions defined in the `module.psm1` file to be accessible to timers, routes, scheduled, etc.

#### Certificates

> Binding existing, and generating self-signed certificates is only supported on Windows

Pode has the ability to generate and bind self-signed certificates (for dev/testing), as well as the ability to bind existing - already installed - certificates for HTTPS. If Pode detects that the IP:Port binding already has a certificate bound, then Pode will not create a self-signed cert, or bind a new certificate - you'll have to clean-up the binding first: `netsh http delete sslcert 0.0.0.0:8443`.

For example, if you are developing/testing a site on HTTPS then Pode can generate and bind quick self-signed certificates. To do this you can pass the value `"self"` to the `-cert` parameter of `listen`:

```powershell
Server {
    listen *:8443 https -cert self
}
```

To bind a signed certificate, the certificate *must* be installed to `Cert:/LocalMachine/My`; then you can pass the certificate name/domain to `-cert`. An example for `*.example.com`:

```powershell
Server {
    listen *:8443 https -cert '*.example.com'
}
```

### Helpers

#### Attach File

`Attach` is a helper function to aid attaching files to a response, so that they can be downloaded on the client end. Files to attach must be placed within the `public/` directory, much like the content files for JavaScript and CSS.

An example of attaching a file to a response in a route is as follows, and here it will start a download of the file at `public/downloads/installer.exe`:

```powershell
Server {
    listen *:8080 http

    route get '/app/install' {
        param($session)
        attach 'downloads/installer.exe'
    }
}
```

#### Status Code

`Status` is a helper function to aid setting the status code and description on the response. When called you must specify a status code, and the description is optional.

```powershell
Server {
    listen *:8080 http

    # returns a 404 code
    route get '/not-here' {
        status 404
    }

    # returns a 500 code, with description
    route get '/eek' {
        status 500 'oh no! something went wrong!'
    }
}
```

#### Redirect

`Redirect` is a helper function to aid URL redirection from the server. You can either redirect via a 301 or 302 code - the default is a 302 redirect.

```powershell
Server {
    listen *:8080 http

    # redirects to google
    route get '/redirect' {
        redirect -url 'https://google.com'
    }

    # moves to google
    route get '/moved' {
        redirect -moved -url 'https://google.com'
    }

    # redirect to different port - same host, path and query
    route get '/redirect-port' {
        redirect -port 8086
    }

    # redirect to same host, etc; but this time to https
    route get '/redirect-https' {
        redirect -protocol https
    }

    # redirect every method and route to https
    route * * {
        redirect -protocol https
    }
}
```

Supplying `-url` will redirect literally to that URL, or you can supply a relative path to the current host. `-port` and `-protocol` can be used separately or together, but not with `-url`. Using `-port`/`-protocol` will use the URI object in the current Request to generate the redirect URL.

## Pode Files

Using Pode to write dynamic HTML files are mostly just an HTML file - in fact, you can write pure HTML and still be able to use it. The difference is that you're able to embed PowerShell logic into the file, which allows you to dynamically generate HTML.

To use Pode files, you will need to place them within the `/views/` folder. Then you'll need to set the View Engine to be Pode; once set, you can just write view responses as per normal:

> Any PowerShell in a Pode files will need to use semi-colons to end each line

```powershell
Server {
    listen *:8080 http

    # set the engine to use and render Pode files
    engine pode

    # render the index.pode view
    route 'get' '/' {
        param($session)
        view 'index'
    }
}
```

Below is a basic example of a Pode file which just writes the current date to the browser:

```html
<!-- /views/index.pode -->
<html>
    <head>
        <title>Current Date</title>
    </head>
    <body>
        <span>$([DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss');)</span>
    </body>
</html>
```

> When you need to use PowerShell, ensure you wrap the commands within `$(...)`, and end each line with a semi-colon (as you would in C#/Java)

You can also supply data to the `view` function when rendering Pode files. This allows you to make them far more dynamic. The data supplied to `view` must be a `hashtable`, and can be referenced within the file by using the `$data` argument.

For example, say you need to render a search page which is a list of accounts, then you're basic Pode script would look like:

```powershell
Server {
    listen *:8080 http

    # set the engine to use and render Pode files
    engine pode

    # render the search.pode view
    route 'get' '/' {
        param($session)

        # some logic to get accounts
        $query = $session.Query['query']
        $accounts = Find-Account -Query $query

        # render the file
        view 'search' -Data @{ 'query' = $query; 'accounts' = $accounts; }
    }
}
```

You can see that we're supplying the found accounts to the `view` function as a `hashtable`. Next, we see the `search.pode` file which generates the HTML:

```html
<!-- /views/search.pode -->
<html>
    <head>
        <title>Search</title>
    </head>
    <body>
        <h1>Search</h1>
        Query: $($data.query;)

        <div>
            $(foreach ($account in $data.accounts) {
                "<div>Name: $($account.Name)</div><hr/>";
            })
        </div>
    </body>
</html>
```

> Remember, you can access supplied data by using `$data`

This next quick example allows you to include content from another view:

```html
<!-- /views/index.pode -->
<html>
    $(include shared/head)

    <body>
        <span>$([DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss');)</span>
    </body>
</html>

<!-- /views/shared/head.pode -->
<head>
    <title>Include Example</title>
</head>
```

### Non-View Pode Files

The rules for using Pode files for other types, like public css/js, work exactly like the above view files but they're placed within the `/public/` directory instead of the `/views/` directory. You also need to specify the actual file type in the extension, for example:

```plain
/public/styles/main.css.pode
/public/scripts/main.js.pode
```

Here you'll see the main extension is `pode`, but you need to specify a sub-extension of the main file type - this helps Pode work out the main content type.

Below is a `.css.pode` file that will render the page in purple on even seconds, or red on odd seconds:

```css
/* /public/styles/main.css.pode */
body {
    $(
        $date = [DateTime]::UtcNow;

        if ($date.Second % 2 -eq 0) {
            "background-color: rebeccapurple;";
        } else {
            "background-color: red;";
        }
    )
}
```

To load the above `.css.pode` file:

```html
<!-- /views/index.pode -->
<html>
   <head>
      <link rel="stylesheet" href="styles/main.css.pode">
   </head>
   <body>
        <span>$([DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss');)</span>
    </body>
</html>
```

## Third-Party View Engines

Pode also supports the use of third-party view engines, for example you could use the [EPS](https://github.com/straightdave/eps) template engine. To do this, you'll need to supply a custom scriptblock to `Engine` which tells Pode how use the third-party engine.

If you did use `EPS`, then the following example would work:

```powershell
Server {
    listen *:8080 http

    # set the engine to use and render EPS files (could be index.eps, or for content scripts.css.eps)
    # the scriptblock requires the "param($path, $data)"
    engine eps {
        param($path, $data)
        return Invoke-EpsTemplate -Path $path -Binding $data
    }

    # render the index.eps view
    route 'get' '/' {
        param($session)
        view 'index'
    }
}
```

## FAQ

* Running `pode start` throws an `ImportPSModule` error.
  > This error occurs when you are using the source code for Pode, and also have the Pode module installed. To resolve you can do one of the following:
  > * Uninstall the Pode module from PowerShell, and re-`Import-Module` the source code version
  > * Manually call the `start` script
  > * Remove calls to `Remove-Module -Name Pode` within your scripts

## Inbuilt Functions

Pode comes with a few helper functions - mostly for writing responses and reading streams:

* `route`
* `handler`
* `engine`
* `timer`
* `logger`
* `html`
* `xml`
* `json`
* `csv`
* `view`
* `tcp`
* `status`
* `redirect`
* `include`
* `lock`
* `state`
* `listen`
* `access`
* `limit`
* `stopwatch`
* `dispose`
* `stream`
* `schedule`
* `middleware`
* `endware`
* `session`
* `auth`
* `attach`