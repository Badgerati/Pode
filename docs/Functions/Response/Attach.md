# Attach

## Description

The `attach` function allows you to attach files in the `/public` directory, as well as custom static route directories, onto the web response. This allows the files to be downloaded by the end-user.

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

### Example 2

The following example attaches the image found at `/content/assets/images/icon.png` onto the response, when the `http://localhost:8080/app/icon` endpoint is hit:

```powershell
Server {
    listen *:8080 http

    route static '/assets' './content/assets'

    route get '/app/icon' {
        attach '/assets/images/icon.png'
    }
}
```

## Parameters

| Name | Type | Required | Description | Default |
| ---- | ---- | -------- | ----------- | ------- |
| Path | string | true | The path to the file to attach, relative to your `/public` directory | null |
