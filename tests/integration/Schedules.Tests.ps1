[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseUsingScopeModifierInNewRunspaces', '', Justification = 'Using ArgumentList')]
param()

Describe 'Schedules' {

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

                # schedule minutely using predefined cron

                Set-PodeState -Name 'test3' -Value @{eventList = @() }

                Add-PodeSchedule -Name 'TestEvents' -Cron '* * * * *' -Limit 2 -OnStart -ScriptBlock {
                    param($Event )
                    Lock-PodeObject -ScriptBlock {
                        $test3 = (Get-PodeState -Name 'test3')
                        $test3.eventList += @{
                            message = 'Hello, world!'
                            'Last'  = $Event.Sender.LastTriggerTime
                            'Next'  = $Event.Sender.NextTriggerTime
                        }
                    }
                }


                Add-PodeRoute -Method Get -Path '/eventlist' -ScriptBlock {
                    Lock-PodeObject -ScriptBlock {
                        $test3 = (Get-PodeState -Name 'test3')
                        if ($test3.eventList.Count -gt 1) {
                            Write-PodeJsonResponse -Value  @{ ready = $true ; count = $test3.eventList.Count; eventList = $test3.eventList }
                        }
                        else {
                            Write-PodeJsonResponse -Value  @{ ready = $false ; count = $test3.eventList.Count; }
                        }
                    }
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

    It 'Schedule updates state value - full cron' {
        $result = Invoke-RestMethod -Uri "$($Endpoint)/test1" -Method Get
        $result.Result | Should -Be 1337
    }

    It 'Schedule updates state value - short cron' {
        $result = Invoke-RestMethod -Uri "$($Endpoint)/test2" -Method Get
        $result.Result | Should -Be 314
    }

    It 'Check schedule events result' {

        for ($i = 0; $i -lt 20; $i++) {
            $result = Invoke-RestMethod -Uri "$($Endpoint)/eventlist" -Method Get
            if ($result.ready) {
                break
            }
            Start-Sleep -Seconds 10
        }
        $result.ready | Should -BeTrue
        $result.Count | Should -Be 2
        $result.eventList.GetType() | Should -Be 'System.Object[]'
        $result.eventList.Count | Should -Be 2


        if ( $null -eq $result.eventList[0].Next  ) { $index = 0 } else { $index = 1 }
        $result.eventList[$index].Message | Should -Be 'Hello, world!'
        $result.eventList[$index].Last | Should -not -BeNullOrEmpty
        $result.eventList[$index].next | Should -BeNullOrEmpty
        if ($index -eq 0) { $index = 1 }else { $index = 0 }
        $result.eventList[$index].Message | Should -Be 'Hello, world!'
        $result.eventList[$index].Last | Should -not -BeNullOrEmpty
        $result.eventList[$index].next | Should -not -BeNullOrEmpty
    }

}