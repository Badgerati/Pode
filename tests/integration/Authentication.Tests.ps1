Describe 'Authentication Requests' {

    BeforeAll {
        $Port = 50000
        $Endpoint = "http://localhost:$($Port)"

        Start-Job -Name 'Pode' -ErrorAction Stop -ScriptBlock {
            Import-Module -Name "$($using:PSScriptRoot)\..\..\src\Pode.psm1"

            Start-PodeServer {
                Add-PodeEndpoint -Address localhost -Port $using:Port -Protocol Http
                Add-PodeRoute -Method Get -Path '/close' -ScriptBlock {
                    Close-PodeServer
                }

                # BASIC
                New-PodeAuthType -Basic | Add-PodeAuth -Name 'BasicAuth' -ScriptBlock {
                    param($username, $password)

                    if (($username -eq 'morty') -and ($password -eq 'pickle')) {
                        return @{ User = @{ ID ='M0R7Y302' } }
                    }

                    return @{ Message = 'Invalid details supplied' }
                }

                Add-PodeRoute -Method Post -Path '/auth/basic' -Middleware (Get-PodeAuthMiddleware -Name 'BasicAuth' -Sessionless) -ScriptBlock {
                    Write-PodeJsonResponse -Value @{ Result = 'OK' }
                }

                # BEARER
                New-PodeAuthType -Bearer -Scope write | Add-PodeAuth -Name 'BearerAuth' -ScriptBlock {
                    param($token)

                    if ($token -ieq 'test-token') {
                        return @{
                            User = @{ ID ='M0R7Y302' }
                            Scope = 'write'
                        }
                    }

                    return $null
                }

                Add-PodeRoute -Method Get -Path '/auth/bearer' -Middleware (Get-PodeAuthMiddleware -Name 'BearerAuth' -Sessionless) -ScriptBlock {
                    Write-PodeJsonResponse -Value @{ Result = 'OK' }
                }

                # FORM (Monocle?)
            }
        }

        Start-Sleep -Seconds 3
    }

    AfterAll {
        Receive-Job -Name 'Pode' | Out-Default
        Invoke-RestMethod -Uri "$($Endpoint)/close" -Method Get | Out-Null
        Get-Job -Name 'Pode' | Remove-Job -Force
    }


    # BASIC
    It 'basic - returns ok for valid creds' {
        $result = Invoke-RestMethod -Uri "$($Endpoint)/auth/basic" -Method Post -Headers @{ Authorization = 'Basic bW9ydHk6cGlja2xl' }
        $result.Result | Should Be 'OK'
    }

    It 'basic - returns 401 for invalid creds' {
        { Invoke-RestMethod -Uri "$($Endpoint)/auth/basic" -Method Post -Headers @{ Authorization = 'Basic cmljazpwaWNrbGU=' } -ErrorAction Stop } | Should Throw '401'
    }

    It 'basic - returns 400 for invalid base64' {
        { Invoke-RestMethod -Uri "$($Endpoint)/auth/basic" -Method Post -Headers @{ Authorization = 'Basic cmlazpwaNrbGU' } -ErrorAction Stop } | Should Throw '400'
    }


    # BEARER
    It 'bearer - returns ok for valid token' {
        $result = Invoke-RestMethod -Uri "$($Endpoint)/auth/bearer" -Method Get -Headers @{ Authorization = 'Bearer test-token' }
        $result.Result | Should Be 'OK'
    }

    It 'bearer - returns 401 for invalid token' {
        { Invoke-RestMethod -Uri "$($Endpoint)/auth/bearer" -Method Get -Headers @{ Authorization = 'Bearer fake-token' } -ErrorAction Stop } | Should Throw '401'
    }

    It 'bearer - returns 400 for no token' {
        { Invoke-RestMethod -Uri "$($Endpoint)/auth/bearer" -Method Get -Headers @{ Authorization = 'Bearer' } -ErrorAction Stop } | Should Throw '400'
    }
}