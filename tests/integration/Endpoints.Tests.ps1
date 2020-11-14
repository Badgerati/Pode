Describe 'Endpoint Requests' {

    BeforeAll {
        $Port1 = 50000
        $Endpoint1 = "http://localhost:$($Port1)"

        $Port2 = 50001
        $Endpoint2 = "http://localhost:$($Port2)"

        Start-Job -Name 'Pode' -ErrorAction Stop -ScriptBlock {
            Import-Module -Name "$($using:PSScriptRoot)\..\..\src\Pode.psm1"

            Start-PodeServer -RootPath $using:PSScriptRoot {
                Add-PodeEndpoint -Address localhost -Port $using:Port1 -Protocol Http -Name 'Endpoint1'
                Add-PodeEndpoint -Address localhost -Port $using:Port2 -Protocol Http -Name 'Endpoint2'

                New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging
                Add-PodeRoute -Method Get -Path '/close' -ScriptBlock {
                    Close-PodeServer
                }

                Add-PodeRoute -Method Get -Path '/ping-1' -EndpointName 'Endpoint1' -ScriptBlock {
                    Write-PodeJsonResponse -Value @{ Result = 'Pong1' }
                }

                Add-PodeRoute -Method Get -Path '/ping-2' -EndpointName 'Endpoint2' -ScriptBlock {
                    Write-PodeJsonResponse -Value @{ Result = 'Pong2' }
                }

                Add-PodeRoute -Method Get -Path '/ping-all' -EndpointName 'Endpoint1', 'Endpoint2' -ScriptBlock {
                    Write-PodeJsonResponse -Value @{ Result = 'PongAll' }
                }
            }
        }

        Start-Sleep -Seconds 10
    }

    AfterAll {
        Receive-Job -Name 'Pode' | Out-Default
        Invoke-RestMethod -Uri "$($Endpoint1)/close" -Method Get | Out-Null
        Get-Job -Name 'Pode' | Remove-Job -Force
    }


    It 'responds back with pong1' {
        $result = Invoke-RestMethod -Uri "$($Endpoint1)/ping-1" -Method Get
        $result.Result | Should Be 'Pong1'
    }

    It 'fails pong1 on second endpoint' {
        { Invoke-RestMethod -Uri "$($Endpoint2)/ping-1" -Method Get -ErrorAction Stop } | Should Throw '404'
    }

    It 'responds back with pong2' {
        $result = Invoke-RestMethod -Uri "$($Endpoint2)/ping-2" -Method Get
        $result.Result | Should Be 'Pong2'
    }

    It 'fails pong2 on first endpoint' {
        { Invoke-RestMethod -Uri "$($Endpoint1)/ping-2" -Method Get -ErrorAction Stop } | Should Throw '404'
    }

    It 'responds back with pong all' {
        $result = Invoke-RestMethod -Uri "$($Endpoint1)/ping-all" -Method Get
        $result.Result | Should Be 'PongAll'
        $result = Invoke-RestMethod -Uri "$($Endpoint2)/ping-all" -Method Get
        $result.Result | Should Be 'PongAll'
    }
}