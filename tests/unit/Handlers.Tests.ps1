$path = $MyInvocation.MyCommand.Path
$src = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]unit', '/src/'
Get-ChildItem "$($src)/*.ps1" -Recurse | Resolve-Path | ForEach-Object { . $_ }

$PodeContext = @{ 'Server' = $null; }

Describe 'Get-PodeTcpHandler' {
    Context 'Invalid parameters supplied' {
        It 'Throw invalid type error' {
            { Get-PodeTcpHandler -Type 'MOO' } | Should Throw "Cannot validate argument on parameter 'Type'"
        }
    }

    Context 'Valid parameters' {
        It 'Return null as type does not exist' {
            $PodeContext.Server = @{ 'Handlers' = @{}; }
            Get-PodeTcpHandler -Type TCP | Should Be $null
        }

        It 'Returns logic for type' {
            $PodeContext.Server = @{ 'Handlers' = @{ 'TCP' = { Write-Host 'hello' }; }; }
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
            $PodeContext.Server = @{ 'Handlers' = @{ 'TCP' = {}; }; }
            { Handler -Type TCP -ScriptBlock {} } | Should Throw 'already defined'
        }

        It 'Adds tcp handler' {
            $PodeContext.Server = @{ 'Handlers' = @{}; }
            Handler -Type TCP -ScriptBlock { Write-Host 'hello' }

            $handler = $PodeContext.Server.Handlers['tcp']
            $handler | Should Not be $null
            $handler.ToString() | Should Be ({ Write-Host 'hello' }).ToString()
        }

        It 'Adds smtp handler' {
            $PodeContext.Server = @{ 'Handlers' = @{}; }
            Handler -Type SMTP -ScriptBlock { Write-Host 'hello' }

            $handler = $PodeContext.Server.Handlers['smtp']
            $handler | Should Not be $null
            $handler.ToString() | Should Be ({ Write-Host 'hello' }).ToString()
        }

        It 'Adds service handler' {
            $PodeContext.Server = @{ 'Handlers' = @{}; }
            Handler -Type Service -ScriptBlock { Write-Host 'hello' }

            $handler = $PodeContext.Server.Handlers['service']
            $handler | Should Not be $null
            $handler.ToString() | Should Be ({ Write-Host 'hello' }).ToString()
        }
    }
}