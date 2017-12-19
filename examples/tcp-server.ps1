if ((Get-Module -Name Pode | Measure-Object).Count -ne 0)
{
    Remove-Module -Name Pode
}

$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -ErrorAction Stop

# or just:
# Import-Module Pode

# create a server, and start listening on port 8999
Server -Tcp -Port 8999 {

    # setup a tcp handler
    Add-PodeTcpHandler 'tcp' {
        param($session)
        Write-ToTcpStream -Message 'gief data'
        $msg = Read-FromTcpStream
        Write-Host $msg
    }

}