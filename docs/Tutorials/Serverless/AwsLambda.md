# AWS Lambda

Pode has support for being used within AWS Lambda PowerShell Functions, helping you with routing and responses.

## Usage

### Module

Your PowerShell Function script will need to have the Pode module imported, so it can be used. To do this, the following line is required at the top of your script (as well as the normal AWS module):

```powershell
#Requires -Modules @{ModuleName='AWSPowerShell.NetCore';ModuleVersion='3.3.509.0'}
#Requires -Modules @{ModuleName='Pode';ModuleVersion='<version>'}
```

### Template

One Function can accept many routes if you setup the template. Your SAM/serverless YAML template could look as follows:

```yaml
AWSTemplateFormatVersion : '2010-09-09'
Transform: 'AWS::Serverless-2016-10-31'
Resources:
  ExampleFunction:
    Type: 'AWS::Serverless::Function'
    Properties:
      Handler: 'Example::Example.Bootstrap::ExecuteFunction'
      Runtime: dotnetcore2.1
      CodeUri: Example.zip
      Timeout: 60
      MemorySize: 256
      Events:
        Example:
          Type: Api
          Properties:
            Path: /{proxy+}
            Method: get
```

Here, the `/{proxy+}` will enable one Function for all routes - which can be controlled via Pode within your Function.

### The Server

With the above being done, your Pode `server` can be created as follows. The `$LambdaInput` is a parameter supplied to your Function by AWS:

```powershell
Start-PodeServer -Request $LambdaInput -Type 'AwsLambda' {
    # logic
}
```

### Routing

Let's say for your Function you have it setup for multiple routes, and you've enabled the `GET` method.

The following script would be a simple example of using Pode to aid with routing in this Function:

```powershell
#Requires -Modules @{ModuleName='AWSPowerShell.NetCore';ModuleVersion='3.3.509.0'}
#Requires -Modules @{ModuleName='Pode';ModuleVersion='<version>'}

Start-PodeServer -Request $LambdaInput -Type 'AwsLambda' {
    # get some user data
    Add-PodeRoute -Method Get -Path '/users' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ 'Users' = @() }
    }

    # get some messages data
    Add-PodeRoute -Method Get -Path '/message' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ 'UserId' = 123; 'Messages' = @() }
    }
}
```

### Websites

You can render websites using Pode as well. To do this in Lambda Functions you'll need to upload your website files to some S3 bucket. In here you can place your normal `/views`, `/public` and `/errors` directories - as well as your `pode.json` file.

Then within your Function script, you need to read in the data from your S3 bucket to some path your Function can access. Once read in, you need to then reference this directory as the root path for your server:

```powershell
#Requires -Modules @{ModuleName='AWSPowerShell.NetCore';ModuleVersion='3.3.509.0'}
#Requires -Modules @{ModuleName='Pode';ModuleVersion='<version>'}

Read-S3Object -BucketName '<bucket-name>' -KeyPrefix '<dir-name>' -Folder '/tmp/www' | Out-Null

Start-PodeServer -Request $LambdaInput -Type 'AwsLambda' -RootPath '/tmp/www' {
    # set your engine renderer
    Set-PodeViewEngine -Type Pode

    # get route for your 'index.pode' view
    Add-PodeRoute -Method Get -Path '/home' -ScriptBlock {
        Write-PodeViewResponse -Path 'index'
    }
}
```

### Static Content

Unlike Azure Functions, static content in AWS Functions can be served up in the normal way - assuming your function can recieve multiple routes.

For example, if you have a CSS stylesheet at `/tmp/www/styles/main.css.pode`, then your `index.pode` view would get this as such:

```html
<html>
    <head>
        <title>Example</title>
        <link rel="stylesheet" type="text/css" href="/styles/main.css.pode">
    </head>
    <body>
        <img src="/SomeImage.jpg" />
    </body>
</html>
```

## Responses

Pode will handle returning an appropriate response object for you, dealing with the Status Code, Body, Headers, etc. There's no need to return the normal hashtable from your Function.