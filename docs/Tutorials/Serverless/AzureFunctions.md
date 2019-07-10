# Azure Functions

Pode has support for being used within HTTP Azure PowerShell Functions, helping you with routing and responses.

## Setup

First, you'll need to have the Pode module saved within your Azure Function. At the root of your Azure PowerShell Functions run the following:

```powershell
Save-Module -Name Pode -Path ./Modules/ -Force
```

With this, the Pode module will be automatically loaded by Azure for your Functions.

## Usage

### Parameters

Your PowerShell Function script has only one requirement, you need to have the `$TriggerMetadata` passed into your script:

```powershell
param($Request, $TriggerMetadata)
```

The metadata also contains the Request object, as well as other information required by Pode.

Your Function's `function.json` will also need to contain at a minimum the Request and Response:

```json
{
  "bindings": [
    {
      "authLevel": "<anything>",
      "type": "httpTrigger",
      "direction": "in",
      "name": "Request",
      "methods": ["<allowed-methods>"]
    },
    {
      "type": "http",
      "direction": "out",
      "name": "Response"
    }
  ]
}
```

### The Server

With the above being done, your Pode `server` can be created as follows:

```powershell
Start-PodeServer -Request $TriggerMetadata -Type 'azure-functions' {
    # logic
}
```

### Routing

Typically your Azure Function will be located at the `/api/<name>` endpoint. Let's say you have some Function called `MyFunc`, and within its `functions.json` file you've enabled `GET`, `POST`, and `PUT`.

The following `run.ps1` would be a simple example of using Pode to aid with routing in this Function:

```powershell
param($Request, $TriggerMetadata)
$endpoint = '/api/MyFunc'

Start-PodeServer -Request $TriggerMetadata -Type 'azure-functions' {
    # get route that can return data
    route get $endpoint {
        Write-PodeJsonResponse -Value @{ 'Data' = 'some random data' }
    }

    # post route to create some data
    route post $endpoint {
        param($e)
        New-Thing -Name $e.Data['Name']
    }

    # put route to update some data
    route put $endpoint {
        param($e)
        Update-Thing -Name $e.Data['Name']
    }
}
```

### Websites

You can render websites using Pode as well. Let's say you create a `/www` directory at the root of your project, within here you can place your normal `/views`, `/public` and `/errors` directories - as well as your `pode.json` file.

All you need to do then is reference this directory as the root path for your server:

```powershell
param($Request, $TriggerMetadata)
$endpoint = '/api/MyFunc'

Start-PodeServer -Request $TriggerMetadata -Type 'azure-functions' -RootPath '../www' {
    # set your engine renderer
    Set-PodeViewEngine -Type Pode

    # get route for your 'index.pode' view
    route get $endpoint {
        Write-PodeViewResponse -Path 'index'
    }
}
```

### Static Content

Serving up static content in Azure Functions is a little weird, as you have to reference the main endpoint but with a query of `static-file` and then the path.

For example, if you have a CSS stylesheet at `/www/styles/main.css.pode`, then your `index.pode` view would get this as such:

```html
<html>
    <head>
        <title>Example</title>
        <link rel="stylesheet" type="text/css" href="/api/MyFunc?static-file=/styles/main.css.pode">
    </head>
    <body>
        <img src="/api/MyFunc?static-file=/SomeImage.jpg" />
    </body>
</html>
```

## Responses

You've likely noticed that no reference to Azure PowerShell Function's `Push-OutputBinding` was made. This is because Pode will handle all of the responses for you, from the Status Code and Body, to Headers and Cookies.