# Redirecting

Sometimes you just want a `route` to redirect the user else where, be it to another URL or to the same route just a different port/protocol.

## Usage

When in a `route`, to inform the client to redirect to a different endpoint you can use the [`redirect`](../../../Functions/Response/Redirect) function.

The make-up of the `redirect` function is as follows:

```powershell
redirect [-port <int>] [-protocol <http|https>] [-moved]
redirect [-url <string>] [-moved]

# or shorthand:
redirect [-p <int>] [-pr <http|https>] [-m]
redirect [-u <string>] [-m]
```

Supplying `-url` will redirect the user to that URL, or you can supply a relative path o the server for the user to be redirected to. `-port` and `-protocol` can be used separately or together, but not with `-url`. Using `-port`/`-protocol` will use the URI of the current web request to generate the redirect URL.

By default the `redirect` function will return a `302` response, but supplying `-moved` will return a `301` response instead.

The following example will redirect the user to Google:

```powershell
Server {
    listen *:8080 http

    route get '/redirect' {
        redirect -url 'https://google.com'
    }
}
```

The below example will redirect the user to the same host/server, but with a different protocol and port:

```powershell
Server {
    listen *:8080 http

    route get '/redirect' {
        redirect -port 8086 -protocol https
    }
}
```

This final example will redirect every route path, on every action, to https:

```powershell
Server {
    listen *:8080 http

    route * * {
        redirect -port 443 -protocol https
    }
}
```