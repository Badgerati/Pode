[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseUsingScopeModifierInNewRunspaces', '')]
param()


Describe 'ASYNC REST API Requests' {

    BeforeAll {
        $mindyCommonHeaders = @{
            'accept'        = 'application/json'
            'X-API-KEY'     = 'test2-api-key'
            'Authorization' = 'Basic bWluZHk6cGlja2xl'
        }

        $mortyCommonHeaders = @{
            'accept'        = 'application/json'
            'X-API-KEY'     = 'test-api-key'
            'Authorization' = 'Basic bW9ydHk6cGlja2xl'
        }
        $Port = 8080
        $Endpoint = "http://127.0.0.1:$($Port)"
        $scriptPath = "$($PSScriptRoot)\..\..\examples\Async.ps1"
        if ($PSVersionTable.PsVersion -gt [version]'6.0') {
            Start-Process 'pwsh' -ArgumentList "-NoProfile -File `"$scriptPath`" -Quiet -Port $Port -DisableTermination"  -NoNewWindow
        }
        else {
            Start-Process 'powershell' -ArgumentList "-NoProfile -File `"$scriptPath`" -Quiet -Port $Port -DisableTermination"  -NoNewWindow
        }
        Start-Sleep -Seconds 20
    }

    AfterAll {
        Invoke-RestMethod -Uri "$($Endpoint)/close" -Method Post | Out-Null

    }
    Describe 'Create Async operation on behalf of Mindy' {
        It 'Create Async operation /auth/asyncUsingNotCancelable' {
            $response = Invoke-RestMethod -Uri 'http://localhost:8080/auth/asyncUsingNotCancelable' -Method Put -Headers $mindyCommonHeaders

            # Assertions to validate the response
            $response | Should -Not -BeNullOrEmpty
            $response.User | Should -Be 'MINDY021'
            $response.Name | Should -Be '__Put_auth_asyncUsingNotCancelable__'
            $response.State | Should -BeIn @('NotStarted', 'Running')
            $response.Cancelable | Should -Be $false
        }

        It 'Create Async operation /auth/asyncUsingCancelable' {
            $response = Invoke-RestMethod -Uri 'http://localhost:8080/auth/asyncUsingCancelable' -Method Put -Headers $mindyCommonHeaders

            # Assertions to validate the response
            $response | Should -Not -BeNullOrEmpty
            $response.User | Should -Be 'MINDY021'
            $response.Name | Should -Be '__Put_auth_asyncUsingCancelable__'
            $response.State | Should -BeIn @('NotStarted', 'Running')
            $response.Cancelable | Should -Be $true
        }

        It 'Create Async operation /auth/asyncUsing with JSON body' {
            $body = @{
                callbackUrl = 'http://localhost:8080/receive/callback'
            } | ConvertTo-Json

            $headersWithContentType = $mindyCommonHeaders.Clone()
            $headersWithContentType['Content-Type'] = 'application/json'

            $response = Invoke-RestMethod -Uri 'http://localhost:8080/auth/asyncUsing' -Method Put -Headers $headersWithContentType -Body $body

            # Assertions to validate the response
            $response | Should -Not -BeNullOrEmpty
            $response.User | Should -Be 'MINDY021'
            $response.Name | Should -Be '__Put_auth_asyncUsing__'
            $response.State | Should -BeIn @('NotStarted', 'Running')
            $response.Cancelable | Should -Be $true
        }

        It 'Create Async operation /auth/asyncStateNoColumn' {
            $response = Invoke-RestMethod -Uri 'http://localhost:8080/auth/asyncStateNoColumn' -Method Put -Headers $mindyCommonHeaders

            # Assertions to validate the response
            $response | Should -Not -BeNullOrEmpty
            $response.User | Should -Be 'MINDY021'
            $response.Name | Should -Be '__Put_auth_asyncStateNoColumn__'
            $response.State | Should -BeIn @('NotStarted', 'Running')
            $response.Cancelable | Should -Be $true
        }

        It 'Create Async operation /auth/asyncState' {
            $response = Invoke-RestMethod -Uri 'http://localhost:8080/auth/asyncState' -Method Put -Headers $mindyCommonHeaders

            # Assertions to validate the response
            $response | Should -Not -BeNullOrEmpty
            $response.User | Should -Be 'MINDY021'
            $response.Name | Should -Be '__Put_auth_asyncState__'
            $response.State | Should -BeIn @('NotStarted', 'Running')
            $response.Cancelable | Should -Be $true
        }

        It 'Create Async operation /auth/asyncParam' {
            $response = Invoke-RestMethod -Uri 'http://localhost:8080/auth/asyncParam' -Method Put -Headers $mindyCommonHeaders

            # Assertions to validate the response
            $response | Should -Not -BeNullOrEmpty
            $response.User | Should -Be 'MINDY021'
            $response.Name | Should -Be '__Put_auth_asyncParam__'
            $response.State | Should -BeIn @('NotStarted', 'Running')
            $response.Cancelable | Should -Be $true
        }
    }

    Describe 'Create Async operation on behalf of Morty' {
        It 'Create Async operation /auth/asyncUsingNotCancelable' {
            $response = Invoke-RestMethod -Uri 'http://localhost:8080/auth/asyncUsingNotCancelable' -Method Put -Headers $mortyCommonHeaders

            # Assertions to validate the response
            $response | Should -Not -BeNullOrEmpty
            $response.User | Should -Be 'M0R7Y302'
            $response.Name | Should -Be '__Put_auth_asyncUsingNotCancelable__'
            $response.State | Should -BeIn @('NotStarted', 'Running')
            $response.Cancelable | Should -Be $false
        }

        It 'Create Async operation /auth/asyncUsingCancelable' {
            $response = Invoke-RestMethod -Uri 'http://localhost:8080/auth/asyncUsingCancelable' -Method Put -Headers $mortyCommonHeaders

            # Assertions to validate the response
            $response | Should -Not -BeNullOrEmpty
            $response.User | Should -Be 'M0R7Y302'
            $response.Name | Should -Be '__Put_auth_asyncUsingCancelable__'
            $response.State | Should -BeIn @('NotStarted', 'Running')
            $response.Cancelable | Should -Be $true
        }

        It 'Create Async operation /auth/asyncUsing with JSON body' {
            $body = @{
                callbackUrl = 'http://localhost:8080/receive/callback'
            } | ConvertTo-Json

            $headersWithContentType = $mortyCommonHeaders.Clone()
            $headersWithContentType['Content-Type'] = 'application/json'

            $response = Invoke-RestMethod -Uri 'http://localhost:8080/auth/asyncUsing' -Method Put -Headers $headersWithContentType -Body $body

            # Assertions to validate the response
            $response | Should -Not -BeNullOrEmpty
            $response.User | Should -Be 'M0R7Y302'
            $response.Name | Should -Be '__Put_auth_asyncUsing__'
            $response.State | Should -BeIn @('NotStarted', 'Running')
            $response.Cancelable | Should -Be $true
        }

        It 'Throws exception - Create Async operation /auth/asyncStateNoColumn' {
            { Invoke-RestMethod -Uri 'http://localhost:8080/auth/asyncStateNoColumn' -Method Put -Headers $mortyCommonHeaders } | Should -Throw
        }

        It 'Create Async operation /auth/asyncState' {
            $response = Invoke-RestMethod -Uri 'http://localhost:8080/auth/asyncState' -Method Put -Headers $mortyCommonHeaders

            # Assertions to validate the response
            $response | Should -Not -BeNullOrEmpty
            $response.User | Should -Be 'M0R7Y302'
            $response.Name | Should -Be '__Put_auth_asyncState__'
            $response.State | Should -BeIn @('NotStarted', 'Running')
            $response.Cancelable | Should -Be $true
        }

        It 'Create Async operation /auth/asyncParam' {
            $response = Invoke-RestMethod -Uri 'http://localhost:8080/auth/asyncParam' -Method Put -Headers $mortyCommonHeaders

            # Assertions to validate the response
            $response | Should -Not -BeNullOrEmpty
            $response.User | Should -Be 'M0R7Y302'
            $response.Name | Should -Be '__Put_auth_asyncParam__'
            $response.State | Should -BeIn @('NotStarted', 'Running')
            $response.Cancelable | Should -Be $true
        }
    }

    Describe -Name 'Get Async Operation' {
        BeforeAll {
            $responseCreateAsync = Invoke-RestMethod -Uri 'http://localhost:8080/auth/asyncWaitForever' -Method Put -Headers $mindyCommonHeaders
        }
        it 'Throws exception - Get Async Operation as Morty' {
            { Invoke-RestMethod -Uri "http://localhost:8080/task/$($responseCreateAsync.ID)" -Method Get -Headers $mortyCommonHeaders } |
                Should -Throw #-ExceptionType ([Microsoft.PowerShell.Commands.HttpResponseException])
        }
        it 'Throws exception - Terminate Async Operation as Morty' {
            { Invoke-RestMethod -Uri "http://localhost:8080/task?taskId=$($responseCreateAsync.ID)" -Method Delete -Headers $mortyCommonHeaders } |
                Should -Throw  #-Exception Type ([Microsoft.PowerShell.Commands.HttpResponseException])
        }

        it 'Get Async Operation as Mindy' {
            $response = Invoke-RestMethod -Uri "http://localhost:8080/task/$($responseCreateAsync.ID)" -Method Get -Headers $mindyCommonHeaders
            # Assertions to validate the response
            $response | Should -Not -BeNullOrEmpty
            $response.User | Should -Be 'MINDY021'
            $response.Name | Should -Be '__Put_auth_asyncWaitForever__'
            $response.State | Should -BeIn 'Running'
            $response.Cancelable | Should -Be $true
        }

        it 'Terminate Async Operation as Mindy' {
            $response = Invoke-RestMethod -Uri "http://localhost:8080/task?taskId=$($responseCreateAsync.ID)" -Method Delete -Headers $mindyCommonHeaders
            # Assertions to validate the response
            $response | Should -Not -BeNullOrEmpty
            $response.User | Should -Be 'MINDY021'
            $response.Name | Should -Be '__Put_auth_asyncWaitForever__'
            $response.State | Should -BeIn 'Aborted'
            $response.Error | Should -BeIn 'User Aborted!'
            $response.Cancelable | Should -Be $true
        }
    }

    Describe -Name 'Query Async Operation' {
        it 'Get Query Async Operation as Mindy' {
            $body = @{'CreationTime' = @{
                    'value' = get-date '2024-07-05T13:20:00-07:00'
                    'op'    = 'GE'
                }
            } | ConvertTo-Json
            $response = Invoke-RestMethod -Uri 'http://localhost:8080/tasks' -Method Post -Body $body -Headers $mindyCommonHeaders
            # Assertions to validate the response
            $response | Should -Not -BeNullOrEmpty
            $response.Count | Should -Be 7
            $response.state.where({ $_ -eq 'Aborted' }).count | Should -Be 1
        }

        it 'Get Query Async Operation as Morty' {
            $body = @{'CreationTime' = @{
                    'value' = get-date '2024-07-05T13:20:00-07:00'
                    'op'    = 'GE'
                }
            } | ConvertTo-Json
            $response = Invoke-RestMethod -Uri 'http://localhost:8080/tasks' -Method Post -Body $body -Headers $mortyCommonHeaders
            # Assertions to validate the response
            $response | Should -Not -BeNullOrEmpty
            $response.Count | Should -Be 5
            $response.state.where({ $_ -eq 'Aborted' }).count | Should -Be 0
        }
    }

    Describe -Name 'Waiting for results ' {
        it 'Wendy results' {
            do {
                $response = Invoke-RestMethod -Uri 'http://localhost:8080/tasks' -Method Post -Body '{}' -Headers $mindyCommonHeaders
                Start-Sleep 2
            } until ($response.state.where({ $_ -eq 'Running' -or $_ -eq 'NotStarted' }).count -eq 0)
            # Assertions to validate the response
            $response | Should -Not -BeNullOrEmpty
            $response.Count | Should -Be 7
            $response.state.where({ $_ -eq 'Aborted' }).count | Should -Be 1
            $response.where({ $_.Name -eq '__Put_auth_asyncUsingCancelable__' }).Result.InnerValue | Should -Be 'coming from using'
            $response.where({ $_.Name -eq '__Put_auth_asyncUsing__' }).Result.InnerValue | Should -Be 'coming from using'
            $response.where({ $_.Name -eq '__Put_auth_asyncUsingNotCancelable__' }).Result.InnerValue | Should -Be 'coming from using'
            $response.where({ $_.Name -eq '__Put_auth_asyncWaitForever__' }).State | Should -Be 'Aborted'
            $response.where({ $_.Name -eq '__Put_auth_asyncParam__' }).Result.InnerValue | Should -Be 'comming as argument'
            $response.where({ $_.Name -eq '__Put_auth_asyncStateNoColumn__' }).Result.InnerValue | Should -Be 'coming from a PodeState'
            $response.where({ $_.Name -eq '__Put_auth_asyncState__' }).Result.InnerValue | Should -Be 'coming from a PodeState'
        }
        it 'Morty results' {
            do {
                $response = Invoke-RestMethod -Uri 'http://localhost:8080/tasks' -Method Post -Body '{}' -Headers $mortyCommonHeaders
                Start-Sleep 2
            } until ($response.state.where({ $_ -eq 'Running' -or $_ -eq 'NotStarted' }).count -eq 0)
            # Assertions to validate the response
            $response | Should -Not -BeNullOrEmpty
            $response.Count | Should -Be 5
            $response.state.where({ $_ -eq 'Aborted' }).count | Should -Be 0
            $response.where({ $_.Name -eq '__Put_auth_asyncUsingCancelable__' }).Result.InnerValue | Should -Be 'coming from using'
            $response.where({ $_.Name -eq '__Put_auth_asyncUsing__' }).Result.InnerValue | Should -Be 'coming from using'
            $response.where({ $_.Name -eq '__Put_auth_asyncUsingNotCancelable__' }).Result.InnerValue | Should -Be 'coming from using'
            $response.where({ $_.Name -eq '__Put_auth_asyncParam__' }).Result.InnerValue | Should -Be 'comming as argument'
            $response.where({ $_.Name -eq '__Put_auth_asyncState__' }).Result.InnerValue | Should -Be 'coming from a PodeState'
        }

    }

}


#}