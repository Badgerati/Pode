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

                New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging
                Add-PodeRoute -Method Get -Path '/close' -ScriptBlock {
                    Close-PodeServer
                }

                # schedule minutely using predefined cron

                Set-PodeState -Name 'test3' -Value @{eventList = @() }

                Add-PodeSchedule -Name 'TestEvents' -Cron '* * * * *' -Limit 2 -ScriptBlock {
                    param($Event, $Message1, $Message2)
                    Lock-PodeObject -ScriptBlock {
                        $test3 = (Get-PodeState -Name 'test3')
                        $test3.eventList += @{
                            message    = 'Hello, world!'
                            'Last'     = $Event.Sender.LastTriggerTime
                            'Next'     = $Event.Sender.NextTriggerTime
                            'Message1' = $Message1
                            'Message2' = $Message2
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


                # adhoc invoke a schedule's logic
                Add-PodeRoute -Method Post -Path '/eventlist/run' -ScriptBlock {
                    Invoke-PodeSchedule -Name 'TestEvents' -ArgumentList @{
                        Message1 = 'Hello!'
                        Message2 = 'Bye!'
                    }
                    Write-PodeJsonResponse -Value ( @{Result = 'ok' }  )
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

    It 'Invoke schedule events' {
        $result = Invoke-RestMethod -Uri "$($Endpoint)/eventlist/run" -Method post
        $result.Result | Should -Be 'OK'
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
        if ( $result.eventList[0].Message1 -eq 'Hello!' ) { $index = 0 } else { $index = 1 }
        $result.eventList[$index].Message1 | Should -Be 'Hello!'
        $result.eventList[$index].Message2 | Should -Be 'Bye!'
        $result.eventList[$index].Message | Should -Be 'Hello, world!'
        $result.eventList[$index].Last | Should -BeNullOrEmpty
        $result.eventList[$index].next | Should -not -BeNullOrEmpty
        if ($index -eq 0) { $index = 1 }else { $index = 0 }
        $result.eventList[$index].Message1 | Should -BeNullOrEmpty
        $result.eventList[$index].Message2 | Should -BeNullOrEmpty
        $result.eventList[$index].Message | Should -Be 'Hello, world!'
        $result.eventList[$index].Last | Should -not -BeNullOrEmpty
        $result.eventList[$index].next | Should -not -BeNullOrEmpty
    }

}