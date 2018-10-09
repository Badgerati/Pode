# Status Codes

By default Pode will return a status code of `200` on success, or `404` if the route/path cannot be found.

## Usage

The [`status`](../../../Functions/Response/Status) function allows you to set your own status code on the response, as well as a custom status description.

The make-up of the `status` function is as follows:

```powershell
status <number> [-description <string>]

# or shorthand
status <number> [-d <string>]
```

The following example will set the status code of the response to be `418`:

```powershell
Server {
    listen *:8080 http

    route get '/teapot' {
        status 418
    }
}
```

Where as the next example will return a `503` with a custom description:

```powershell
Server {
    listen *:8080 http

    route get '/eek' {
        status 503 -d 'oh no! something went wrong!'
    }
}
```
