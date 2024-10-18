<#
.SYNOPSIS
    Sets up a Pode server with OpenAPI documentation, request logging, and routes for handling 'potato' requests.

.DESCRIPTION
    This script configures a Pode server to listen on a specified port, enables both request and error logging,
    and sets up OpenAPI documentation. It defines routes for fetching 'potato' data with responses in both
    JSON and plain text. OpenAPI documentation is exposed via Swagger and other viewers.

.EXAMPLE
    ./PodeServer-OpenApi.ps1

    Invoke-RestMethod -Uri http://localhost:8080/api/v4.2/potato -Method Get

.LINK
    https://github.com/Badgerati/Pode

.NOTES
    This is an example Pode server setup that demonstrates OpenAPI integration.
    Author: Pode Team
    License: MIT License
#>

# Try to import the Pode module from the source if available, otherwise use the installed version
try {
	# Determine the script path and Pode module path
	$ScriptPath = (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
	$podePath = Split-Path -Parent -Path $ScriptPath

	# Import Pode from local source if available, otherwise from installed modules
	if (Test-Path -Path "$($podePath)/src/Pode.psm1" -PathType Leaf) {
		Import-Module "$($podePath)/src/Pode.psm1" -Force -ErrorAction Stop
	}
	else {
		Import-Module -Name 'Pode' -MaximumVersion 2.99 -ErrorAction Stop
	}
}
catch {
	throw
}

# Start the Pode server
Start-PodeServer {

	# Enable terminal logging for requests and errors
	New-PodeLoggingMethod -Terminal | Enable-PodeRequestLogging
	New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging

	# Define the endpoint for the server
	Add-PodeEndpoint -Address 127.0.0.1 -Port 8080 -Protocol Http

	# Initialize OpenAPI with basic configuration
	Enable-PodeOpenApi -Path '/docs/openapi' -DefinitionTag 'potato' -DisableMinimalDefinitions

	# Set OpenAPI info
	Add-PodeOAInfo -Title 'Potato sample - OpenAPI 3.0' `
		-Version 1.0.17 `
		-Description 'This is a simple "potato" API with the OpenAPI 3.0 specification.' -DefinitionTag 'potato'

	# Define the OpenAPI server endpoint
	Add-PodeOAServerEndpoint -url '/api' -Description 'default endpoint' -DefinitionTag 'potato'

	# External documentation link for OpenAPI
	$extDoc = New-PodeOAExternalDoc -Description 'Find out more about Swagger' -Url 'http://swagger.io'
	$extDoc | Add-PodeOAExternalDoc

	# Enable OpenAPI viewers
	Enable-PodeOAViewer -Type Swagger -Path '/docs/swagger' -Title 'Swagger' -DefinitionTag 'potato'
	Enable-PodeOAViewer -Bookmarks -Path '/docs' -Title 'Bookmark' -DefinitionTag 'potato'
	Enable-PodeOAViewer -Editor -Path '/docs/editor' -Title 'Editor' -DefinitionTag 'potato'

	# Select OpenAPI definition tag
	Select-PodeOADefinition -tag 'potato' -ScriptBlock {

		# Define routes within the '/api' group
		Add-PodeRouteGroup -Path '/api' -Routes {

			# JSON output route
			Add-PodeRoute -Method Get -Path '/v4.2/:potato' -ScriptBlock {
				Write-PodeJsonResponse -Value @{Potato = $WebEvent.Parameters['potato'] } -StatusCode 400
			} -Passthru | Set-PodeOARouteInfo -Summary 'Json output' -Description 'Returns JSON response' -OperationId 'json' -Passthru | `
					Set-PodeOARequest -PassThru -Parameters (
					New-PodeOAStringProperty -Name 'potato' -Description 'Potato Name' -Required |
						ConvertTo-PodeOAParameter -In Path -Required
					)

			# Plain text output route
			Add-PodeRoute -Method Get -Path '/:potato' -ScriptBlock {
				Write-PodeTextResponse -Value $WebEvent.Parameters['potato'] -StatusCode 200
			} -Passthru | Set-PodeOARouteInfo -Summary 'Text output' -Description 'Returns plain text response' -OperationId 'text' -Passthru | `
					Set-PodeOARequest -PassThru -Parameters (
					New-PodeOAStringProperty -Name 'potato' -Description 'Potato Name' -Required |
						ConvertTo-PodeOAParameter -In Path -Required
					)
		}
	}
}
