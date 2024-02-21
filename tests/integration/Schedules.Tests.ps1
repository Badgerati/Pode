[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
param()

Describe 'Schedules' {

    BeforeAll {
        $Port = 50000
        $Endpoint = "http://localhost:$($Port)"

        Start-Job -Name 'Pode' -ErrorAction Stop -ScriptBlock {
            Import-Module -Name "$($using:PSScriptRoot)\..\..\src\Pode.psm1"

            Start-PodeServer -RootPath $using:PSScriptRoot -Quiet -ScriptBlock {
                Add-PodeEndpoint -Address localhost -Port $using:Port -Protocol Http

                New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging
                Add-PodeRoute -Method Get -Path '/close' -ScriptBlock {
                    Close-PodeServer
                }

                # test1
                Set-PodeState -Name 'Test1' -Value 0
                Add-PodeSchedule -Name 'Test1' -Cron '* * * * *' -ScriptBlock {
                    Set-PodeState -Name 'Test1' -Value 1337
                }

                Add-PodeRoute -Method Get -Path '/test1' -ScriptBlock {
                    Invoke-PodeSchedule -Name 'Test1'
                    Start-Sleep -Seconds 2
                    Write-PodeJsonResponse -Value @{ Result = (Get-PodeState -Name 'Test1') }
                }

                # test2
                Set-PodeState -Name 'Test2' -Value 0
                Add-PodeSchedule -Name 'Test2' -Cron '@minutely' -ScriptBlock {
                    Set-PodeState -Name 'Test2' -Value 314
                }

                Add-PodeRoute -Method Get -Path '/test2' -ScriptBlock {
                    Invoke-PodeSchedule -Name 'Test2'
                    Start-Sleep -Seconds 2
                    Write-PodeJsonResponse -Value @{ Result = (Get-PodeState -Name 'Test2') }
                }
            }
        }

        Start-Sleep -Seconds 10
    }

    AfterAll {
        Receive-Job -Name 'Pode' | Out-Default
        Invoke-RestMethod -Uri "$($Endpoint)/close" -Method Get | Out-Null
        Get-Job -Name 'Pode' | Remove-Job -Force
    }


    It 'schedule updates state value - full cron' {
        $result = Invoke-RestMethod -Uri "$($Endpoint)/test1" -Method Get
        $result.Result | Should -Be 1337
    }

    It 'schedule updates state value - short cron' {
        $result = Invoke-RestMethod -Uri "$($Endpoint)/test2" -Method Get
        $result.Result | Should -Be 314
    }
}