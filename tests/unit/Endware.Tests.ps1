[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '')]
param()
BeforeAll {
    $path = $PSCommandPath
    $src = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]unit', '/src/'
    Get-ChildItem "$($src)/*.ps1" -Recurse | Resolve-Path | ForEach-Object { . $_ }
    Import-LocalizedData -BindingVariable PodeLocale -BaseDirectory (Join-Path -Path $src -ChildPath 'Locales') -FileName 'Pode'
}

Describe 'Invoke-PodeEndware' {
    It 'Returns for no endware' {
        (Invoke-PodeEndware -Endware @()) | Out-Null
    }

    It 'Runs the logic for a single endware' {
        Mock Invoke-PodeScriptBlock { }
        Invoke-PodeEndware -Endware @(@{ Logic = { 'test' | Out-Null } })
        Assert-MockCalled Invoke-PodeScriptBlock -Times 1 -Scope It
    }

    It 'Runs the logic for 2 endwares' {
        Mock Invoke-PodeScriptBlock { }
        Invoke-PodeEndware -Endware @(
            @{ Logic = { 'test' | Out-Null } },
            @{ Logic = { 'test2' | Out-Null } }
        )
        Assert-MockCalled Invoke-PodeScriptBlock -Times 2 -Scope It
    }

    It 'Runs the logic for a single endware and errors' {
        Mock Invoke-PodeScriptBlock { throw 'some error' }
        Mock Write-PodeErrorLog { }

        Invoke-PodeEndware -Endware @(@{ Logic = { 'test' | Out-Null } })

        Assert-MockCalled Invoke-PodeScriptBlock -Times 1 -Scope It
        Assert-MockCalled Write-PodeErrorLog -Times 1 -Scope It
    }
}

Describe 'Add-PodeEndware' {
    Context 'Invalid parameters supplied' {
        It 'Throws null logic error' {
            { Add-PodeEndware -ScriptBlock $null } | Should -Throw -ErrorId 'ParameterArgumentValidationErrorNullNotAllowed,Add-PodeEndware'
        }
    }

    Context 'Valid parameters' {
        It 'Adds single Endware to list' {
            $PodeContext = @{ 'Server' = @{ 'Endware' = @(); }; }

            Add-PodeEndware -ScriptBlock { write-host 'end1' }

            $PodeContext.Server.Endware.Length | Should -Be 1
            $PodeContext.Server.Endware[0].Logic.ToString() | Should -Be ({ Write-Host 'end1' }).ToString()
        }

        It 'Adds two Endwares to list' {
            $PodeContext = @{ 'Server' = @{ 'Endware' = @(); }; }

            Add-PodeEndware -ScriptBlock { write-host 'end1' }
            Add-PodeEndware -ScriptBlock { write-host 'end2' }

            $PodeContext.Server.Endware.Length | Should -Be 2
            $PodeContext.Server.Endware[0].Logic.ToString() | Should -Be ({ Write-Host 'end1' }).ToString()
            $PodeContext.Server.Endware[1].Logic.ToString() | Should -Be ({ Write-Host 'end2' }).ToString()
        }
    }
}