param(
    [Parameter()]
    [int]
    $Port = 8090
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
<#
    # setup session details
    Enable-PodeSessionMiddleware -Duration 120 -Extend

    # setup form auth (<form> in HTML)
    New-PodeAuthScheme -Form | Add-PodeAuth -Name 'Login' -FailureUrl '/login' -SuccessUrl '/' -ScriptBlock {
        param($username, $password)

        # here you'd check a real user storage, this is just for example
        if ($username -eq 'morty' -and $password -eq 'pickle') {
            return @{
                User = @{
                    Name = 'Morty'
                    Roles = @('Developer')
                }
            }
        }

        return @{ Message = 'Invalid details supplied' }
    }

    # set RBAC access
    New-PodeAccessScheme -Type Role | Add-PodeAccess -Name 'Rbac' -Match One


    # home page:
    # redirects to login page if not authenticated
    Add-PodeRoute -Method Get -Path '/' -Authentication Login -ScriptBlock {
        $session:Views++

        Write-PodeViewResponse -Path 'auth-home' -Data @{
            Username = $WebEvent.Auth.User.Name
            Views = $session:Views
            Expiry = Get-PodeSessionExpiry
        }
    }

    Add-PodeRoute -PassThru -Method Put -Path '/auth/asyncUsing'  -Authentication 'Validate' -Group 'TaskManager' -ScriptBlock {
        Write-PodeHost "sleepTime=$($using:uSleepTime)"
        Write-PodeHost "Message=$($using:uMessage)"
        Start-Sleep ($using:uSleepTime *2)
        return @{ InnerValue = $using:uMessage }
    } | Set-PodeRouteAsync -ResponseContentType JSON, YAML
#>

Add-PodeRoute -PassThru -Method Put -Path '/asyncUsing'    -ScriptBlock {

        Write-PodeHost "sleepTime=$($using:uSleepTime)"
        Write-PodeHost "Message=$($using:uMessage)"
        Start-Sleep $using:uSleepTime
        return @{ InnerValue = $using:uMessage }
    } | Set-PodeRouteAsync -ResponseContentType JSON, YAML
    Add-PodeRoute -PassThru -Method Put -Path '/asyncState'  -ScriptBlock {

        Write-PodeHost "state:sleepTime=$($state:data.sleepTime)"
        Write-PodeHost "state:MessageTest=$($state:data.Message)"
        for ($i = 0; $i -lt 20; $i++) {
            Start-Sleep $state:data.sleepTime
        }
        return @{ InnerValue = $state:data.Message }
    } | Set-PodeRouteAsync -ResponseContentType JSON, YAML -Threads 5



    Add-PodeRoute -PassThru -Method Put -Path '/asyncStateNoColumn'    -ScriptBlock {
        $data = Get-PodeState -Name 'data'
        Write-PodeHost 'data:'
        Write-PodeHost $data -Explode -ShowType
        for ($i = 0; $i -lt 20; $i++) {
            Start-Sleep $data.sleepTime
        }
        return @{ InnerValue = $data.Message }
    } | Set-PodeRouteAsync -ResponseContentType JSON, YAML




    Add-PodeRoute -PassThru -Method Put -Path '/asyncParam'   -ScriptBlock {
        param($sleepTime2, $Message)
        Write-PodeHost "sleepTime2=$sleepTime2"
        Write-PodeHost "Message=$Message"
        for ($i = 0; $i -lt 20; $i++) {
            Start-Sleep $sleepTime2
        }
        return @{ InnerValue = $Message }
    } -ArgumentList @{sleepTime2 = 2; Message = 'comming as argument' } | Set-PodeRouteAsync -ResponseContentType JSON, YAML



    Add-PodeGetTaskRoute -Path '/task' -ResponseContentType JSON, YAML -In Path #-TaskIdName 'pippopppoId'
    Add-PodeStopTaskRoute -Path '/task' -ResponseContentType JSON, YAML -In Query #-TaskIdName 'pippopppoId'

    Add-PodeQueryTaskRoute -path '/tasks'  -ResponseContentType JSON , YAML   -Payload Body #-Style Form

    <#
    Add-PodeRoute -PassThru -Method Put -Path '/asyncglobal'    -ScriptBlock {

        Write-PodeHost "global:gSleepTime=$($global:gSleepTime)"
        Write-PodeHost "global:gMessage=$($global:gMessage)"
        for ($i = 0; $i -lt 20; $i++) {
            Start-Sleep $global:gSleepTime
        }
        return @{ InnerValue = $global:gMessage }
    } | Set-PodeRouteAsync -ResponseContentType JSON, YAML

#>

}