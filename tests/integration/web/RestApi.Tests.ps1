Describe 'Simple REST API' {

    BeforeAll {
        $Port = 9000
        $Endpoint = "http://localhost:$($Port)"

        Start-Job -Name 'Pode' -ErrorAction Stop -ScriptBlock {
            Import-Module -Name "$($using:PSScriptRoot)\..\..\..\src\Pode.psm1"

            Start-PodeServer {
                Add-PodeEndpoint -Address localhost -Port $using:Port -Protocol Http

                Add-PodeRoute -Method Get -Path '/ping' -ScriptBlock {
                    Write-PodeJsonResponse -Value @{ Result = 'Pong' }
                }

                Add-PodeRoute -Method Get -Path '/query' -ScriptBlock {
                    param($e)
                    Write-PodeJsonResponse -Value @{ Username = $e.Query['username'] }
                }

                Add-PodeRoute -Method Get -Path '/close' -ScriptBlock {
                    Close-PodeServer
                }
            }
        }

        Start-Sleep -Seconds 3
    }

    It 'responds back with pong' {
        $result = Invoke-RestMethod -Uri "$($Endpoint)/ping" -Method Get
        $result.Result | Should Be 'Pong'
    }

    It 'responds with simple query parameter' {
        $result = Invoke-RestMethod -Uri "$($Endpoint)/query?username=rick" -Method Get
        $result.Username | Should Be 'rick'
    }

    AfterAll {
        Invoke-RestMethod -Uri "$($Endpoint)/close" -Method Get | Out-Null
        Get-Job -Name 'Pode' | Remove-Job -Force
    }
}