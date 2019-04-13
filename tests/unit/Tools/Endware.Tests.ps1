$path = $MyInvocation.MyCommand.Path
$src = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]unit[\\/]', '/src/'
Get-ChildItem "$($src)/*.ps1" | Resolve-Path | ForEach-Object { . $_ }

Describe 'Invoke-PodeEndware' {
    It 'Returns for no endware' {
        (Invoke-PodeEndware -WebEvent @{} -Endware @()) | Out-Null
    }

    It 'Runs the logic for a single endware' {
        Mock Invoke-ScriptBlock { }
        Invoke-PodeEndware -WebEvent @{} -Endware @({ 'test' | Out-Null })
        Assert-MockCalled Invoke-ScriptBlock -Times 1 -Scope It
    }

    It 'Runs the logic for 2 endwares' {
        Mock Invoke-ScriptBlock { }
        Invoke-PodeEndware -WebEvent @{} -Endware @(
            { 'test' | Out-Null },
            { 'test2' | Out-Null })
        Assert-MockCalled Invoke-ScriptBlock -Times 2 -Scope It
    }

    It 'Runs the logic for a single endware and errors' {
        Mock Invoke-ScriptBlock { throw 'some error' }
        Mock Out-Default { }

        Invoke-PodeEndware -WebEvent @{} -Endware @({ 'test' | Out-Null })

        Assert-MockCalled Invoke-ScriptBlock -Times 1 -Scope It
        Assert-MockCalled Out-Default -Times 1 -Scope It
    }
}

Describe 'Endware' {
    Context 'Invalid parameters supplied' {
        It 'Throws null logic error' {
            { Endware -ScriptBlock $null } | Should Throw 'argument is null'
        }
    }

    Context 'Valid parameters' {
        It 'Adds single Endware to list' {
            $PodeContext = @{ 'Server' = @{ 'Endware' = @(); }; }

            Endware -ScriptBlock { write-host 'end1' }

            $PodeContext.Server.Endware.Length | Should Be 1
            $PodeContext.Server.Endware[0].ToString() | Should Be ({ Write-Host 'end1' }).ToString()
        }

        It 'Adds two Endwares to list' {
            $PodeContext = @{ 'Server' = @{ 'Endware' = @(); }; }

            Endware -ScriptBlock { write-host 'end1' }
            Endware -ScriptBlock { write-host 'end2' }

            $PodeContext.Server.Endware.Length | Should Be 2
            $PodeContext.Server.Endware[0].ToString() | Should Be ({ Write-Host 'end1' }).ToString()
            $PodeContext.Server.Endware[1].ToString() | Should Be ({ Write-Host 'end2' }).ToString()
        }
    }
}