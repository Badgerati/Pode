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

    # Add a simple MCP tool for returning all windows service names
    Add-PodeMcpTool -Name 'GetWindowsServices' -Description 'Returns all Windows service names' -Group 'Default' -ScriptBlock {
        $services = Get-Service -ErrorAction Ignore | Select-Object Name
        return New-PodeMcpTextContent -Value $services
    }

    # Add a simple MCP tool for returning windows services names for a given state
    Add-PodeMcpTool -Name 'GetWindowsServicesByState' -Description 'Returns Windows service names for a given state' -Group 'Default' -AutoSchema -ScriptBlock {
        param(
            [Parameter(Mandatory = $true, HelpMessage = 'The state of the services to retrieve')]
            [ValidateSet('Running', 'Stopped', 'Paused')]
            [string]
            $State
        )

        $services = Get-Service -ErrorAction Ignore | Where-Object { $_.Status -ieq $State } | Select-Object Name
        if (($null -eq $services) -or (Test-PodeIsEmpty $services)) {
            $services = "No services found in the '$State' state."
        }

        return New-PodeMcpTextContent -Value $services
    }

    # Add a simple MCP tool for testing if a specified service is in a specified state
    Add-PodeMcpTool -Name 'TestWindowsServiceState' -Description 'Tests if a specified service is in a specified state' -Group 'Default' -ScriptBlock {
        param(
            [string]
            $Name,

            [ValidateSet('Running', 'Stopped', 'Paused')]
            [string]
            $State
        )

        $service = Get-Service -Name $Name -ErrorAction Ignore
        if ($null -eq $service) {
            return New-PodeMcpTextContent -Value "Service '$Name' not found."
        }

        if ($service.Status -ieq $State) {
            return New-PodeMcpTextContent -Value "Service '$Name' is in the '$State' state."
        }

        return New-PodeMcpTextContent -Value "Service '$Name' is not in the '$State' state. Current state: $($service.Status)"
    } -PassThru |
        Add-PodeMcpToolProperty -Name 'Name' -Required -Definition (
            New-PodeJsonSchemaString -Description 'The name of the service to check'
        ) -PassThru |
        Add-PodeMcpToolProperty -Name 'State' -Required -Definition (
            New-PodeJsonSchemaString -Description 'The state to check for the service' -Enum 'Running', 'Stopped', 'Paused'
        )

    # Add the MCP route
    Add-PodeRoute -Method Post -Path '/mcp-services' -ScriptBlock {
        $WebEvent.Data | ConvertTo-Json | Out-Default
        Resolve-PodeMcpRequest -Group 'Default'
    }
}