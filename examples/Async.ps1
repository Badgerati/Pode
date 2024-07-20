<#
.SYNOPSIS
    A script to either run a Pode server with various endpoints or to send multiple REST requests to the server.

.DESCRIPTION
    This script sets up a Pode server with multiple endpoints demonstrating asynchronous operations and authorization.
    It also includes examples of how to send REST requests to the server.

.PARAMETER Port
    The port on which the Pode server will listen. Default is 8080.

.PARAMETER Quiet
    Suppresses output when the server is running.

.PARAMETER DisableTermination
    Prevents the server from being terminated.

.EXAMPLE
    .\PodeServer.ps1 -Port 9090 -Quiet -DisableTermination

.EXAMPLE
    # Example of using the endpoints with Invoke-RestMethod
    $mortyCommonHeaders = @{
        'accept'        = 'application/json'
        'X-API-KEY'     = 'test-api-key'
        'Authorization' = 'Basic bW9ydHk6cGlja2xl'
    }

    $mindyCommonHeaders = @{
        'accept'        = 'application/json'
        'X-API-KEY'     = 'test2-api-key'
        'Authorization' = 'Basic bWluZHk6cGlja2xl'
    }

    $response_asyncUsingNotCancelable = Invoke-RestMethod -Uri 'http://localhost:8080/auth/asyncUsingNotCancelable' -Method Put -Headers $mortyCommonHeaders
    $response_asyncUsingCancelable = Invoke-RestMethod -Uri 'http://localhost:8080/auth/asyncUsingCancelable' -Method Put -Headers $mortyCommonHeaders

    $body = @{
        callbackUrl = 'http://localhost:8080/receive/callback'
    } | ConvertTo-Json

    $headersWithContentType = $mortyCommonHeaders.Clone()
    $headersWithContentType['Content-Type'] = 'application/json'

    $response_asyncUsing = Invoke-RestMethod -Uri 'http://localhost:8080/auth/asyncUsing' -Method Put -Headers $headersWithContentType -Body $body

    $response_asyncState = Invoke-RestMethod -Uri 'http://localhost:8080/auth/asyncState' -Method Put -Headers $mortyCommonHeaders

    $response_asyncParam = Invoke-RestMethod -Uri 'http://localhost:8080/auth/asyncParam' -Method Put -Headers $mortyCommonHeaders

    $response_asyncWaitForeverTimeout = Invoke-RestMethod -Uri 'http://localhost:8080/auth/asyncWaitForeverTimeout' -Method Put -Headers $mortyCommonHeaders

    $response = Invoke-RestMethod -Uri 'http://localhost:8080/tasks' -Method Post -Body '{}' -Headers $mortyCommonHeaders



$response_Mindy_asyncWaitForever = Invoke-RestMethod -Uri 'http://localhost:8080/auth/asyncWaitForever' -Method Put -Headers $mindyCommonHeaders

    $response_Mindy_asyncUsingNotCancelable = Invoke-RestMethod -Uri 'http://localhost:8080/auth/asyncUsingNotCancelable' -Method Put -Headers $mindyCommonHeaders
    $response_Mindy_asyncUsingCancelable = Invoke-RestMethod -Uri 'http://localhost:8080/auth/asyncUsingCancelable' -Method Put -Headers $mindyCommonHeaders
    $response_Mindy_asyncStateNoColumn = Invoke-RestMethod -Uri 'http://localhost:8080/auth/asyncStateNoColumn' -Method Put -Headers $mindyCommonHeaders

    $headersWithContentType = $mindyCommonHeaders.Clone()
    $headersWithContentType['Content-Type'] = 'application/json'
    $response_Mindy_asyncUsing = Invoke-RestMethod -Uri 'http://localhost:8080/auth/asyncUsing' -Method Put -Headers $headersWithContentType -Body $body

    $response_Mindy_asyncState = Invoke-RestMethod -Uri 'http://localhost:8080/auth/asyncState' -Method Put -Headers $mindyCommonHeaders

    $response_Mindy_asyncParam = Invoke-RestMethod -Uri 'http://localhost:8080/auth/asyncParam' -Method Put -Headers $mindyCommonHeaders

    $response_Mindy_asyncWaitForeverTimeout = Invoke-RestMethod -Uri 'http://localhost:8080/auth/asyncWaitForeverTimeout' -Method Put -Headers $mindyCommonHeaders

