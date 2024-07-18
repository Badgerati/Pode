<#
.SYNOPSIS
    A sample PowerShell script to set up a Pode TCP server with role-based access control and logging.

.DESCRIPTION
    This script sets up a Pode TCP server that listens on port 8081, logs errors to the terminal, and implements role-based access control. The server provides an endpoint that restricts access based on user roles retrieved from a database.

.EXAMPLE
    To run the sample: ./TcpServer-Auth.ps1

.LINK
    https://github.com/Badgerati/Pode/blob/develop/examples/TcpServer-Auth.ps1

.NOTES
    Author: Pode Team
    License: MIT License
#>
try {
    # Determine the script path and Pode module path
    $ScriptPath = (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
    $podePath = Split-Path -Parent -Path $ScriptPath

    # Import the Pode module from the source path if it exists, otherwise from installed modules
    if (Test-Path -Path "$($podePath)/src/Pode.psm1" -PathType Leaf) {
        Import-Module "$($podePath)/src/Pode.psm1" -Force -ErrorAction Stop
    }
    else {
        Import-Module -Name 'Pode' -MaximumVersion 2.99 -ErrorAction Stop
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