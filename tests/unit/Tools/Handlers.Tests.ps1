$path = $MyInvocation.MyCommand.Path
$src = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]unit[\\/]', '/src/'
Get-ChildItem "$($src)/*.ps1" | Resolve-Path | ForEach-Object { . $_ }

$PodeSession = @{ 'Server' = $null; }

Describe 'Get-PodeTcpHandler' {
    Context 'Invalid parameters supplied' {
        It 'Throw invalid type error' {
            { Get-PodeTcpHandler -Type 'MOO' } | Should Throw "Cannot validate argument on parameter 'Type'"
        }
    }

    Context 'Valid parameters' {
        It 'Return null as type does not exist' {
            $PodeSession.Server = @{ 'Handlers' = @{}; }
            Get-PodeTcpHandler -Type TCP | Should Be $null
        }

        It 'Returns logic for type' {
            $PodeSession.Server = @{ 'Handlers' = @{ 'TCP' = { Write-Host 'hello' }; }; }
            $result = (Get-PodeTcpHandler -Type TCP)

            $result | Should Not Be $null
            $result.ToString() | Should Be ({ Write-Host 'hello' }).ToString()
        }
    }
}

Describe 'Handler' {
    Context 'Invalid parameters supplied' {
        It 'Throws invalid type error' {
            { Handler -Type 'MOO' -ScriptBlock {} } | Should Throw "Cannot validate argument on parameter 'Type'"
        }

        It 'Throws null scriptblock parameter error' {
            { Handler -Type TCP -ScriptBlock $null } | Should Throw 'The argument is null'
        }
    }

    Context 'Valid handler parameters' {
        It 'Throws error because type already exists' {
            $PodeSession.Server = @{ 'Handlers' = @{ 'TCP' = {}; }; }
            { Handler -Type TCP -ScriptBlock {} } | Should Throw 'already defined'
        }

        It 'Adds tcp handler' {
            $PodeSession.Server = @{ 'Handlers' = @{}; }
            Handler -Type TCP -ScriptBlock { Write-Host 'hello' }

            $handler = $PodeSession.Server.Handlers['tcp']
            $handler | Should Not be $null
            $handler.ToString() | Should Be ({ Write-Host 'hello' }).ToString()
        }

        It 'Adds smtp handler' {
            $PodeSession.Server = @{ 'Handlers' = @{}; }
            Handler -Type SMTP -ScriptBlock { Write-Host 'hello' }

            $handler = $PodeSession.Server.Handlers['smtp']
            $handler | Should Not be $null
            $handler.ToString() | Should Be ({ Write-Host 'hello' }).ToString()
        }

        It 'Adds service handler' {
            $PodeSession.Server = @{ 'Handlers' = @{}; }
            Handler -Type Service -ScriptBlock { Write-Host 'hello' }

            $handler = $PodeSession.Server.Handlers['service']
            $handler | Should Not be $null
            $handler.ToString() | Should Be ({ Write-Host 'hello' }).ToString()
        }
    }
}