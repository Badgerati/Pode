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

    # setup apikey auth
    New-PodeAuthScheme -ApiKey -Location Header | Add-PodeAuth -Name 'ApiKey' -Sessionless -ScriptBlock {
        param($key)

        # here you'd check a real user storage, this is just for example
        if ($key -ieq 'test-api-key') {
            return @{
                User = @{
                    ID     = 'M0R7Y302'
                    Name   = 'Morty'
                    Type   = 'Human'
                    Roles  = @('Developer')
                    Groups = @('Platform')
                }
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
                User = @{
                    Username = 'morty'
                    ID       = 'M0R7Y302'
                    Name     = 'Morty'
                    Type     = 'Human'
                    Roles    = @('Developer')
                    Groups   = @('Software')
                }
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
                Username = $basicUser.Username
                ID       = $apiUser.ID
                Name     = $apiUser.Name
                Type     = $apiUser.Type
                Roles    = @($apiUser.Roles + $basicUser.Roles) | Sort-Object -Unique
                Groups   = @($apiUser.Groups + $basicUser.Groups) | Sort-Object -Unique
            }
        }
    }

    Add-PodeRoute -PassThru -Method Put -Path '/auth/asyncUsing'  -Authentication 'MergedAuth' -Access 'MergedAccess' -Group 'Software' -ScriptBlock {
        Write-PodeHost "sleepTime=$($using:uSleepTime)"
        Write-PodeHost "Message=$($using:uMessage)"
        write-podehost $WebEvent.auth.User -Explode
        Start-Sleep ($using:uSleepTime *2)
        return @{ InnerValue = $using:uMessage }
    } | Set-PodeAsyncRoute -ResponseContentType JSON, YAML


    Add-PodeRoute -PassThru -Method Put -Path '/asyncUsing'    -ScriptBlock {
        Write-PodeHost "sleepTime=$($using:uSleepTime)"
        Write-PodeHost "Message=$($using:uMessage)"
        Start-Sleep $using:uSleepTime
        return @{ InnerValue = $using:uMessage }
    } | Set-PodeAsyncRoute -ResponseContentType JSON, YAML -Callback -PassThru -CallbackSendResult | Set-PodeOARequest  -RequestBody (
        New-PodeOARequestBody -Content @{'application/json' = (New-PodeOAStringProperty -Name 'callbackUrl' -Format Uri -Object -Example 'http://localhost:8080/receive/callback') }
    )


    Add-PodeRoute -PassThru -Method Put -Path '/asyncState'  -ScriptBlock {

        Write-PodeHost "state:sleepTime=$($state:data.sleepTime)"
        Write-PodeHost "state:MessageTest=$($state:data.Message)"
        for ($i = 0; $i -lt 20; $i++) {
            Start-Sleep $state:data.sleepTime
        }
        return @{ InnerValue = $state:data.Message }
    } | Set-PodeAsyncRoute -ResponseContentType JSON, YAML -MaxThreads 5



    Add-PodeRoute -PassThru -Method Put -Path '/asyncStateNoColumn'    -ScriptBlock {
        $data = Get-PodeState -Name 'data'
        Write-PodeHost 'data:'
        Write-PodeHost $data -Explode -ShowType
        for ($i = 0; $i -lt 20; $i++) {
            Start-Sleep $data.sleepTime
        }
        return @{ InnerValue = $data.Message }
    } | Set-PodeAsyncRoute -ResponseContentType JSON, YAML




    Add-PodeRoute -PassThru -Method Put -Path '/asyncParam'   -ScriptBlock {
        param($sleepTime2, $Message)
        Write-PodeHost "sleepTime2=$sleepTime2"
        Write-PodeHost "Message=$Message"
        for ($i = 0; $i -lt 20; $i++) {
            Start-Sleep $sleepTime2
        }
        return @{ InnerValue = $Message }
    } -ArgumentList @{sleepTime2 = 2; Message = 'comming as argument' } | Set-PodeAsyncRoute -ResponseContentType JSON, YAML



    Add-PodeAsyncGetRoute -Path '/task' -ResponseContentType JSON, YAML -In Path #-TaskIdName 'pippopppoId'
    Add-PodeAsyncStopRoute -Path '/task' -ResponseContentType JSON, YAML -In Query #-TaskIdName 'pippopppoId'

    Add-PodeAsyncQueryRoute -path '/tasks'  -ResponseContentType JSON , YAML   -Payload  Body -QueryContentType JSON, YAML

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
    } | Set-PodeAsyncRoute -ResponseContentType JSON, YAML

#>

}