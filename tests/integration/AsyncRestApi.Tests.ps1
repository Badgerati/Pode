[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseUsingScopeModifierInNewRunspaces', '')]
param()


Describe 'ASYNC REST API Requests' {

    BeforeAll {
        $commonHeaders = @{
            'accept'        = 'application/yaml'
            'X-API-KEY'     = 'test2-api-key'
            'Authorization' = 'Basic bWluZHk6cGlja2xl'
        }

        $Port = 8080
        $Endpoint = "http://127.0.0.1:$($Port)"
        $scriptPath = "$($PSScriptRoot)\..\..\examples\Async.ps1"
        if ($PSVersionTable.PsVersion -gt [version]'6.0') {
            Start-Process 'pwsh' -ArgumentList "-NoProfile -File `"$scriptPath`" -Quiet -Port $Port -DisableTermination"  -NoNewWindow

            #  Invoke-Command -FilePath $scriptPath -ArgumentList  'Quiet', "Port $Port", 'DisableTermination'
        }
        else {
            Start-Process 'powershell' -ArgumentList "-NoProfile -File `"$scriptPath`" -Quiet -Port $Port -DisableTermination"  -NoNewWindow
        }
        Start-Sleep -Seconds 10
    }

    AfterAll {
        Invoke-RestMethod -Uri "$($Endpoint)/close" -Method Post | Out-Null

    }

    It 'PUT request on behalf of Mindy to /auth/asyncUsingNotCancelable' {
        $response = Invoke-RestMethod -Uri 'http://localhost:8080/auth/asyncUsingNotCancelable' -Method Put -Headers $commonHeaders

        # Assertions to validate the response
        $response | Should -Not -BeNullOrEmpty
        $response.User | Should -Be 'MINDY021'
        $response.Name | Should -Be '__Put_auth_asyncUsingNotCancelable__'
        $response.State | Should -BeIn @('NotStarted', 'Running')
        $response.Cancelable | Should -Be $false
    }

    It 'PUT request on behalf of Mindy to /auth/asyncUsingNCancelable' {
        $response = Invoke-RestMethod -Uri 'http://localhost:8080/auth/asyncUsingNCancelable' -Method Put -Headers $commonHeaders

        # Assertions to validate the response
        $response | Should -Not -BeNullOrEmpty
        $response.User | Should -Be 'MINDY021'
        $response.Name | Should -Be '__Put_auth_asyncUsingNCancelable__'
        $response.State | Should -BeIn @('NotStarted', 'Running')
        $response.Cancelable | Should -Be $true
    }

    It 'PUT request on behalf of Mindy to /auth/asyncUsing with JSON body' {
        $body = @{
            callbackUrl = 'http://localhost:8080/receive/callback'
        } | ConvertTo-Json

        $headersWithContentType = $commonHeaders.Clone()
        $headersWithContentType['Content-Type'] = 'application/json'

        $response = Invoke-RestMethod -Uri 'http://localhost:8080/auth/asyncUsing' -Method Put -Headers $headersWithContentType -Body $body

        # Assertions to validate the response
        $response | Should -Not -BeNullOrEmpty
        $response.User | Should -Be 'MINDY021'
        $response.Name | Should -Be '__Put_auth_asyncUsing__'
        $response.State | Should -BeIn @('NotStarted', 'Running')
        $response.Cancelable | Should -Be $true
    }

    It 'PUT request on behalf of Mindy to /auth/asyncStateNoColumn' {
        $response = Invoke-RestMethod -Uri 'http://localhost:8080/auth/asyncStateNoColumn' -Method Put -Headers $commonHeaders

        # Assertions to validate the response
        $response | Should -Not -BeNullOrEmpty
        $response.User | Should -Be 'MINDY021'
        $response.Name | Should -Be '__Put_auth_asyncStateNoColumn__'
        $response.State | Should -BeIn @('NotStarted', 'Running')
        $response.Cancelable | Should -Be $true
    }

    It 'PUT request on behalf of Mindy to /auth/asyncState' {
        $response = Invoke-RestMethod -Uri 'http://localhost:8080/auth/asyncState' -Method Put -Headers $commonHeaders

        # Assertions to validate the response
        $response | Should -Not -BeNullOrEmpty
        $response.User | Should -Be 'MINDY021'
        $response.Name | Should -Be '__Put_auth_asyncState__'
        $response.State | Should -BeIn @('NotStarted', 'Running')
        $response.Cancelable | Should -Be $true
    }

    It 'PUT request on behalf of Mindy to /auth/asyncParam' {
        $response = Invoke-RestMethod -Uri 'http://localhost:8080/auth/asyncParam' -Method Put -Headers $commonHeaders

        # Assertions to validate the response
        $response | Should -Not -BeNullOrEmpty
        $response.User | Should -Be 'MINDY021'
        $response.Name | Should -Be '__Put_auth_asyncParam__'
        $response.State | Should -BeIn @('NotStarted', 'Running')
        $response.Cancelable | Should -Be $true
    }
}



#}