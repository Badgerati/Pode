$path = $MyInvocation.MyCommand.Path
$src = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]unit', '/src/'
Get-ChildItem "$($src)/*.ps1" -Recurse | Resolve-Path | ForEach-Object { . $_ }

$PodeContext = @{ 'Server' = $null; }

Describe 'Get-PodeHandler' {
    Context 'Invalid parameters supplied' {
        It 'Throw invalid type error' {
            { Get-PodeHandler -Type 'Moo' } | Should Throw "Cannot validate argument on parameter 'Type'"
        }
    }

    Context 'Valid parameters' {
        It 'Return null as type does not exist' {
            $PodeContext.Server = @{ 'Handlers' = @{}; }
            Get-PodeHandler -Type Tcp | Should Be $null
        }

        It 'Returns handlers for type' {
            $PodeContext.Server = @{ 'Handlers' = @{ 'TCP' = @{
                'Main' = @{
                    'Logic' = { Write-Host 'hello' };
                };
             }; }; }

            $result = (Get-PodeHandler -Type Tcp)

            $result | Should Not Be $null
            $result.Count | Should Be 1
            $result.Main.Logic.ToString() | Should Be ({ Write-Host 'hello' }).ToString()
        }

        It 'Returns handler for type by name' {
            $PodeContext.Server = @{ 'Handlers' = @{ 'TCP' = @{
                'Main' = @{
                    'Logic' = { Write-Host 'hello' };
                };
             }; }; }

            $result = (Get-PodeHandler -Type Tcp -Name 'Main')

            $result | Should Not Be $null
            $result.Logic.ToString() | Should Be ({ Write-Host 'hello' }).ToString()
        }

        It 'Returns no handler for type by name' {
            $PodeContext.Server = @{ 'Handlers' = @{ 'TCP' = @{
                'Main' = @{
                    'Logic' = { Write-Host 'hello' };
                };
             }; }; }

            $result = (Get-PodeHandler -Type Tcp -Name 'Fail')
            $result | Should Be $null
        }
    }
}

Describe 'Add-PodeHandler' {
    It 'Throws error because type already exists' {
        $PodeContext.Server = @{ 'Handlers' = @{ 'TCP' = @{ 'Main' = @{}; }; }; }
        { Add-PodeHandler -Type Tcp -Name 'Main' -ScriptBlock {} } | Should Throw 'already defined'
    }

    It 'Adds tcp handler' {
        $PodeContext.Server = @{ 'Handlers' = @{ 'TCP' = @{}; }; }
        Add-PodeHandler -Type Tcp -Name 'Main' -ScriptBlock { Write-Host 'hello' }

        $handler = $PodeContext.Server.Handlers['tcp']
        $handler.Count | Should Be 1
        $handler['Main'].Logic.ToString() | Should Be ({ Write-Host 'hello' }).ToString()
    }

    It 'Adds smtp handler' {
        $PodeContext.Server = @{ 'Handlers' = @{ 'SMTP' = @{}; }; }
        Add-PodeHandler -Type Smtp -Name 'Main' -ScriptBlock { Write-Host 'hello' }

        $handler = $PodeContext.Server.Handlers['smtp']
        $handler.Count | Should Be 1
        $handler['Main'].Logic.ToString() | Should Be ({ Write-Host 'hello' }).ToString()
    }

    It 'Adds service handler' {
        $PodeContext.Server = @{ 'Handlers' = @{ 'Service' = @{}; }; }
        Add-PodeHandler -Type Service -Name 'Main' -ScriptBlock { Write-Host 'hello' }

        $handler = $PodeContext.Server.Handlers['service']
        $handler.Count | Should Be 1
        $handler['Main'].Logic.ToString() | Should Be ({ Write-Host 'hello' }).ToString()
    }
}

Describe 'Remove-PodeHandler' {
    It 'Adds two handlers, and removes one by name' {
        $PodeContext.Server = @{ 'Handlers' = @{ 'TCP' = @{}; }; }

        Add-PodeHandler -Type Tcp -Name 'Main1' -ScriptBlock { Write-Host 'hello1' }
        Add-PodeHandler -Type Tcp -Name 'Main2' -ScriptBlock { Write-Host 'hello2' }

        $handler = $PodeContext.Server.Handlers['tcp']
        $handler.Count | Should Be 2
        $handler['Main1'].Logic.ToString() | Should Be ({ Write-Host 'hello1' }).ToString()
        $handler['Main2'].Logic.ToString() | Should Be ({ Write-Host 'hello2' }).ToString()

        Remove-PodeHandler -Type Tcp -Name 'Main1'

        $handler = $PodeContext.Server.Handlers['tcp']
        $handler.Count | Should Be 1
        $handler['Main2'].Logic.ToString() | Should Be ({ Write-Host 'hello2' }).ToString()
    }
}

Describe 'Clear-PodeHandlers' {
    It 'Adds handlers, and removes them all for one type' {
        $PodeContext.Server = @{ 'Handlers' = @{
            'TCP' = @{};
            'SMTP' = @{};
            'Service' = @{};
        }; }

        Add-PodeHandler -Type Tcp -Name 'Main' -ScriptBlock { Write-Host 'hello' }
        Add-PodeHandler -Type Smtp -Name 'Main' -ScriptBlock { Write-Host 'hello' }
        Add-PodeHandler -Type Service -Name 'Main' -ScriptBlock { Write-Host 'hello' }

        $handler = $PodeContext.Server.Handlers['tcp']
        $handler.Count | Should Be 1

        $handler = $PodeContext.Server.Handlers['smtp']
        $handler.Count | Should Be 1

        $handler = $PodeContext.Server.Handlers['service']
        $handler.Count | Should Be 1

        Clear-PodeHandlers -Type Tcp

        $handler = $PodeContext.Server.Handlers['tcp']
        $handler.Count | Should Be 0

        $handler = $PodeContext.Server.Handlers['smtp']
        $handler.Count | Should Be 1

        $handler = $PodeContext.Server.Handlers['service']
        $handler.Count | Should Be 1
    }

    It 'Adds handlers, and removes them all' {
        $PodeContext.Server = @{ 'Handlers' = @{
            'TCP' = @{};
            'SMTP' = @{};
            'Service' = @{};
        }; }

        Add-PodeHandler -Type Tcp -Name 'Main' -ScriptBlock { Write-Host 'hello' }
        Add-PodeHandler -Type Smtp -Name 'Main' -ScriptBlock { Write-Host 'hello' }
        Add-PodeHandler -Type Service -Name 'Main' -ScriptBlock { Write-Host 'hello' }

        $handler = $PodeContext.Server.Handlers['tcp']
        $handler.Count | Should Be 1

        $handler = $PodeContext.Server.Handlers['smtp']
        $handler.Count | Should Be 1

        $handler = $PodeContext.Server.Handlers['service']
        $handler.Count | Should Be 1

        Clear-PodeHandlers

        $handler = $PodeContext.Server.Handlers['tcp']
        $handler.Count | Should Be 0

        $handler = $PodeContext.Server.Handlers['smtp']
        $handler.Count | Should Be 0

        $handler = $PodeContext.Server.Handlers['service']
        $handler.Count | Should Be 0
    }
}