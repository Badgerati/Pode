Describe 'Authentication Requests' {

    BeforeAll {
        $Port = 50000
        $Endpoint = "http://localhost:$($Port)"

        Start-Job -Name 'Pode' -ErrorAction Stop -ScriptBlock {
            Import-Module -Name "$($using:PSScriptRoot)\..\..\src\Pode.psm1"

            Start-PodeServer {
                Add-PodeEndpoint -Address localhost -Port $using:Port -Protocol Http

                New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging
                Add-PodeRoute -Method Get -Path '/close' -ScriptBlock {
                    Close-PodeServer
                }

                # BASIC
                New-PodeAuthScheme -Basic | Add-PodeAuth -Name 'BasicAuth' -Sessionless -ScriptBlock {
                    param($username, $password)

                    if (($username -eq 'morty') -and ($password -eq 'pickle')) {
                        return @{ User = @{ ID ='M0R7Y302' } }
                    }

                    return @{ Message = 'Invalid details supplied' }
                }

                Add-PodeRoute -Method Post -Path '/auth/basic' -Authentication 'BasicAuth' -ScriptBlock {
                    Write-PodeJsonResponse -Value @{ Result = 'OK' }
                }

                # BEARER
                New-PodeAuthScheme -Bearer -Scope write | Add-PodeAuth -Name 'BearerAuth' -Sessionless -ScriptBlock {
                    param($token)

                    if ($token -ieq 'test-token') {
                        return @{
                            User = @{ ID ='M0R7Y302' }
                            Scope = 'write'
                        }
                    }

                    return $null
                }

                Add-PodeRoute -Method Get -Path '/auth/bearer' -Authentication 'BearerAuth' -ScriptBlock {
                    Write-PodeJsonResponse -Value @{ Result = 'OK' }
                }

                # FORM (Monocle?)
            }
        }

        Start-Sleep -Seconds 10
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