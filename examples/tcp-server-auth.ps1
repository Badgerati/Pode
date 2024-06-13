try {
    $ScriptPath = (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
    $podePath = Split-Path -Parent -Path $ScriptPath
    if (Test-Path -Path "$($podePath)/src/Pode.psm1" -PathType Leaf) {
        Import-Module "$($podePath)/src/Pode.psm1" -Force -ErrorAction Stop
    }
    else {
        Import-Module -Name 'Pode' -ErrorAction Stop
    }
}
catch { throw }

# or just:
# Import-Module Pode

# create a server, and start listening on port 8081
Start-PodeServer -Threads 2 {

    # add endpoint
    Add-PodeEndpoint -Address localhost -Port 8081 -Protocol Tcp -CRLFMessageEnd

    # enable logging
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging

    # create a role access method get retrieves roles from a database
    New-PodeAccessScheme -Type Role | Add-PodeAccess -Name 'RoleExample' -ScriptBlock {
        param($username)
        if ($username -ieq 'morty') {
            return @('Developer')
        }

        return 'QA'
    }

    # setup a Verb that only allows Developers
    Add-PodeVerb -Verb 'EXAMPLE :username' -ScriptBlock {
        if (!(Test-PodeAccess -Name 'RoleExample' -Destination 'Developer' -ArgumentList $TcpEvent.Parameters.username)) {
            Write-PodeTcpClient -Message 'Forbidden Access'
            'Forbidden!' | Out-Default
            return
        }

        Write-PodeTcpClient -Message 'Hello, there!'
        'Hello!' | Out-Default
    }
}