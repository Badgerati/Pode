# Azure Functions

Pode has support for being used within HTTP Azure PowerShell Functions, helping you with routing and responses, but also leveraging middleware, authentication, and other features of Pode.

## Overview

When you use Pode in a serverless environment, the server logic is run once, and the route logic immediately parsed; any response is returned, and the server disposed. Unlike the normal web-server logic of Pode, when in serverless the server logic doesn't continually loop.

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
Start-PodeServer -Request $TriggerMetadata -Type 'AzureFunctions' {
    # logic
}
```

### Routing

Typically your Azure Function will be located at the `/api/<name>` endpoint. Let's say you have some Function called `MyFunc`, and within its `functions.json` file you've enabled `GET`, `POST`, and `PUT`.

The following `run.ps1` would be a simple example of using Pode to aid with routing in this Function:

```powershell
param($Request, $TriggerMetadata)
$endpoint = '/api/MyFunc'

Start-PodeServer -Request $TriggerMetadata -Type 'AzureFunctions' {
    # get route that can return data
    Add-PodeRoute -Method Get -Path $endpoint -ScriptBlock {
        Write-PodeJsonResponse -Value @{ 'Data' = 'some random data' }
    }

    # post route to create some data
    Add-PodeRoute -Method Post -Path $endpoint -ScriptBlock {
        New-Thing -Name $WebEvent.Data['Name']
    }

    # put route to update some data
    Add-PodeRoute -Method Put -Path $endpoint -ScriptBlock {
        Update-Thing -Name $WebEvent.Data['Name']
    }
}
```

### Websites

You can render websites using Pode as well. Let's say you create a `/www` directory at the root of your project, within here you can place your normal `/views`, `/public` and `/errors` directories - as well as your `server.psd1` file.

All you need to do then is reference this directory as the root path for your server:

```powershell
param($Request, $TriggerMetadata)
$endpoint = '/api/MyFunc'

Start-PodeServer -Request $TriggerMetadata -Type 'AzureFunctions' -RootPath '../www' {
    # set your engine renderer
    Set-PodeViewEngine -Type Pode

    # get route for your 'index.pode' view
    Add-PodeRoute -Method Get -Path $endpoint -ScriptBlock {
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

## Unsupported Features

Unfortunately not all the features of Pode can be used within a serverless environment. Below is a list of features in Pode that cannot be used when running in a serverless context:

* Access Middleware
* Limit Middleware
* Opening your server as a GUI
* TCP/Service Handler logic
* Listening on endpoints (as Azure Functions does this for us)
* Schedules
* Timers
* File Monitoring
* Server Restarting