$response = Invoke-RestMethod -Uri 'http://localhost:8080/tasks' -Method Post -Body '{}' -Headers $mindyCommonHeaders

$response_Mindy_asyncWaitForever = Invoke-RestMethod -Uri "http://localhost:8080/task?taskId=$($response_Mindy_asyncWaitForever.ID)" -Method Delete -Headers $mindyCommonHeaders

.NOTES
    Author: Pode Team
    License: MIT License
#>
param(
    [Parameter()]
    [int]
    $Port = 8080,
    [switch]
    $Quiet,
    [switch]
    $DisableTermination
)

try {
    # Determine the script path and Pode module path
    $ScriptPath = (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
    $podePath = Split-Path -Parent -Path $ScriptPath

    # Import the Pode module from the source path if it exists, otherwise from installed modules
    if (Test-Path -Path "$($podePath)/src/Pode.psm1" -PathType Leaf) {
        Import-Module "$($podePath)/src/Pode.psm1" -Force -ErrorAction Stop
    }
    else {
        Import-Module -Name 'Pode' -MaximumVersion 2.99 -ErrorAction Stop
    }
}
catch { throw }

# or just:
# Import-Module Pode

<#
# Demostrates Lockables, Mutexes, and Semaphores
#>

Start-PodeServer -Threads 1 -Quiet:$Quiet -DisableTermination:$DisableTermination {

    Add-PodeEndpoint -Address localhost -Port $Port -Protocol Http -DualMode
    New-PodeLoggingMethod -name 'async' -File  -Path "$ScriptPath/logs" | Enable-PodeErrorLogging

    # request logging
    # New-PodeLoggingMethod -Terminal | Enable-PodeRequestLogging

    Enable-PodeOpenApi -Path '/docs/openapi' -OpenApiVersion '3.0.3'  -DisableMinimalDefinitions -NoDefaultResponses

    Add-PodeOAInfo -Title 'Async test - OpenAPI 3.0' -Version 0.0.1

    Enable-PodeOAViewer -Type Swagger -Path '/docs/swagger'

    Enable-PodeOAViewer -Editor -Path '/docs/swagger-editor'
    Enable-PodeOAViewer -Bookmarks -Path '/docs'
    $uSleepTime = 4
    $uMessage = 'coming from using'

    #  $global:gMessage = 'coming from global'
    #   $global:gSleepTime = 3
    Set-PodeState -Name 'data' -Value @{
        sleepTime = 5
        Message   = 'coming from a PodeState'
    }


    # setup access
    New-PodeAccessScheme -Type Role | Add-PodeAccess -Name 'Rbac'
    New-PodeAccessScheme -Type Group | Add-PodeAccess -Name 'Gbac'

    # setup a merged access
    Merge-PodeAccess -Name 'MergedAccess' -Access 'Rbac', 'Gbac' -Valid All

    $testApiKeyUsers = @{
        'M0R7Y302' = @{
            ID     = 'M0R7Y302'
            Name   = 'Morty'
            Type   = 'Human'
            Roles  = @('Manager')
            Groups = @('Software')
        }
        'MINDY021' = @{
            ID     = 'MINDY021'
            Name   = 'Mindy'
            Type   = 'AI'
            Roles  = @('Developer')
            Groups = @('Support')
        }
    }


    $testBasicUsers = @{
        'M0R7Y302' = @{
            ID     = 'M0R7Y302'
            Name   = 'Morty'
            Type   = 'Human'
            Roles  = @('Developer')
            Groups = @('Platform')
        }
        'MINDY021' = @{
            ID     = 'MINDY021'
            Name   = 'Mindy'
            Type   = 'AI'
            Roles  = @('Developer')
            Groups = @('Software')
        }
    }



    # setup apikey auth
    New-PodeAuthScheme -ApiKey -Location Header | Add-PodeAuth -Name 'ApiKey' -Sessionless -ScriptBlock {
        param($key)

        # here you'd check a real user storage, this is just for example
        if ($key -ieq 'test-api-key') {
            return @{
                User = ($using:testApiKeyUsers).M0R7Y302
            }
        }
        if ($key -ieq 'test2-api-key') {
            return @{
                User = ($using:testApiKeyUsers).MINDY021
            }
        }

        return $null
    }

    # setup basic auth (base64> username:password in header)
    New-PodeAuthScheme -Basic | Add-PodeAuth -Name 'Basic' -Sessionless -ScriptBlock {
        param($username, $password)

        # here you'd check a real user storage, this is just for example
        if ($username -eq 'morty' -and $password -eq 'pickle') {
            return @{
                User = ($using:testBasicUsers).M0R7Y302
            }
        }

        if ($username -eq 'mindy' -and $password -eq 'pickle') {
            return @{
                User = ($using:testBasicUsers).MINDY021
            }
        }

        return @{ Message = 'Invalid details supplied' }
    }

    # merge the auths together
    Merge-PodeAuth -Name 'MergedAuth' -Authentication 'ApiKey', 'Basic' -Valid All -ScriptBlock {
        param($results)

        $apiUser = $results['ApiKey'].User
        $basicUser = $results['Basic'].User

        return @{
            User = @{
                ID     = $apiUser.ID
                Name   = $apiUser.Name
                Type   = $apiUser.Type
                Roles  = @($apiUser.Roles + $basicUser.Roles) | Sort-Object -Unique
                Groups = @($apiUser.Groups + $basicUser.Groups) | Sort-Object -Unique
            }
        }
    }

    Add-PodeRoute -PassThru -Method Put -Path '/auth/asyncUsing' -Authentication 'MergedAuth' -Access 'MergedAccess' -Group 'Software'   -ScriptBlock {
        Write-PodeHost '/auth/asyncUsing'
        Write-PodeHost "sleepTime=$($using:uSleepTime)"
        Write-PodeHost "Message=$($using:uMessage)"
        Start-Sleep $using:uSleepTime
        return @{ InnerValue = $using:uMessage }
    } | Set-PodeAsyncRoute -ResponseContentType 'application/json', 'application/yaml' -Callback -PassThru -CallbackSendResult -Timeout 300 | Set-PodeOARequest  -RequestBody (
        New-PodeOARequestBody -Content @{'application/json' = (New-PodeOAStringProperty -Name 'callbackUrl' -Format Uri -Object -Example 'http://localhost:8080/receive/callback') }
    )


    Add-PodeRoute -PassThru -Method Put -Path '/auth/asyncState' -Authentication 'MergedAuth' -Access 'MergedAccess' -Group 'Software'  -ScriptBlock {
        Write-PodeHost '/auth/asyncState'
        Write-PodeHost "state:sleepTime=$($state:data.sleepTime)"
        Write-PodeHost "state:MessageTest=$($state:data.Message)"
        for ($i = 0; $i -lt 10; $i++) {
            Start-Sleep $state:data.sleepTime
        }
        return @{ InnerValue = $state:data.Message }
    } | Set-PodeAsyncRoute -ResponseContentType 'application/json', 'application/yaml' -Timeout 300



    Add-PodeRoute -PassThru -Method Put -Path '/auth/asyncStateNoColumn'  -Authentication 'MergedAuth' -Access 'MergedAccess' -Group 'Support'   -ScriptBlock {
        Write-PodeHost '/auth/asyncStateNoColumn'
        $data = Get-PodeState -Name 'data'
        Write-PodeHost 'data:'
        Write-PodeHost $data -Explode -ShowType
        for ($i = 0; $i -lt 10; $i++) {
            Start-Sleep $data.sleepTime
        }
        return @{ InnerValue = $data.Message }
    } | Set-PodeAsyncRoute -ResponseContentType 'application/json', 'application/yaml' -Timeout 300




    Add-PodeRoute -PassThru -Method Put -Path '/auth/asyncParam'  -Authentication 'MergedAuth' -Access 'MergedAccess' -Group 'Software' -ScriptBlock {
        param($sleepTime2, $Message)
        Write-PodeHost '/auth/asyncParam'
        Write-PodeHost "sleepTime2=$sleepTime2"
        Write-PodeHost "Message=$Message"

        for ($i = 0; $i -lt 10; $i++) {
            Start-Sleep $sleepTime2
        }
        return @{ InnerValue = $Message }
    } -ArgumentList @{sleepTime2 = 2; Message = 'comming as argument' } | Set-PodeAsyncRoute -ResponseContentType 'application/json', 'application/yaml' -Timeout 300


    Add-PodeRoute -PassThru -Method Put -Path '/auth/asyncUsingNotCancelable' -Authentication 'MergedAuth' -Access 'MergedAccess' -Group 'Software' -ScriptBlock {
        Write-PodeHost '/auth/asyncUsingNotCancelable'
        Write-PodeHost "sleepTime=$($using:uSleepTime * 5)"
        Write-PodeHost "Message=$($using:uMessage)"
        #write-podehost $WebEvent.auth.User -Explode
        Start-Sleep ($using:uSleepTime * 10)
        return @{ InnerValue = $using:uMessage }
    } | Set-PodeAsyncRoute -ResponseContentType 'application/json', 'application/yaml' -NotCancelable -Timeout 300

    Add-PodeRoute -PassThru -Method Put -Path '/auth/asyncUsingCancelable' -Authentication 'MergedAuth' -Access 'MergedAccess' -Group 'Software' -ScriptBlock {
        Write-PodeHost '/auth/asyncUsingCancelable'
        Write-PodeHost "sleepTime=$($using:uSleepTime * 5)"
        Write-PodeHost "Message=$($using:uMessage)"
        #write-podehost $WebEvent.auth.User -Explode
        Start-Sleep ($using:uSleepTime * 10)
        return @{ InnerValue = $using:uMessage }
    } | Set-PodeAsyncRoute -ResponseContentType 'application/json', 'application/yaml'


    Add-PodeRoute -PassThru -Method Put -Path '/auth/asyncWaitForever' -Authentication 'MergedAuth' -Access 'MergedAccess' -Group 'Software'  -ScriptBlock {
        while ($true) {
            Start-Sleep 2
        }
    } | Set-PodeAsyncRoute -ResponseContentType 'application/json', 'application/yaml' -Timeout 300



    Add-PodeRoute -PassThru -Method Put -Path '/auth/asyncWaitForeverTimeout' -Authentication 'MergedAuth' -Access 'MergedAccess' -Group 'Software'  -ScriptBlock {
        while ($true) {
            Start-Sleep 2
        }
    } | Set-PodeAsyncRoute -ResponseContentType 'application/json', 'application/yaml' -Timeout 40 -NotCancelable


    Add-PodeRoute -PassThru -Method Put -Path '/auth/asyncProgressByTimer' -Authentication 'MergedAuth' -Access 'MergedAccess' -Group 'Software'  -ScriptBlock {
        Set-PodeAsyncProgress -DurationSeconds 60 -IntervalSeconds 1
        for ($i = 0 ; $i -lt 60 ; $i++) {
            Start-Sleep 1
        }
    } | Set-PodeAsyncRoute -ResponseContentType 'application/json', 'application/yaml' -Timeout 300




    Add-PodeRoute -PassThru -Method Get -path '/SumOfSquareRoot' -ScriptBlock {
        $start = [int]( Get-PodeHeader -Name 'Start')
        $end = [int]( Get-PodeHeader -Name 'End')
        Write-PodeHost "Start=$start End=$end"
        Set-PodeAsyncProgress -Start $start -End $End -UseDecimalProgress -MaxProgress 80
        [double]$sum = 0.0
        for ($i = $Start; $i -le $End; $i++) {
            $sum += [math]::Sqrt($i )
            Set-PodeAsyncProgress -Tick
            #   Write-PodeHost  (Get-PodeAsyncProgress)
        }
        Write-PodeHost  (Get-PodeAsyncProgress)
        Set-PodeAsyncProgress -Start $start -End $End -Steps 4
        for ($i = $Start; $i -le $End; $i += 4) {
            $sum += [math]::Sqrt($i )
            Set-PodeAsyncProgress -Tick
            #   Write-PodeHost  (Get-PodeAsyncProgress)
        }

        Write-PodeHost  (Get-PodeAsyncProgress)
        Write-PodeHost "Result of Start=$start End=$end is $sum"
        return $sum
    } | Set-PodeAsyncRoute -ResponseContentType 'application/json', 'application/yaml' -MaxRunspaces 10 -MinRunspaces 5 -PassThru | Set-PodeOARouteInfo -Summary 'Caluclate sum of square roots'  -PassThru |
        Set-PodeOARequest -PassThru -Parameters (
      (  New-PodeOANumberProperty -Name 'Start' -Format Double -Description 'Start' -Required | ConvertTo-PodeOAParameter -In Header),
         (   New-PodeOANumberProperty -Name 'End' -Format Double -Description 'End' -Required | ConvertTo-PodeOAParameter -In Header)
        ) | Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -Content  @{ 'application/json' = New-PodeOANumberProperty -Name 'Result' -Format Double -Description 'Result' -Required -Object }


    Add-PodeAsyncGetRoute -Path '/task' -ResponseContentType  'application/json', 'application/yaml'  -In Path -Authentication 'MergedAuth' -Access 'MergedAccess' -Group 'Software' #-TaskIdName 'pippopppoId'
    Add-PodeAsyncStopRoute -Path '/task' -ResponseContentType 'application/json', 'application/yaml' -In Query -Authentication 'MergedAuth' -Access 'MergedAccess' -Group 'Software' #-TaskIdName 'pippopppoId'

    Add-PodeAsyncQueryRoute -path '/tasks'  -ResponseContentType 'application/json', 'application/yaml'   -Payload  Body -QueryContentType 'application/json', 'application/yaml'  -Authentication 'MergedAuth' -Access 'MergedAccess' -Group 'Software'

    Add-PodeRoute -PassThru -Method Post -path '/receive/callback' -ScriptBlock {
        write-podehost 'Callback received'
        write-podehost $WebEvent.Data -Explode
    }

    Add-PodeRoute  -Method 'Post' -Path '/close' -ScriptBlock {
        Close-PodeServer
    } -PassThru | Set-PodeOARouteInfo -Summary 'Shutdown the server'

    Add-PodeRoute  -Method 'Get' -Path '/hello' -ScriptBlock {
        Write-PodeJsonResponse -Value @{'message' = 'Hello!' } -StatusCode 200
    } -PassThru | Set-PodeOARouteInfo -Summary 'Hello from the server'
    <#
    Add-PodeRoute -PassThru -Method Put -Path '/asyncglobal'    -ScriptBlock {

        Write-PodeHost "global:gSleepTime=$($global:gSleepTime)"
        Write-PodeHost "global:gMessage=$($global:gMessage)"
        for ($i = 0; $i -lt 20; $i++) {
            Start-Sleep $global:gSleepTime
        }
        return @{ InnerValue = $global:gMessage }
    } | Set-PodeAsyncRoute -ResponseContentType 'application/json', 'application/yaml'

#>

}