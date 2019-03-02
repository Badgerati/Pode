$path = $MyInvocation.MyCommand.Path
$src = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]unit[\\/]', '/src/'
Get-ChildItem "$($src)/*.ps1" | Resolve-Path | ForEach-Object { . $_ }

Describe 'Get-PodeContentType' {
    Context 'No extension supplied' {
        It 'Return the default type for empty' {
            Get-PodeContentType -Extension ([string]::Empty) | Should Be 'text/plain'
        }

        It 'Return the default type for null' {
            Get-PodeContentType -Extension $null | Should Be 'text/plain'
        }

        It 'Return the default type for empty when DefaultIsNull' {
            Get-PodeContentType -Extension ([string]::Empty) -DefaultIsNull | Should Be $null
        }

        It 'Return the default type for null when DefaultIsNull' {
            Get-PodeContentType -Extension $null -DefaultIsNull | Should Be $null
        }
    }

    Context 'Extension with no period' {
        It 'Add a period and return type' {
            Get-PodeContentType -Extension 'mp3' | Should Be 'audio/mpeg'
        }

        It 'Add a period and return default' {
            Get-PodeContentType -Extension '<random>' | Should Be 'text/plain'
        }
    }

    Context 'Extension with period' {
        It 'Add a period and return type' {
            Get-PodeContentType -Extension '.mp3' | Should Be 'audio/mpeg'
        }

        It 'Add a period and return default' {
            Get-PodeContentType -Extension '.<random>' | Should Be 'text/plain'
        }
    }
}

Describe 'Get-PodeStatusDescription' {
    It 'Returns no description for no StatusCode' {
        Get-PodeStatusDescription | Should Be ([string]::Empty)
    }

    It 'Returns no description for unknown StatusCode' {
        Get-PodeStatusDescription -StatusCode 9001 | Should Be ([string]::Empty)
    }

    It 'Returns description for StatusCode' {
        Get-PodeStatusDescription -StatusCode 404 | Should Be 'Not Found'
    }

    It 'Returns description for first StatusCode' {
        Get-PodeStatusDescription -StatusCode 100 | Should Be 'Continue'
    }

    It 'Returns description for last StatusCode' {
        Get-PodeStatusDescription -StatusCode 526 | Should Be 'Invalid SSL Certificate'
    }
}