# Download.Tests.ps1  – Pester 5.x
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
param()


Describe 'Download endpoints' {


    # ----------  2.  Environment set-up  ----------
    BeforeAll {
        $helperPath = (Split-Path -Parent -Path $PSCommandPath) -ireplace 'integration', 'shared'
        . "$helperPath/TestHelper.ps1"

        $Port = 8080
        $Endpoint = "http://127.0.0.1:$Port"


        Wait-ForWebServer -Port $Port -Offline

        $TestFolder = Join-Path -Path ([System.IO.Path]::GetTempPath()) 'pode-test'
        $DownloadFolder = Join-Path -Path ([System.IO.Path]::GetTempPath()) 'pode-test-downloads'
        # fresh test area
        if (Test-Path $TestFolder) { Remove-Item $TestFolder -Recurse -Force }
        New-Item $TestFolder -ItemType Directory | Out-Null

        if (Test-Path $DownloadFolder) { Remove-Item $DownloadFolder -Recurse -Force }
        New-Item $DownloadFolder -ItemType Directory | Out-Null
        # start Pode in a job
        Start-Job -Name Pode -ScriptBlock {
            Import-Module "$($using:PSScriptRoot)\..\..\src\Pode.psm1"

            Start-PodeServer -RootPath $using:PSScriptRoot -Quiet -ScriptBlock {
                Add-PodeEndpoint -Address localhost -Port $using:Port -Protocol Http -DualMode
                Add-PodeRoute    -Method Get -Path '/close' -ScriptBlock { Close-PodeServer }

                Add-PodeStaticRoute -Path '/standard'  -Source $using:TestFolder -FileBrowser

                Add-PodeStaticRoute -Path '/compress'  -Source $using:TestFolder  -FileBrowser -PassThru |
                    Add-PodeRouteCompression -Enable -Encoding gzip

                Add-PodeStaticRoute -Path '/cache'  -Source $using:TestFolder  -FileBrowser -PassThru |
                    Add-PodeRouteCache -Enable -MaxAge 10 -Visibility public -ETagMode mtime -MustRevalidate -PassThru |
                    Add-PodeRouteCompression -Enable -Encoding gzip

            }
        }

        Wait-ForWebServer -Port $Port           # server is now up
    }

    AfterAll {
        Receive-Job -Name 'Pode' | Out-Default
        Invoke-RestMethod -Uri "$($Endpoint)/close" -Method Get | Out-Null
        Get-Job -Name 'Pode' | Remove-Job -Force
        if ((Test-Path $TestFolder)) {
            Remove-Item $TestFolder -Recurse -Force
        }
        if ((Test-Path $DownloadFolder)) {
            Remove-Item $DownloadFolder -Recurse -Force
        }
    }

    # ----------  3.  DATA-DRIVEN TESTS  ----------
    Context 'Pode download  standard, ranged, compressed' {
        BeforeDiscovery {
            $Sizes = @(
                @{ Label = '1MB'; Bytes = 1MB; Tag = 'Quick' },
                @{ Label = '1GB'; Bytes = 1GB; Tag = 'Medium' },
                @{ Label = '3GB'; Bytes = 3GB; Tag = 'Large' }#,
                #@{ Label = '8GB'; Bytes = 8GB; Tag = 'Huge' },
                #@{ Label = '13GB'; Bytes = 13GB; Tag = 'Enormous' }
            )
            $Kinds = @('Text', 'Binary')

            $TestCases = foreach ($size in $Sizes) {
                foreach ($kind in $Kinds) {
                    @{
                        Kind        = $kind
                        Label       = $size.Label
                        Bytes       = $size.Bytes
                        Tag         = $size.Tag
                        Ext         = $(if ($kind -eq 'Text') { '.txt' } else { '.bin' })
                        ContentType = $(if ($kind -eq 'Text') { 'text/plain; charset=utf-8' } else { 'application/octet-stream' })
                    }
                }
            }

            # expose to later blocks
            #  Set-Variable -Name TestCases -Value $TestCases -Scope Script
        }


        It 'Creates test files <Tag><Ext>' -ForEach $TestCases {
            $dest = Join-Path -Path $TestFolder -ChildPath "$Tag$Ext"

            New-TestFile -Path $dest -SizeBytes $Bytes -Kind $Kind
            (Test-Path -Path $dest -PathType Leaf) | Should -Be $true
        }
        #
        # a) full download
        #
        It 'Full download matches for <Kind> <Label>' -ForEach $TestCases {
            $url = "$Endpoint/standard/$Tag$Ext"
            $dest = (Join-Path -Path $DownloadFolder -ChildPath "full-$Label$Ext")
            $response = Invoke-CurlRequest -Url $Url -OutFile $dest  -PassThru
            $response.StatusCode | Should -Be 200
            $response.Headers['Pragma'] | Should -Be 'no-cache'
            $response.Headers['Content-Type'] | Should -Be $ContentType
            $response.Headers['Content-Disposition'] | Should -Be "inline; filename=""$Tag$Ext"""
            $directives = $response.Headers['Cache-Control'] -split '\s*,\s*'

            $directives | Should -Contain 'no-store'
            $directives | Should -Contain 'must-revalidate'
            $directives | Should -Contain 'no-cache'
            (Test-Path $dest) | Should -BeTrue
            (Get-FileHash $dest -Algo SHA256).Hash |
                Should -Be (Get-FileHash "$TestFolder\$Tag$Ext" -Algo SHA256).Hash
            Remove-Item $dest -Force
            (Test-Path  -Path $dest) | Should -BeFalse
        }

        It 'Range download matches for <Kind> <Label>' -ForEach $TestCases {
            $url = "$Endpoint/standard/$Tag$Ext"
            $dir = (Join-Path -Path $DownloadFolder -ChildPath "range-$Label")
            if (Test-Path -Path $dir) { Remove-Item $dir -Recurse -Force }
            New-Item $dir -ItemType Directory | Out-Null
            $joined = Invoke-CurlRequest -Url $Url -UseRangeDownload -DownloadDir $dir -PassThru | Select-Object -ExpandProperty OutFile

            (Test-Path $joined) | Should -BeTrue
            (Get-FileHash $joined -Algo SHA256).Hash |
                Should -Be (Get-FileHash "$TestFolder\$Tag$Ext" -Algo SHA256).Hash

            Remove-Item $joined -Force
            (Test-Path $joined) | Should -BeFalse
            if (Test-Path $dir) { Remove-Item $dir -Recurse -Force }
        }


        It 'Gzip download matches for text <Label>' -ForEach $($TestCases |
                Where-Object { $_.Kind -eq 'Text' }) {

            $url = "$Endpoint/compress/$Tag$Ext"
            $dest = (Join-Path $DownloadFolder "gzip-$Label$Ext")
            #    $response = Invoke-WebRequest $url -OutFile $dest -Headers @{ 'Accept-Encoding' = 'gzip' } -PassThru
            $response = Invoke-CurlRequest -Url $url -OutFile $dest -AcceptEncoding 'gzip' -PassThru
            $response.StatusCode | Should -Be 200
            $response.Headers['Vary'] | Should -Be 'Accept-Encoding'
            $response.Headers['Pragma'] | Should -Be 'no-cache'
            $response.Headers['Content-Type'] | Should -Be $ContentType
            $response.Headers['Content-Disposition'] | Should -Be "inline; filename=""$Tag$Ext"""
            $directives = $response.Headers['Cache-Control'] -split '\s*,\s*'
            $directives | Should -Contain 'no-store'
            $directives | Should -Contain 'must-revalidate'
            $directives | Should -Contain 'no-cache'
            $response.Headers['Content-Encoding'] | Should -Be 'gzip'

            (Get-FileHash $dest -Algo SHA256).Hash |
                Should -Be (Get-FileHash "$TestFolder\$Tag$Ext" -Algo SHA256).Hash
            Remove-Item $dest -Force
            (Test-Path $dest) | Should -BeFalse
        }


        It 'Cache download matches for text <Label>' -ForEach $($TestCases[2] ) {

            $url = "$Endpoint/cache/$Tag$Ext"
            $dest = (Join-Path $DownloadFolder "cache-$Label$Ext")
            $response = Invoke-CurlRequest -Url $Url -OutFile $dest -AcceptEncoding 'gzip' -PassThru
            $response.StatusCode | Should -Be 200
            $response.Headers['Vary'] | Should -Be 'Accept-Encoding'
            $response.Headers['Content-Type'] | Should -Be $ContentType
            $response.Headers['Content-Disposition'] | Should -Be "inline; filename=""$Tag$Ext"""
            { [DateTime]::ParseExact($response.Headers['Date'] , 'r', [CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AssumeUniversal ) } | Should -Not -Throw
            $directives = $response.Headers['Cache-Control'] -split '\s*,\s*'
            $directives | Should -Contain 'public'
            $directives | Should -Contain 'max-age=10'
            $directives | Should -Contain 'must-revalidate'
            $eTag = $response.Headers['ETag']
            $eTag | Should -Not -BeNullOrEmpty
            (Get-FileHash $dest -Algo SHA256).Hash |
                Should -Be (Get-FileHash "$TestFolder\$Tag$Ext" -Algo SHA256).Hash


            $response2 = Invoke-CurlRequest -Url $Url -OutFile $dest -ETag $eTag -AcceptEncoding 'gzip' -PassThru
            $response2.StatusCode | Should -Be 304
            $response2.Headers['Content-Disposition'] | Should -BeNullOrEmpty
            $response2.Headers['Content-Encoding'] | Should -BeNullOrEmpty
            $response2.Headers['Content-Type'] | Should -BeNullOrEmpty
            $response2.Headers['Content-Length'] | Should -BeNullOrEmpty
            { [DateTime]::ParseExact($response.Headers['Date'] , 'r', [CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AssumeUniversal ) } | Should -Not -Throw

            $response2.Headers['Vary'] | Should -Be 'Accept-Encoding'
            $directives = $response2.Headers['Cache-Control'] -split '\s*,\s*'
            $directives | Should -Contain 'public'
            $directives | Should -Contain 'max-age=10'
            $directives | Should -Contain 'must-revalidate'
            Remove-Item $dest -Force
            (Test-Path $dest) | Should -BeFalse
        }

        It 'Cache download matches for text <Label>' -ForEach $($TestCases[0] ) {

            $url = "$Endpoint/cache/$Tag$Ext"
            $dest = (Join-Path $DownloadFolder "cache-$Label$Ext")
            $response = Invoke-CurlRequest -Url $Url -OutFile $dest -AcceptEncoding 'gzip' -PassThru
            $response.StatusCode | Should -Be 200
            $response.Headers['Vary'] | Should -Be 'Accept-Encoding'
            $response.Headers['Content-Type'] | Should -Be $ContentType
            $response.Headers['Content-Disposition'] | Should -Be "inline; filename=""$Tag$Ext"""
            { [DateTime]::ParseExact($response.Headers['Date'] , 'r', [CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AssumeUniversal ) } | Should -Not -Throw
            $date = ([DateTime]::ParseExact($response.Headers['Date'] , 'r', [CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AssumeUniversal )).AddDays(1)
            $directives = $response.Headers['Cache-Control'] -split '\s*,\s*'
            $directives | Should -Contain 'public'
            $directives | Should -Contain 'max-age=10'
            $directives | Should -Contain 'must-revalidate'
            $response.Headers['ETag'] | Should -Not -BeNullOrEmpty
            (Get-FileHash $dest -Algo SHA256).Hash |
                Should -Be (Get-FileHash "$TestFolder\$Tag$Ext" -Algo SHA256).Hash
            Start-Sleep 10

            $response2 = Invoke-CurlRequest -Url $Url -OutFile $dest -IfModifiedSince $date -AcceptEncoding 'gzip' -PassThru
            $response2.StatusCode | Should -Be 304
            $response2.Headers['Content-Disposition'] | Should -BeNullOrEmpty
            $response2.Headers['Content-Encoding'] | Should -BeNullOrEmpty
            $response2.Headers['Content-Type'] | Should -BeNullOrEmpty
            $response2.Headers['Content-Length'] | Should -BeNullOrEmpty
            $response2.Headers['Vary'] | Should -Be 'Accept-Encoding'
            $directives = $response2.Headers['Cache-Control'] -split '\s*,\s*'
            $directives | Should -Contain 'public'
            $directives | Should -Contain 'max-age=10'
            $directives | Should -Contain 'must-revalidate'
            Remove-Item $dest -Force
            (Test-Path $dest) | Should -BeFalse
        }
    }
}
