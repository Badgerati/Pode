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

    # allow the local ip
    access allow ip 127.0.0.1

    # setup a tcp handler
    handler 'tcp' {
        param($session)
        tcp write 'gief data'
        $msg = (tcp read)
        Write-Host $msg
    }

}