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
        $scriptPath = "$($PSScriptRoot)\..\..\examples\AsyncRoute.ps1"
        if ($PSVersionTable.PsVersion -gt [version]'6.0') {
            Start-Process 'pwsh' -ArgumentList "-NoProfile -File `"$scriptPath`" -Quiet -Port $Port -DisableTermination"  -NoNewWindow
        }
        else {
            Start-Process 'powershell' -ArgumentList "-NoProfile -File `"$scriptPath`" -Quiet -Port $Port -DisableTermination"  -NoNewWindow
        }
        Start-Sleep -Seconds 5
    }

    AfterAll {
        Start-Sleep -Seconds 10
        Invoke-RestMethod -Uri "$($Endpoint)/close" -Method Post | Out-Null

    }

    Describe 'Hello Server' {
        it 'Hello Server' {
            Start-Sleep -Seconds 10
            $response = Invoke-RestMethod -Uri "http://localhost:$($Port)/hello" -Method Get
            $response.message | Should -Be 'Hello!'
        }
    }

    Describe 'Create Async Route Task on behalf of Mindy' {

        It 'Create Async Route Task /auth/asyncUsingNotCancellable' {

            $response = Invoke-RestMethod -Uri "http://localhost:$($Port)/auth/asyncUsingNotCancellable" -Method Put -Headers $mindyCommonHeaders

            # Assertions to validate the response
            $response | Should -Not -BeNullOrEmpty
            $response.User | Should -Be 'MINDY021'
            $response.AsyncRouteId | Should -Be '__Put_auth_asyncUsingNotCancellable__'
            $response.State | Should -BeIn @('NotStarted', 'Running')
            $response.Cancellable | Should -Be $false
        }

        It 'Create Async Route Task /auth/asyncUsingCancellable' {
            $response = Invoke-RestMethod -Uri "http://localhost:$($Port)/auth/asyncUsingCancellable" -Method Put -Headers $mindyCommonHeaders

            # Assertions to validate the response
            $response | Should -Not -BeNullOrEmpty
            $response.User | Should -Be 'MINDY021'
            $response.AsyncRouteId | Should -Be '__Put_auth_asyncUsingCancellable__'
            $response.State | Should -BeIn @('NotStarted', 'Running')
            $response.Cancellable | Should -Be $true
        }

        It 'Create Async Route Task /auth/asyncUsing with JSON body' {
            $body = @{
                callbackUrl = "http://localhost:$($Port)/receive/callback"
            } | ConvertTo-Json

            $headersWithContentType = $mindyCommonHeaders.Clone()
            $headersWithContentType['Content-Type'] = 'application/json'

            $response = Invoke-RestMethod -Uri "http://localhost:$($Port)/auth/asyncUsing" -Method Put -Headers $headersWithContentType -Body $body

            # Assertions to validate the response
            $response | Should -Not -BeNullOrEmpty
            $response.User | Should -Be 'MINDY021'
            $response.AsyncRouteId | Should -Be '__Put_auth_asyncUsing__'
            $response.State | Should -BeIn @('NotStarted', 'Running')
            $response.Cancellable | Should -Be $true
        }

        It 'Create Async Route Task /auth/asyncStateNoColumn' {
            $response = Invoke-RestMethod -Uri "http://localhost:$($Port)/auth/asyncStateNoColumn" -Method Put -Headers $mindyCommonHeaders

            # Assertions to validate the response
            $response | Should -Not -BeNullOrEmpty
            $response.User | Should -Be 'MINDY021'
            $response.AsyncRouteId | Should -Be '__Put_auth_asyncStateNoColumn__'
            $response.State | Should -BeIn @('NotStarted', 'Running')
            $response.Cancellable | Should -Be $true
        }

        It 'Create Async Route Task /auth/asyncState' {
            $response = Invoke-RestMethod -Uri "http://localhost:$($Port)/auth/asyncState" -Method Put -Headers $mindyCommonHeaders

            # Assertions to validate the response
            $response | Should -Not -BeNullOrEmpty
            $response.User | Should -Be 'MINDY021'
            $response.AsyncRouteId | Should -Be '__Put_auth_asyncState__'
            $response.State | Should -BeIn @('NotStarted', 'Running')
            $response.Cancellable | Should -Be $true
        }

        It 'Create Async Route Task /auth/asyncParam' {
            $response = Invoke-RestMethod -Uri "http://localhost:$($Port)/auth/asyncParam" -Method Put -Headers $mindyCommonHeaders

            # Assertions to validate the response
            $response | Should -Not -BeNullOrEmpty
            $response.User | Should -Be 'MINDY021'
            $response.AsyncRouteId | Should -Be '__Put_auth_asyncParam__'
            $response.State | Should -BeIn @('NotStarted', 'Running')
            $response.Cancellable | Should -Be $true
        }
    }

    Describe 'Create Async Route Task on behalf of Morty' {
        It 'Create Async Route Task /auth/asyncUsingNotCancellable' {
            $response = Invoke-RestMethod -Uri "http://localhost:$($Port)/auth/asyncUsingNotCancellable" -Method Put -Headers $mortyCommonHeaders

            # Assertions to validate the response
            $response | Should -Not -BeNullOrEmpty
            $response.User | Should -Be 'M0R7Y302'
            $response.AsyncRouteId | Should -Be '__Put_auth_asyncUsingNotCancellable__'
            $response.State | Should -BeIn @('NotStarted', 'Running')
            $response.Cancellable | Should -Be $false
        }

        It 'Create Async Route Task /auth/asyncUsingCancellable' {
            $response = Invoke-RestMethod -Uri "http://localhost:$($Port)/auth/asyncUsingCancellable" -Method Put -Headers $mortyCommonHeaders

            # Assertions to validate the response
            $response | Should -Not -BeNullOrEmpty
            $response.User | Should -Be 'M0R7Y302'
            $response.AsyncRouteId | Should -Be '__Put_auth_asyncUsingCancellable__'
            $response.State | Should -BeIn @('NotStarted', 'Running')
            $response.Cancellable | Should -Be $true
        }

        It 'Create Async Route Task /auth/asyncUsing with JSON body' {
            $body = @{
                callbackUrl = "http://localhost:$($Port)/receive/callback"
            } | ConvertTo-Json

            $headersWithContentType = $mortyCommonHeaders.Clone()
            $headersWithContentType['Content-Type'] = 'application/json'

            $response = Invoke-RestMethod -Uri "http://localhost:$($Port)/auth/asyncUsing" -Method Put -Headers $headersWithContentType -Body $body

            # Assertions to validate the response
            $response | Should -Not -BeNullOrEmpty
            $response.User | Should -Be 'M0R7Y302'
            $response.AsyncRouteId | Should -Be '__Put_auth_asyncUsing__'
            $response.State | Should -BeIn @('NotStarted', 'Running')
            $response.Cancellable | Should -Be $true
        }

        It 'Throws exception - Create Async Route Task /auth/asyncStateNoColumn' {
            { Invoke-RestMethod -Uri "http://localhost:$($Port)/auth/asyncStateNoColumn" -Method Put -Headers $mortyCommonHeaders } | Should -Throw
        }

        It 'Create Async Route Task /auth/asyncState' {
            $response = Invoke-RestMethod -Uri "http://localhost:$($Port)/auth/asyncState" -Method Put -Headers $mortyCommonHeaders

            # Assertions to validate the response
            $response | Should -Not -BeNullOrEmpty
            $response.User | Should -Be 'M0R7Y302'
            $response.AsyncRouteId | Should -Be '__Put_auth_asyncState__'
            $response.State | Should -BeIn @('NotStarted', 'Running')
            $response.Cancellable | Should -Be $true
        }

        It 'Create Async Route Task /auth/asyncParam' {
            $response = Invoke-RestMethod -Uri "http://localhost:$($Port)/auth/asyncParam" -Method Put -Headers $mortyCommonHeaders

            # Assertions to validate the response
            $response | Should -Not -BeNullOrEmpty
            $response.User | Should -Be 'M0R7Y302'
            $response.AsyncRouteId | Should -Be '__Put_auth_asyncParam__'
            $response.State | Should -BeIn @('NotStarted', 'Running')
            $response.Cancellable | Should -Be $true
        }

        It 'Create Async Route Task /asyncWaitForeverTimeout' {
            $response = Invoke-RestMethod -Uri "http://localhost:$($Port)/auth/asyncInfiniteLoopTimeout" -Method Put -Headers $mortyCommonHeaders

            # Assertions to validate the response
            $response | Should -Not -BeNullOrEmpty
            $response.User | Should -Be 'M0R7Y302'
            $response.AsyncRouteId | Should -Be '__Put_auth_asyncInfiniteLoopTimeout__'
            $response.State | Should -BeIn @('NotStarted', 'Running')
            $response.Cancellable | Should -Be $false
        }
    }

    Describe -Name 'Get Async Route Task' {
        BeforeAll {
            $responseCreateAsync = Invoke-RestMethod -Uri "http://localhost:$($Port)/auth/asyncInfiniteLoop" -Method Put -Headers $mindyCommonHeaders
        }
        it 'Throws exception - Get Async Route Task as Morty' {
            { Invoke-RestMethod -Uri "http://localhost:$($Port)/task/$($responseCreateAsync.ID)" -Method Get -Headers $mortyCommonHeaders } |
                Should -Throw #-ExceptionType ([Microsoft.PowerShell.Commands.HttpResponseException])
        }
        it 'Throws exception - Terminate Async Route Task as Morty' {
            { Invoke-RestMethod -Uri "http://localhost:$($Port)/task?id=$($responseCreateAsync.ID)" -Method Delete -Headers $mortyCommonHeaders } |
                Should -Throw  #-Exception Type ([Microsoft.PowerShell.Commands.HttpResponseException])
        }

        it 'Get Async Route Task as Mindy' {
            $response = Invoke-RestMethod -Uri "http://localhost:$($Port)/task/$($responseCreateAsync.ID)" -Method Get -Headers $mindyCommonHeaders
            # Assertions to validate the response
            $response | Should -Not -BeNullOrEmpty
            $response.User | Should -Be 'MINDY021'
            $response.AsyncRouteId | Should -Be '__Put_auth_asyncInfiniteLoop__'
            $response.State | Should -BeIn 'Running'
            $response.Cancellable | Should -Be $true
        }

        it 'Terminate Async Route Task as Mindy' {
            $response = Invoke-RestMethod -Uri "http://localhost:$($Port)/task?id=$($responseCreateAsync.ID)" -Method Delete -Headers $mindyCommonHeaders
            # Assertions to validate the response
            $response | Should -Not -BeNullOrEmpty
            $response.User | Should -Be 'MINDY021'
            $response.AsyncRouteId | Should -Be '__Put_auth_asyncInfiniteLoop__'
            $response.State | Should -BeIn 'Aborted'
            $response.Error | Should -BeIn 'Aborted by the user'
            $response.Cancellable | Should -Be $true
        }
    }

    Describe -Name 'Query Async Route Task' {
        it 'Get Query Async Route Task as Mindy' {
            $body = @{} | ConvertTo-Json
            $response = Invoke-RestMethod -Uri "http://localhost:$($Port)/tasks" -Method Post -Body $body -Headers $mindyCommonHeaders
            # Assertions to validate the response
            $response | Should -Not -BeNullOrEmpty
            $response.Count | Should -Be 7
            $response.state.where({ $_ -eq 'Aborted' }).count | Should -Be 1
        }

        it 'Get Query Async Route Task as Morty' {
            $body = @{} | ConvertTo-Json
            $response = Invoke-RestMethod -Uri "http://localhost:$($Port)/tasks" -Method Post -Body $body -Headers $mortyCommonHeaders
            # Assertions to validate the response
            $response | Should -Not -BeNullOrEmpty
            $response.Count | Should -Be 6
            $response.state.where({ $_ -eq 'Aborted' }).count | Should -Be 0
        }
    }

    Describe -Name 'Waiting for results ' {
        it 'Wendy results' {
            $counter = 0
            do {
                $response = Invoke-RestMethod -Uri "http://localhost:$($Port)/tasks" -Method Post -Body '{}' -Headers $mindyCommonHeaders
                Start-Sleep 2

            } until (($response.state.where({ $_ -eq 'Running' -or $_ -eq 'NotStarted' }).count -eq 0) -or (++$counter -gt 60))
            # Assertions to validate the response
            $response | Should -Not -BeNullOrEmpty
            $response.Count | Should -Be 7
            $response.state.where({ $_ -eq 'Aborted' }).count | Should -Be 1
            $response.where({ $_.AsyncRouteId -eq '__Put_auth_asyncUsingCancellable__' }).Result.InnerValue | Should -Be 'coming from using'
            $response.where({ $_.AsyncRouteId -eq '__Put_auth_asyncUsing__' }).Result.InnerValue | Should -Be 'coming from using'
            $response.where({ $_.AsyncRouteId -eq '__Put_auth_asyncUsingNotCancellable__' }).Result.InnerValue | Should -Be 'coming from using'
            $response.where({ $_.AsyncRouteId -eq '__Put_auth_asyncInfiniteLoop__' }).State | Should -Be 'Aborted'
            $response.where({ $_.AsyncRouteId -eq '__Put_auth_asyncParam__' }).Result.InnerValue | Should -Be 'comming as argument'
            $response.where({ $_.AsyncRouteId -eq '__Put_auth_asyncStateNoColumn__' }).Result.InnerValue | Should -Be 'coming from a PodeState'
            $response.where({ $_.AsyncRouteId -eq '__Put_auth_asyncState__' }).Result.InnerValue | Should -Be 'coming from a PodeState'
        }
        it 'Morty results' {
            $counter = 0
            do {
                $body = @{'AsyncRouteId' = @{
                        'value' = '__Put_auth_asyncInfiniteLoopTimeout__'
                        'op'    = 'NE'
                    }
                } | ConvertTo-Json
                $response = Invoke-RestMethod -Uri "http://localhost:$($Port)/tasks" -Method Post -Body $body -Headers $mortyCommonHeaders
                Start-Sleep 2
            } until (($response.state.where({ $_ -eq 'Running' -or $_ -eq 'NotStarted' }).count -eq 0) -or (++$counter -gt 60))
            # Assertions to validate the response
            $response | Should -Not -BeNullOrEmpty
            $response.Count | Should -Be 5
            $response.state.where({ $_ -eq 'Aborted' }).count | Should -Be 0
            $response.where({ $_.AsyncRouteId -eq '__Put_auth_asyncUsingCancellable__' }).Result.InnerValue | Should -Be 'coming from using'
            $response.where({ $_.AsyncRouteId -eq '__Put_auth_asyncUsing__' }).Result.InnerValue | Should -Be 'coming from using'
            $response.where({ $_.AsyncRouteId -eq '__Put_auth_asyncUsingNotCancellable__' }).Result.InnerValue | Should -Be 'coming from using'
            $response.where({ $_.AsyncRouteId -eq '__Put_auth_asyncParam__' }).Result.InnerValue | Should -Be 'comming as argument'
            $response.where({ $_.AsyncRouteId -eq '__Put_auth_asyncState__' }).Result.InnerValue | Should -Be 'coming from a PodeState'
        }

        it 'Timeout' {
            do {
                $body = @{'AsyncRouteId' = @{
                        'value' = '__Put_auth_asyncInfiniteLoopTimeout__'
                        'op'    = 'EQ'
                    }
                } | ConvertTo-Json
                $response = Invoke-RestMethod -Uri "http://localhost:$($Port)/tasks" -Method Post -Body $body -Headers $mortyCommonHeaders
            } until ($response.state.where({ $_ -eq 'Aborted' }).count -eq 1)
            # Assertions to validate the response
            $response | Should -Not -BeNullOrEmpty
            $response.Count | Should -Be 1
            $response.state.where({ $_ -eq 'Aborted' }).count | Should -Be 1
        }

    }

}


#}