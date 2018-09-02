$path = $MyInvocation.MyCommand.Path
$src = (Split-Path -Parent -Path $path) -ireplace '\\tests\\unit\\', '\src\'
Get-ChildItem "$($src)\*.ps1" | Resolve-Path | ForEach-Object { . $_ }

Describe 'Endware' {
    Context 'Invalid parameters supplied' {
        It 'Throws null logic error' {
            { Endware -ScriptBlock $null } | Should Throw 'argument is null'
        }
    }

    Context 'Valid parameters' {
        It 'Adds single Endware to list' {
            $PodeSession = @{ 'Server' = @{ 'Endware' = @(); }; }

            Endware -ScriptBlock { write-host 'end1' }

            $PodeSession.Server.Endware.Length | Should Be 1
            $PodeSession.Server.Endware[0].ToString() | Should Be ({ Write-Host 'end1' }).ToString()
        }

        It 'Adds two Endwares to list' {
            $PodeSession = @{ 'Server' = @{ 'Endware' = @(); }; }

            Endware -ScriptBlock { write-host 'end1' }
            Endware -ScriptBlock { write-host 'end2' }

            $PodeSession.Server.Endware.Length | Should Be 2
            $PodeSession.Server.Endware[0].ToString() | Should Be ({ Write-Host 'end1' }).ToString()
            $PodeSession.Server.Endware[1].ToString() | Should Be ({ Write-Host 'end2' }).ToString()
        }
    }
}