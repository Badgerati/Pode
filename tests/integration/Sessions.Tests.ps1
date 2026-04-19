[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseUsingScopeModifierInNewRunspaces', '')]
param()

Describe 'Session Requests' {

    BeforeAll {
        $Port = 8080
        $Endpoint = "http://127.0.0.1:$($Port)"

        Start-Job -Name 'Pode' -ErrorAction Stop -ScriptBlock {
            Import-Module -Name "$($using:PSScriptRoot)\..\..\src\Pode.psm1"

            Start-PodeServer -Quiet -ScriptBlock {
                Add-PodeEndpoint -Address localhost -Port $using:Port -Protocol Http
                Add-PodeRoute -Method Get -Path '/close' -ScriptBlock {
                    Close-PodeServer
                }

                Add-PodeRoute -Method Get -Path '/ping' -ScriptBlock {
                    Write-PodeJsonResponse -Value @{ Result = 'Pong' }
                }

                Enable-PodeSessionMiddleware -Secret 'schwifty' -Duration 5 -Extend -UseHeaders

                New-PodeAuthScheme -Basic | Add-PodeAuth -Name 'Auth' -ScriptBlock {
                    param($username, $password)

                    if (($username -eq 'morty') -and ($password -eq 'pickle')) {
                        return @{ User = @{ ID = 'M0R7Y302' } }
                    }

                    return @{ Message = 'Invalid details supplied' }
                }

                Add-PodeRoute -Method Post -Path '/auth/basic' -Authentication Auth -ScriptBlock {
                    $WebEvent.Session.Data.Views++

                    Write-PodeJsonResponse -Value @{
                        Result   = 'OK'
                        Username = $WebEvent.Auth.User.ID
                        Views    = $WebEvent.Session.Data.Views
                    }
                }
            }
        }

        Mock Invoke-WebRequest {
            param($Uri, [string]$Method, $Headers)

            $handler = [System.Net.Http.HttpClientHandler]::new()
            $client = [System.Net.Http.HttpClient]::new($handler)

            $request = [System.Net.Http.HttpRequestMessage]::new($Method, $Uri)

            if ($null -ne $Headers) {
                foreach ($key in $Headers.Keys) {
                    $request.Headers.Add($key, $Headers[$key])
                }
            }

            $response = $client.SendAsync($request).GetAwaiter().GetResult()
            $content = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()

            $webResponse = @{
                Content    = $content
                StatusCode = $response.StatusCode.value__
                Headers    = @{}
            }

            if ($null -ne $response.Headers) {
                foreach ($header in $response.Headers.GetEnumerator()) {
                    $webResponse.Headers[$header.Key] = $header.Value -join ', '
                }
            }

            if ($null -ne $response.Content.Headers) {
                foreach ($header in $response.Content.Headers.GetEnumerator()) {
                    $webResponse.Headers[$header.Key] = $header.Value -join ', '
                }
            }

            return $webResponse
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

    It 'returns ok for valid creds' {
        $result = Invoke-WebRequest -Uri "$($Endpoint)/auth/basic" -Method Post -Headers @{ Authorization = 'Basic bW9ydHk6cGlja2xl' }
        $content = ($result.Content | ConvertFrom-Json)

        $content.Result | Should -Be 'OK'
        $content.Views | Should -Be 1
        $result.Headers['pode.sid'] | Should -Not -BeNullOrEmpty
    }

    It 'returns 401 for invalid creds' {
        { Invoke-RestMethod -Uri "$($Endpoint)/auth/basic" -Method Post -Headers @{ Authorization = 'Basic cmljazpwaWNrbGU=' } -ErrorAction Stop } | Should -Throw -ExpectedMessage '*401*'
    }

    It 'returns ok for session requests' {
        $result = Invoke-WebRequest -Uri "$($Endpoint)/auth/basic" -Method Post -Headers @{ Authorization = 'Basic bW9ydHk6cGlja2xl' }
        $content = ($result.Content | ConvertFrom-Json)

        $content.Result | Should -Be 'OK'
        $content.Views | Should -Be 1
        $result.Headers['pode.sid'] | Should -Not -BeNullOrEmpty

        $session = ($result.Headers['pode.sid'] | Select-Object -First 1)
        $result = Invoke-WebRequest -Uri "$($Endpoint)/auth/basic" -Method Post -Headers @{ 'pode.sid' = $session }
        $content = ($result.Content | ConvertFrom-Json)
        $content.Result | Should -Be 'OK'
        $content.Views | Should -Be 2

        $session = ($result.Headers['pode.sid'] | Select-Object -First 1)
        $result = Invoke-WebRequest -Uri "$($Endpoint)/auth/basic" -Method Post -Headers @{ 'pode.sid' = $session }
        $content = ($result.Content | ConvertFrom-Json)
        $content.Result | Should -Be 'OK'
        $content.Views | Should -Be 3
    }

    It 'returns 401 for invalid session' {
        { Invoke-RestMethod -Uri "$($Endpoint)/auth/basic" -Method Post -Headers @{ 'pode.sid' = 'some-fake-session' } -ErrorAction Stop } | Should -Throw -ExpectedMessage '*401*'
    }

    It 'returns 401 for session timeout' {
        $result = Invoke-WebRequest -Uri "$($Endpoint)/auth/basic" -Method Post -Headers @{ Authorization = 'Basic bW9ydHk6cGlja2xl' }
        $content = ($result.Content | ConvertFrom-Json)

        $content.Result | Should -Be 'OK'
        $content.Views | Should -Be 1
        $result.Headers['pode.sid'] | Should -Not -BeNullOrEmpty

        $session = ($result.Headers['pode.sid'] | Select-Object -First 1)
        $result = Invoke-WebRequest -Uri "$($Endpoint)/auth/basic" -Method Post -Headers @{ 'pode.sid' = $session }
        $content = ($result.Content | ConvertFrom-Json)
        $content.Result | Should -Be 'OK'
        $content.Views | Should -Be 2

        Start-Sleep -Seconds 6

        $session = ($result.Headers['pode.sid'] | Select-Object -First 1)
        { Invoke-RestMethod -Uri "$($Endpoint)/auth/basic" -Method Post -Headers @{ 'pode.sid' = $session } -ErrorAction Stop } | Should -Throw -ExpectedMessage '*401*'
    }
}