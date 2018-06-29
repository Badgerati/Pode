$path = $MyInvocation.MyCommand.Path
$src = (Split-Path -Parent -Path $path) -ireplace '\\tests\\unit\\', '\src\'
$sut = (Split-Path -Leaf -Path $path) -ireplace '\.Tests\.', '.'
. "$($src)\$($sut)"

Describe 'Get-PodeContentType' {

    Context 'No extension supplied' {
        It 'Return the default type for empty' {
            Get-PodeContentType -Extension ([string]::Empty) | Should Be 'text/plain'
        }

        It 'Return the default type for null' {
            Get-PodeContentType -Extension $null | Should Be 'text/plain'
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