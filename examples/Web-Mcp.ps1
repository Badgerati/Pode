<#
.SYNOPSIS
    A PowerShell script to set up a Pode server with simple MCP tools for MCP clients.

.DESCRIPTION
    This script sets up a Pode server that listens on a specified port, and provides a simple set of tools for MCP clients to interact with.

.EXAMPLE
    To run the sample: ./Web-Mcp.ps1
.LINK
    https://github.com/Badgerati/Pode/blob/develop/examples/Web-Mcp.ps1

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

    # listen on localhost:8081
    Add-PodeEndpoint -Address localhost -Port 8081 -Protocol Http

    # request logging
    New-PodeLoggingMethod -Terminal -Batch 10 -BatchTimeout 10 | Enable-PodeRequestLogging
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging

    # Create a simple default group for MCP tools
    Add-PodeMcpGroup -Name 'Default' -Description 'Default group for MCP tools'

    # Add a simple MCP tool for returning a random greeting
    Add-PodeMcpTool -Name 'Greet' -Description 'Returns a random greeting' -Group 'Default' -ScriptBlock {
        $greetings = @('Hello', 'Hi', 'Hey', 'Greetings', 'Salutations')
        $greeting = Get-Random -InputObject $greetings
        return New-PodeMcpTextContent -Value "$($greeting) from the Pode MCP tool!"
    }

    # Add a simple MCP tool for returning a random greeting to a person
    Add-PodeMcpTool -Name 'GreetPerson' -Description 'Returns a random greeting to a person' -Group 'Default' -AutoSchema -ScriptBlock {
        param(
            [Parameter(Mandatory = $true, HelpMessage = 'The name of the person to greet')]
            [string]$Name
        )
        $greetings = @('Hello', 'Hi', 'Hey', 'Greetings', 'Salutations')
        $greeting = Get-Random -InputObject $greetings
        return New-PodeMcpTextContent -Value "$($greeting), $($Name)! from the Pode MCP tool!"
    }

    # Add a simple MCP tool for returning a random greeting to a person in a location
    Add-PodeMcpTool -Name 'GreetPersonInLocation' -Description 'Returns a random greeting to a person in a location' -Group 'Default' -ScriptBlock {
        param(
            [string]$Name,
            [string]$Location
        )
        $greetings = @('Hello', 'Hi', 'Hey', 'Greetings', 'Salutations')
        $greeting = Get-Random -InputObject $greetings
        return New-PodeMcpTextContent -Value "$($greeting), $($Name) from $($Location)! via the Pode MCP tool!"
    } -PassThru |
        Add-PodeMcpToolProperty -Name 'Name' -Required -Definition (
            New-PodeJsonSchemaString -Description 'The name of the person to greet'
        ) -PassThru |
        Add-PodeMcpToolProperty -Name 'Location' -Required -Definition (
            New-PodeJsonSchemaString -Description 'The location of the person to greet'
        )

    # Add the MCP route
    Add-PodeRoute -Method Post -Path '/mcp-tests' -ScriptBlock {
        # $WebEvent.Data | ConvertTo-Json | Out-Default
        Resolve-PodeMcpRequest -Group 'Default'
    }
}