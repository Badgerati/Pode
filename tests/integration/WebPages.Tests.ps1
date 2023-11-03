Describe 'Web Page Requests' {

    BeforeAll {
        $Port = 50000
        $Endpoint = "http://localhost:$($Port)"

        Start-Job -Name 'Pode' -ErrorAction Stop -ScriptBlock {
            Import-Module -Name "$($using:PSScriptRoot)\..\..\src\Pode.psm1"

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

                Add-PodeRoute -Method Get -Path '/redirect' -ScriptBlock {
                    Move-PodeResponseUrl -Url 'https://google.com'
                }

                Add-PodeRoute -Method Get -Path '/attachment' -ScriptBlock {
                    Set-PodeResponseAttachment -Path 'ruler.png'
                }

                Add-PodeStaticRoute -Path '/custom-images' -Source './images'
            }
        }

        Start-Sleep -Seconds 10
    }

    AfterAll {
        Invoke-RestMethod -Uri "$($Endpoint)/close" -Method Get | Out-Null
        Get-Job -Name 'Pode' | Remove-Job -Force
    }


    It 'responds with a dynamic view' {
        $result = Invoke-WebRequest -Uri "$($Endpoint)/views/dynamic" -Method Get
        $result.Content | Should -Be '<p>2020-03-14</p>'
    }

    It 'responds with a static view' {
        $result = Invoke-WebRequest -Uri "$($Endpoint)/views/static" -Method Get
        $result.Content | Should -Be '<p>2020-01-01</p>'
    }

    It 'redirects you to another url' {
        $result = Invoke-WebRequest -Uri "$($Endpoint)/redirect" -Method Get
        $result.StatusCode | Should -Be 200
        $result.Content.Contains('google') | Should -Be $true
    }

    It 'attaches and image for download' {
        $result = Invoke-WebRequest -Uri "$($Endpoint)/attachment" -Method Get
        $result.StatusCode | Should -Be 200
        $result.Headers['Content-Type'] | Should -Be 'image/png'
        $result.Headers['Content-Disposition'] | Should -Be 'attachment; filename=ruler.png'
    }

    It 'responds with public static content' {
        $result = Invoke-WebRequest -Uri "$($Endpoint)/ruler.png" -Method Get
        $result.StatusCode | Should -Be 200
        $result.Headers['Content-Type'] | Should -Be 'image/png; charset=utf-8'
    }

    It 'responds with 404 for non-public static content' {
        { Invoke-WebRequest -Uri "$($Endpoint)/images/custom_ruler.png" -Method Get -ErrorAction Stop } | Should -Throw -ExpectedMessage '*404*'
    }

    It 'responds with custom static content' {
        $result = Invoke-WebRequest -Uri "$($Endpoint)/custom-images/custom_ruler.png" -Method Get
        $result.StatusCode | Should -Be 200
        $result.Headers['Content-Type'] | Should -Be 'image/png; charset=utf-8'
    }
}