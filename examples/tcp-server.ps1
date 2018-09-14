$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

# or just:
# Import-Module Pode

# create a server, and start listening on port 8999
Server -Threads 2 {

    listen *:8999 tcp

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