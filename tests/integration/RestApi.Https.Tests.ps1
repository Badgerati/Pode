[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseUsingScopeModifierInNewRunspaces', '')]
param()

Describe 'REST API Requests' {
    BeforeAll {
        $splatter = @{}
        $UseCurl = $true
        $version = $PSVersionTable.PSVersion
        if ( $version.Major -eq 5) {
            # Ignore SSL certificate validation errors
            Add-Type @'
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAllCertsPolicy : ICertificatePolicy {
public bool CheckValidationResult(
    ServicePoint srvPoint, X509Certificate certificate,
    WebRequest request, int certificateProblem) {
    return true;
}
}
'@

            [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
            $UseCurl = $false
        }
        elseif ($PSVersionTable.OS -like '*Windows*') {
            # OS check passed, now check PowerShell version
            # Split version by '.' and compare major and minor version
            if (  $version.Major -gt 7 -or ($version.Major -eq 7 -and $version.Minor -ge 4)) {
                # Running on Windows with PowerShell Core 7.4 or greater.
                $UseCurl = $true
            }
            else {
                $UseCurl = $false
                $splatter.SkipCertificateCheck = $true
                # Running on Windows but with PowerShell version less than 7.4.
            }

        }
        else {
            # Not running on Windows."
            $UseCurl = $false
            $splatter.SkipCertificateCheck = $true
        }


        $Port = 8080
        $Endpoint = "https://127.0.0.1:$($Port)"

        Start-Job -Name 'Pode' -ErrorAction Stop -ScriptBlock {
            Import-Module -Name "$($using:PSScriptRoot)\..\..\src\Pode.psm1"

            function Write-OuterImportedResponse {
                Write-PodeJsonResponse -Value @{ Message = 'Outer Hello' }
            }

            Start-PodeServer -RootPath $using:PSScriptRoot -Quiet -ScriptBlock {
                Add-PodeEndpoint -Address localhost -Port $using:Port -Protocol Https -SelfSigned

                New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging
                Add-PodeRoute -Method Get -Path '/close' -ScriptBlock {
                    Close-PodeServer
                }

                function Write-InnerImportedResponse {
                    Write-PodeJsonResponse -Value @{ Message = 'Inner Hello' }
                }

                Add-PodeRoute -Method Get -Path '/ping' -ScriptBlock {
                    Write-PodeJsonResponse -Value @{ Result = 'Pong' }
                }

                Add-PodeRoute -Method Get -Path '/data/query' -ScriptBlock {
                    Write-PodeJsonResponse -Value @{ Username = $WebEvent.Query.username }
                }

                Add-PodeRoute -Method Post -Path '/data/payload' -ScriptBlock {
                    Write-PodeJsonResponse -Value @{ Username = $WebEvent.Data.username }
                }

                Add-PodeRoute -Method Post -Path '/data/payload-forced-type' -ContentType 'application/json' -ScriptBlock {
                    Write-PodeJsonResponse -Value @{ Username = $WebEvent.Data.username }
                }

                Add-PodeRoute -Method Get -Path '/data/param/:username' -ScriptBlock {
                    Write-PodeJsonResponse -Value @{ Username = $WebEvent.Parameters.username }
                }

                Add-PodeRoute -Method Get -Path '/data/param/:username/messages' -ScriptBlock {
                    Write-PodeJsonResponse -Value @{
                        Messages = @('Hello, world!', 'Greetings', 'Wubba Lub')
                    }
                }

                Add-PodeRoute -Method Delete -Path '/api/:username/remove' -ScriptBlock {
                    Write-PodeJsonResponse -Value @{ Result = 'OK' }
                }

                Add-PodeRoute -Method Patch -Path '/api/:username/update' -ScriptBlock {
                    Write-PodeJsonResponse -Value @{ Result = 'OK' }
                }

                Add-PodeRoute -Method Put -Path '/api/:username/replace' -ScriptBlock {
                    Write-PodeJsonResponse -Value @{ Result = 'OK' }
                }

                Add-PodeRoute -Method Post -Path '/encoding/transfer' -ScriptBlock {
                    Write-PodeJsonResponse -Value @{ Username = $WebEvent.Data.username }
                }

                Add-PodeRoute -Method Post -Path '/encoding/transfer-forced-type' -TransferEncoding 'gzip' -ScriptBlock {
                    Write-PodeJsonResponse -Value @{ Username = $WebEvent.Data.username }
                }

                Add-PodeRoute -Method * -Path '/all' -ScriptBlock {
                    Write-PodeJsonResponse -Value @{ Result = 'OK' }
                }

                Add-PodeRoute -Method Get -Path '/api/*/hello' -ScriptBlock {
                    Write-PodeJsonResponse -Value @{ Result = 'OK' }
                }

                Add-PodeRoute -Method Get -Path '/imported/func/outer' -ScriptBlock {
                    Write-OuterImportedResponse
                }

                Add-PodeRoute -Method Get -Path '/imported/func/inner' -ScriptBlock {
                    Write-InnerImportedResponse
                }
            }
        }

        Start-Sleep -Seconds 10
    }

    AfterAll {
        Receive-Job -Name 'Pode' | Out-Default
        if ($UseCurl) {
            curl -s -X DELETE "$($Endpoint)/close" -k
        }
        else {
            Invoke-RestMethod -Uri "$($Endpoint)/close" -Method Get @splatter | Out-Null
        }
        Get-Job -Name 'Pode' | Remove-Job -Force
    }


    It 'responds back with pong' {
        if ($UseCurl) {
            $result = (curl -s -X GET "$($Endpoint)/ping" -k) | ConvertFrom-Json
        }
        else {
            $result = Invoke-RestMethod -Uri "$($Endpoint)/ping" -Method Get @splatter
        }
        $result.Result | Should -Be 'Pong'
    }

    It 'responds back with 404 for invalid route' {
        if ($UseCurl) {
            $status_code = (curl -s -o /dev/null -w '%{http_code}' "$Endpoint/eek" -k)
            $status_code | Should -be 404
        }
        else {
            { Invoke-RestMethod -Uri "$($Endpoint)/eek" -Method Get -ErrorAction Stop @splatter } | Should -Throw  -ExpectedMessage '*404*'
        }
    }

    It 'responds back with 405 for incorrect method' {
        if ($UseCurl) {
            $status_code = (curl -X POST -s -o /dev/null -w '%{http_code}' "$Endpoint/ping" -k)
            $status_code | Should -be 405
        }
        else {
            { Invoke-RestMethod -Uri "$($Endpoint)/ping" -Method Post -ErrorAction Stop @splatter } | Should -Throw  -ExpectedMessage '*405*'
        }
    }

    It 'responds with simple query parameter' {
        if ($UseCurl) {
            $result = (curl -s -X GET "$($Endpoint)/data/query?username=rick" -k) | ConvertFrom-Json
        }
        else {
            $result = Invoke-RestMethod -Uri "$($Endpoint)/data/query?username=rick" -Method Get @splatter
        }
        $result.Username | Should -Be 'rick'
    }

    It 'responds with simple payload parameter - json' {
        if ($UseCurl) {
            $result = curl -s -X POST "$($Endpoint)/data/payload" -H 'Content-Type: application/json' -d '{"username":"rick"}' -k | ConvertFrom-Json
        }
        else {
            $result = Invoke-RestMethod -Uri "$($Endpoint)/data/payload" -Method Post -Body '{"username":"rick"}' -ContentType 'application/json' @splatter
        }
        $result.Username | Should -Be 'rick'
    }

    It 'responds with simple payload parameter - xml' {
        if ($UseCurl) {
            $result = curl -s -X POST "$($Endpoint)/data/payload" -H 'Content-Type: text/xml' -d '<username>rick</username>' -k | ConvertFrom-Json
        }
        else {
            $result = Invoke-RestMethod -Uri "$($Endpoint)/data/payload" -Method Post -Body '<username>rick</username>' -ContentType 'text/xml' @splatter
        }
        $result.Username | Should -Be 'rick'
    }

    It 'responds with simple payload parameter forced to json' {
        if ($UseCurl) {
            $result = curl -s -X POST "$($Endpoint)/data/payload-forced-type"  -d '{"username":"rick"}' -k | ConvertFrom-Json
        }
        else {
            $result = Invoke-RestMethod -Uri "$($Endpoint)/data/payload-forced-type" -Method Post -Body '{"username":"rick"}' @splatter
        }
        $result.Username | Should -Be 'rick'
    }

    It 'responds with simple route parameter' {
        if ($UseCurl) {
            $result = (curl -s -X GET "$($Endpoint)/data/param/rick" -k) | ConvertFrom-Json
        }
        else {
            $result = Invoke-RestMethod -Uri "$($Endpoint)/data/param/rick" -Method Get @splatter
        }
        $result.Username | Should -Be 'rick'
    }

    It 'responds with simple route parameter long' {
        if ($UseCurl) {
            $result = (curl -s -X GET "$($Endpoint)/data/param/rick/messages" -k) | ConvertFrom-Json
        }
        else {
            $result = Invoke-RestMethod -Uri "$($Endpoint)/data/param/rick/messages" -Method Get @splatter
        }
        $result.Messages[0] | Should -Be 'Hello, world!'
        $result.Messages[1] | Should -Be 'Greetings'
        $result.Messages[2] | Should -Be 'Wubba Lub'
    }

    It 'responds ok to remove account' {
        if ($UseCurl) {
            $result = (curl -s -X DELETE "$($Endpoint)/api/rick/remove" -k) | ConvertFrom-Json
        }
        else {
            $result = Invoke-RestMethod -Uri "$($Endpoint)/api/rick/remove" -Method Delete @splatter
        }
        $result.Result | Should -Be 'OK'
    }

    It 'responds ok to replace account' {
        if ($UseCurl) {
            $result = (curl -s -X PUT "$($Endpoint)/api/rick/replace" -k) | ConvertFrom-Json
        }
        else {
            $result = Invoke-RestMethod -Uri "$($Endpoint)/api/rick/replace" -Method Put @splatter
        }
        $result.Result | Should -Be 'OK'
    }

    It 'responds ok to update account' {
        if ($UseCurl) {
            $result = (curl -s -X PATCH "$($Endpoint)/api/rick/update" -k) | ConvertFrom-Json
        }
        else {
            $result = Invoke-RestMethod -Uri "$($Endpoint)/api/rick/update" -Method Patch @splatter
        }
        $result.Result | Should -Be 'OK'
    }

    It 'decodes encoded payload parameter - gzip' {
        $data = @{ username = 'rick' }
        $message = ($data | ConvertTo-Json)

        # compress the message using gzip
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($message)
        $ms = New-Object -TypeName System.IO.MemoryStream
        $gzip = New-Object System.IO.Compression.GZipStream($ms, [IO.Compression.CompressionMode]::Compress, $true)
        $gzip.Write($bytes, 0, $bytes.Length)
        $gzip.Close()

        if ($UseCurl) {
            $compressedData = $ms.ToArray()
            $ms.Dispose()
            # Save the compressed data to a temporary file
            $tempFile = [System.IO.Path]::GetTempFileName()
            [System.IO.File]::WriteAllBytes($tempFile, $compressedData)
            # make the request
            $result = curl -s -X POST "$Endpoint/encoding/transfer" -H 'Transfer-Encoding: gzip' -H 'Content-Type: application/json' --data-binary "@$tempFile" -k | ConvertFrom-Json

            # Cleanup the temporary file
            Remove-Item -Path $tempFile
        }
        else {
            # make the request
            $ms.Position = 0
            $result = Invoke-RestMethod -Uri "$($Endpoint)/encoding/transfer" -Method Post -Body $ms.ToArray() -Headers @{ 'Transfer-Encoding' = 'gzip' } -ContentType 'application/json' @splatter
            $ms.Dispose()
        }

        $result.Username | Should -Be 'rick'

    }

    It 'decodes encoded payload parameter - deflate' {
        $data = @{ username = 'rick' }
        $message = ($data | ConvertTo-Json)

        # compress the message using deflate
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($message)
        $ms = New-Object -TypeName System.IO.MemoryStream
        $gzip = New-Object System.IO.Compression.DeflateStream($ms, [IO.Compression.CompressionMode]::Compress, $true)
        $gzip.Write($bytes, 0, $bytes.Length)
        $gzip.Close()
        if ($UseCurl) {
            $compressedData = $ms.ToArray()
            $ms.Dispose()

            # Save the compressed data to a temporary file
            $tempFile = [System.IO.Path]::GetTempFileName()
            [System.IO.File]::WriteAllBytes($tempFile, $compressedData)

            # make the request
            $result = curl -s -X POST "$Endpoint/encoding/transfer" -H 'Transfer-Encoding: deflate' -H 'Content-Type: application/json' --data-binary "@$tempFile" -k | ConvertFrom-Json

            # Cleanup the temporary file
            Remove-Item -Path $tempFile
        }
        else {
            # make the request
            $ms.Position = 0
            $result = Invoke-RestMethod -Uri "$($Endpoint)/encoding/transfer" -Method Post -Body $ms.ToArray() -Headers @{  'Transfer-Encoding' = 'deflate' } -ContentType 'application/json' @splatter
            $ms.Dispose()
        }

        $result.Username | Should -Be 'rick'
    }

    It 'decodes encoded payload parameter forced to gzip' {
        $data = @{ username = 'rick' }
        $message = ($data | ConvertTo-Json)

        # compress the message using gzip
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($message)
        $ms = New-Object -TypeName System.IO.MemoryStream
        $gzip = New-Object System.IO.Compression.GZipStream($ms, [IO.Compression.CompressionMode]::Compress, $true)
        $gzip.Write($bytes, 0, $bytes.Length)
        $gzip.Close()
        if ($UseCurl) {

            $compressedData = $ms.ToArray()
            $ms.Dispose()

            # Save the compressed data to a temporary file
            $tempFile = [System.IO.Path]::GetTempFileName()
            [System.IO.File]::WriteAllBytes($tempFile, $compressedData)
            # make the request
            $result = curl -s -X POST "$Endpoint/encoding/transfer-forced-type"  -H 'Content-Type: application/json' --data-binary "@$tempFile" -k | ConvertFrom-Json

            # Cleanup the temporary file
            Remove-Item -Path $tempFile
        }
        else {
            # make the request
            $ms.Position = 0
            $result = Invoke-RestMethod -Uri "$($Endpoint)/encoding/transfer-forced-type" -Method Post -Body $ms.ToArray() -ContentType 'application/json' @splatter
            $ms.Dispose()
        }

        $result.Username | Should -Be 'rick'
    }

    It 'works with any method' {
        if ($UseCurl) {
            $result = (curl -s -X GET "$($Endpoint)/all" -k) | ConvertFrom-Json
            $result.Result | Should -Be 'OK'

            $result = (curl -s -X PUT "$($Endpoint)/all" -k) | ConvertFrom-Json
            $result.Result | Should -Be 'OK'

            $result = (curl -s -X PATCH "$($Endpoint)/all" -k) | ConvertFrom-Json
            $result.Result | Should -Be 'OK'
        }
        else {
            $result = Invoke-RestMethod -Uri "$($Endpoint)/all" -Method Get @splatter
            $result.Result | Should -Be 'OK'

            $result = Invoke-RestMethod -Uri "$($Endpoint)/all" -Method Put @splatter
            $result.Result | Should -Be 'OK'

            $result = Invoke-RestMethod -Uri "$($Endpoint)/all" -Method Patch @splatter
            $result.Result | Should -Be 'OK'
        }
    }

    It 'route with a wild card' {
        if ($UseCurl) {
            $result = (curl -s -X GET "$($Endpoint)/api/stuff/hello" -k) | ConvertFrom-Json
            $result.Result | Should -Be 'OK'

            $result = (curl -s -X GET "$($Endpoint)/api/random/hello" -k) | ConvertFrom-Json
            $result.Result | Should -Be 'OK'

            $result = (curl -s -X GET "$($Endpoint)/api/123/hello" -k) | ConvertFrom-Json
            $result.Result | Should -Be 'OK'
        }
        else {
            $result = Invoke-RestMethod -Uri "$($Endpoint)/api/stuff/hello" -Method Get @splatter
            $result.Result | Should -Be 'OK'

            $result = Invoke-RestMethod -Uri "$($Endpoint)/api/random/hello" -Method Get @splatter
            $result.Result | Should -Be 'OK'

            $result = Invoke-RestMethod -Uri "$($Endpoint)/api/123/hello" -Method Get @splatter
            $result.Result | Should -Be 'OK'
        }
    }

    It 'route importing outer function' {
        if ($UseCurl) {
            $result = (curl -s -X GET "$($Endpoint)/imported/func/outer" -k) | ConvertFrom-Json
        }
        else {
            $result = Invoke-RestMethod -Uri "$($Endpoint)/imported/func/outer" -Method Get @splatter
        }
        $result.Message | Should -Be 'Outer Hello'
    }

    It 'route importing outer function' {
        if ($UseCurl) {
            $result = (curl -s -X GET "$($Endpoint)/imported/func/inner" -k) | ConvertFrom-Json
        }
        else {
            $result = Invoke-RestMethod -Uri "$($Endpoint)/imported/func/inner" -Method Get @splatter
        }
        $result.Message | Should -Be 'Inner Hello'
    }
}