$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

# or just:
# Import-Module Pode

# create a server, and start listening on port 9000
Start-PodeServer -Threads 2 {

    # add endpoint
    Add-PodeEndpoint -Address * -Port 9000 -Protocol Tcp -CRLFMessageEnd

    # enable logging
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging

    # create a role access method get retrieves roles from a database
    Add-PodeAuthAccess -Name 'RoleExample' -Type Role -ScriptBlock {
        param($username)
        if ($username -ieq 'morty') {
            return @('Developer')
        }

        return 'QA'
    }

    # setup a Verb that only allows Developers
    Add-PodeVerb -Verb 'EXAMPLE :username' -ScriptBlock {
        if (!(Test-PodeAuthAccess -Name 'RoleExample' -Destination 'Developer' -ArgumentList $TcpEvent.Parameters.username)) {
            Write-PodeTcpClient -Message "Forbidden Access"
            'Forbidden!' | Out-Default
            return
        }

        Write-PodeTcpClient -Message "Hello, there!"
        'Hello!' | Out-Default
    }
}