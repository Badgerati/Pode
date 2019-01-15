param (
    [int]
    $Port = 8085
)

$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

# or just:
# Import-Module Pode

# create a server, and start listening on port 8085
Server -Threads 2 {

    # listen on localhost:8085
    listen *:$Port http

    # GET request for web page on "localhost:8085/"
    route 'get' '/' {
        view 'web-upload'
    }

    # GET request to upload a file
    route 'post' '/upload' {
        save 'avatar' '.'
        redirect '/'
    }

}