[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
param()

Describe 'Timers' {

    BeforeAll {
        $Port = 8080
        $Endpoint = "http://127.0.0.1:$($Port)"

        Start-Job -Name 'Pode' -ErrorAction Stop -ScriptBlock {
            Import-Module -Name "$($using:PSScriptRoot)\..\..\src\Pode.psm1"

            Start-PodeServer -RootPath $using:PSScriptRoot -Quiet -ScriptBlock {
                Add-PodeEndpoint -Address localhost -Port $using:Port -Protocol Http

                New-PodeLogTerminalMethod | Enable-PodeErrorLogType
                Add-PodeRoute -Method Get -Path '/close' -ScriptBlock {
                    Close-PodeServer
                }

                Add-PodeRoute -Method Get -Path '/ping' -ScriptBlock {
                    Write-PodeJsonResponse -Value @{ Result = 'Pong' }
                }

                Set-PodeState -Name 'Test1' -Value 0
                Add-PodeTimer -Name 'Test1' -Interval 1 -ScriptBlock {
                    Set-PodeState -Name 'Test1' -Value 1337
                }

                Add-PodeRoute -Method Get -Path '/test1' -ScriptBlock {
                    Invoke-PodeTimer -Name 'Test1'
                    Write-PodeJsonResponse -Value @{ Result = (Get-PodeState -Name 'Test1') }
                }
            }
        }

        # wait for ping to be available
        Start-Sleep -Seconds 5

        $count = 0
        while ($true) {
            try {
                $count++
                $ping = Invoke-RestMethod -Uri "$($Endpoint)/ping" -Method Get -TimeoutSec 1 -ErrorAction Stop
                if ($ping.Result -ieq 'Pong') {
                    break
                }
            }
            catch {
                Start-Sleep -Seconds 1
                if ($count -ge 10) {
                    throw "Ping to $($Endpoint)/ping did not respond with 'Pong' within the expected time."
                }
            }
        }
    }

    AfterAll {
        Receive-Job -Name 'Pode' | Out-Default
        Invoke-RestMethod -Uri "$($Endpoint)/close" -Method Get | Out-Null
        Get-Job -Name 'Pode' | Remove-Job -Force
    }


    It 'timer updates state value' {
        $result = Invoke-RestMethod -Uri "$($Endpoint)/test1" -Method Get
        $result.Result | Should -Be 1337
    }
}