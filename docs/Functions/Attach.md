# Status

## Description

The `attach` function allows you to attach files in the `/public` directory onto the web response. This allows the files to be downloaded by the end-user.

## Examples

### Example 1

The following example attaches the installer found at `/public/downloads/installer.exe` onto the response, when the `http://localhost:8080/app/install` endpoint is hit:

```powershell
Server {
    listen *:8080 http

    route get '/app/install' {
        attach 'downloads/installer.exe'
    }
}
```

## Parameters

| Name | Type | Required | Description | Default |
| ---- | ---- | -------- | ----------- | ------- |
| Path | string | true | The path to the file to attach, relative to your `/public` directory | null |
