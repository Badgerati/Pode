Describe 'Web Page Requests' {

    BeforeAll {
        $Port = 9000
        $Endpoint = "http://localhost:$($Port)"

        Start-Job -Name 'Pode' -ErrorAction Stop -ScriptBlock {
            Import-Module -Name "$($using:PSScriptRoot)\..\..\..\src\Pode.psm1"

            Start-PodeServer -RootPath $using:PSScriptRoot {
                Add-PodeEndpoint -Address localhost -Port $using:Port -Protocol Http
                Add-PodeRoute -Method Get -Path '/close' -ScriptBlock {
                    Close-PodeServer
                }

                Set-PodeViewEngine -Type Pode

                Add-PodeRoute -Method Get -Path '/views/dynamic' -ScriptBlock {
                    Write-PodeViewResponse -Path 'dynamic' -Data @{ Date = '2020-03-14' }
                }

                Add-PodeRoute -Method Get -Path '/views/static' -ScriptBlock {
                    Write-PodeViewResponse -Path 'static.html'
                }
            }
        }

        Start-Sleep -Seconds 3
    }

    AfterAll {
        Invoke-RestMethod -Uri "$($Endpoint)/close" -Method Get | Out-Null
        Get-Job -Name 'Pode' | Remove-Job -Force
    }


    It 'responds with a dynamic view' {
        $result = Invoke-WebRequest -Uri "$($Endpoint)/views/dynamic" -Method Get
        $result.Content | Should Be '<p>2020-03-14</p>'
    }

    It 'responds with a static view' {
        $result = Invoke-WebRequest -Uri "$($Endpoint)/views/static" -Method Get
        $result.Content | Should Be '<p>2020-01-01</p>'
    }
}