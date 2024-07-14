param(
    [Parameter()]
    [int]
    $Port = 8080
)

$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

# or just:
# Import-Module Pode

<#
# Demostrates Lockables, Mutexes, and Semaphores
#>

Start-PodeServer -Threads 1 {

    Add-PodeEndpoint -Address localhost -Port $Port -Protocol Http
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging

    # request logging
    New-PodeLoggingMethod -Terminal -Batch 10 -BatchTimeout 10 | Enable-PodeRequestLogging

    Enable-PodeOpenApi -Path '/docs/openapi' -OpenApiVersion '3.0.3'  -DisableMinimalDefinitions -NoDefaultResponses

    Add-PodeOAInfo -Title 'Async test - OpenAPI 3.0' -Version 0.0.1

    Enable-PodeOAViewer -Type Swagger -Path '/docs/swagger'

    Enable-PodeOAViewer -Editor -Path '/docs/swagger-editor'
    Enable-PodeOAViewer -Bookmarks -Path '/docs'
    $uSleepTime = 5
    $uMessage = 'coming from using'

    $global:gMessage = 'coming from global'
    $global:gSleepTime = 3
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
    } | Set-PodeAsyncRoute -ResponseContentType 'application/json', 'application/yaml' -Callback -PassThru -CallbackSendResult | Set-PodeOARequest  -RequestBody (
        New-PodeOARequestBody -Content @{'application/json' = (New-PodeOAStringProperty -Name 'callbackUrl' -Format Uri -Object -Example 'http://localhost:8080/receive/callback') }
    )


    Add-PodeRoute -PassThru -Method Put -Path '/auth/asyncState' -Authentication 'MergedAuth' -Access 'MergedAccess' -Group 'Software'  -ScriptBlock {
        Write-PodeHost '/auth/asyncState'
        Write-PodeHost "state:sleepTime=$($state:data.sleepTime)"
        Write-PodeHost "state:MessageTest=$($state:data.Message)"
        for ($i = 0; $i -lt 20; $i++) {
            Start-Sleep $state:data.sleepTime
        }
        return @{ InnerValue = $state:data.Message }
    } | Set-PodeAsyncRoute -ResponseContentType 'application/json', 'application/yaml' -MaxThreads 5



    Add-PodeRoute -PassThru -Method Put -Path '/auth/asyncStateNoColumn'  -Authentication 'MergedAuth' -Access 'MergedAccess' -Group 'Support'   -ScriptBlock {
        Write-PodeHost '/auth/asyncStateNoColumn'
        $data = Get-PodeState -Name 'data'
        Write-PodeHost 'data:'
        Write-PodeHost $data -Explode -ShowType
        for ($i = 0; $i -lt 20; $i++) {
            Start-Sleep $data.sleepTime
        }
        return @{ InnerValue = $data.Message }
    } | Set-PodeAsyncRoute -ResponseContentType 'application/json', 'application/yaml'




    Add-PodeRoute -PassThru -Method Put -Path '/auth/asyncParam'  -Authentication 'MergedAuth' -Access 'MergedAccess' -Group 'Software' -ScriptBlock {
        param($sleepTime2, $Message)
        Write-PodeHost '/auth/asyncParam'
        Write-PodeHost "sleepTime2=$sleepTime2"
        Write-PodeHost "Message=$Message"

        for ($i = 0; $i -lt 20; $i++) {
            Start-Sleep $sleepTime2
        }
        return @{ InnerValue = $Message }
    } -ArgumentList @{sleepTime2 = 2; Message = 'comming as argument' } | Set-PodeAsyncRoute -ResponseContentType 'application/json', 'application/yaml'


    Add-PodeRoute -PassThru -Method Put -Path '/auth/asyncUsingNotCancelable' -Authentication 'MergedAuth' -Access 'MergedAccess' -Group 'Software' -ScriptBlock {
        Write-PodeHost '/auth/asyncUsingNotCancelable'
        Write-PodeHost "sleepTime=$($using:uSleepTime * 200)"
        Write-PodeHost "Message=$($using:uMessage)"
        #write-podehost $WebEvent.auth.User -Explode
        Start-Sleep ($using:uSleepTime * 200)
        return @{ InnerValue = $using:uMessage }
    } | Set-PodeAsyncRoute -ResponseContentType 'application/json', 'application/yaml' -NotCancelable

    Add-PodeRoute -PassThru -Method Put -Path '/auth/asyncUsingNCancelable' -Authentication 'MergedAuth' -Access 'MergedAccess' -Group 'Software' -ScriptBlock {
        Write-PodeHost '/auth/asyncUsingNCancelable'
        Write-PodeHost "sleepTime=$($using:uSleepTime * 200)"
        Write-PodeHost "Message=$($using:uMessage)"
        #write-podehost $WebEvent.auth.User -Explode
        Start-Sleep ($using:uSleepTime * 200)
        return @{ InnerValue = $using:uMessage }
    } | Set-PodeAsyncRoute -ResponseContentType 'application/json', 'application/yaml'


    Add-PodeAsyncGetRoute -Path '/task' -ResponseContentType  'application/json', 'application/yaml'  -In Path -Authentication 'MergedAuth' -Access 'MergedAccess' -Group 'Software' #-TaskIdName 'pippopppoId'
    Add-PodeAsyncStopRoute -Path '/task' -ResponseContentType 'application/json', 'application/yaml' -In Query -Authentication 'MergedAuth' -Access 'MergedAccess' -Group 'Software' #-TaskIdName 'pippopppoId'

    Add-PodeAsyncQueryRoute -path '/tasks'  -ResponseContentType 'application/json', 'application/yaml'   -Payload  Body -QueryContentType 'application/json', 'application/yaml'  -Authentication 'MergedAuth' -Access 'MergedAccess' -Group 'Software'

    Add-PodeRoute -PassThru -Method Post -path '/receive/callback' -ScriptBlock {
        write-podehost 'Callback received'
        write-podehost $WebEvent.Data -Explode
    }

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