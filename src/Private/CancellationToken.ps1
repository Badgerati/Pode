
<#
.SYNOPSIS
    Resets the cancellation token for a specific type in Pode.
.DESCRIPTION
    The `Reset-PodeCancellationToken` function disposes of the existing cancellation token
    for the specified type and reinitializes it with a new token. This ensures proper cleanup
    of disposable resources associated with the cancellation token.
.PARAMETER Type
    The type of cancellation token to reset. This is a mandatory parameter and must be
    provided as a string.

.EXAMPLE
    # Reset the cancellation token for the 'Cancellation' type
    Reset-PodeCancellationToken -Type Cancellation

.EXAMPLE
    # Reset the cancellation token for the 'Restart' type
    Reset-PodeCancellationToken -Type Restart

.EXAMPLE
    # Reset the cancellation token for the 'Suspend' type
    Reset-PodeCancellationToken -Type Suspend

.NOTES
    This function is used to manage cancellation tokens in Pode's internal context.
#>
function Reset-PodeCancellationToken {
    param(
        [Parameter(Mandatory = $true)]
        [validateset( 'Cancellation' , 'Restart', 'Suspend', 'Resume', 'Terminate' )]
        [string[]]
        $Type
    )
    $type.ForEach({
            # Ensure cleanup of disposable tokens
            Close-PodeDisposable -Disposable $PodeContext.Tokens[$_]

            # Reinitialize the Token
            $PodeContext.Tokens[$_] = [System.Threading.CancellationTokenSource]::new()
        })
}


<#
.SYNOPSIS
	Closes specified cancellation tokens in the Pode context.

.DESCRIPTION
	The `Close-PodeCancellationToken` function ensures proper cleanup of disposable cancellation tokens
	within the `$PodeContext`. It takes one or more token types as input and disposes of the corresponding tokens.

	Supported token types include:
	- `Cancellation`
	- `Restart`
	- `Suspend`
	- `Resume`
	- `Terminate`

	This function is useful for managing and cleaning up resources during the lifecycle of a Pode application.

.PARAMETER Type
	Specifies the type(s) of cancellation tokens to close. Valid values are:
	`Cancellation`, `Restart`, `Suspend`, `Resume`, `Terminate`.

.EXAMPLE
	Close-PodeCancellationToken -Type 'Suspend'
	Closes the `Suspend` cancellation token in the Pode context.

.EXAMPLE
	Close-PodeCancellationToken -Type 'Restart', 'Terminate'
	Closes the `Restart` and `Terminate` cancellation tokens in the Pode context.

.NOTES
	This is an internal function and may change in future releases of Pode.
#>

function Close-PodeCancellationToken {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Cancellation', 'Restart', 'Suspend', 'Resume', 'Terminate')]
        [string[]]
        $Type
    )

    foreach ($tokenType in $Type) {
        # Ensure cleanup of disposable tokens
        Close-PodeDisposable -Disposable $PodeContext.Tokens[$tokenType]
    }
}




<#
.SYNOPSIS
	Waits for Pode suspension cancellation token to be reset.

.DESCRIPTION
	The `Test-PodeSuspensionToken` function checks the status of the suspension cancellation token within the `$PodeContext`.
	It enters a loop to wait for the `Suspend` cancellation token to be reset before proceeding.
	Each loop iteration includes a 1-second delay to minimize resource usage.
	The function returns a boolean indicating whether the suspension token was initially requested.

.EXAMPLE
	Test-PodeSuspensionToken
	Waits for the suspension token to be reset in the Pode context.

.OUTPUTS
	[bool]
	Indicates whether the suspension token was initially requested.

.NOTES
	This is an internal function and may change in future releases of Pode.
#>
function Test-PodeSuspensionToken {
    # Check if the Suspend token was initially requested
    $suspended = $PodeContext.Tokens.Suspend.IsCancellationRequested

    # Wait for the Suspend token to be reset
    while ($PodeContext.Tokens.Suspend.IsCancellationRequested) {
        Start-Sleep -Seconds 1
    }

    # Return whether the suspension token was initially requested
    return $suspended
}


<#
.SYNOPSIS
	Creates a set of cancellation tokens for managing Pode application states.

.DESCRIPTION
	The `New-PodeSuspensionToken` function initializes and returns a hashtable containing
	multiple cancellation tokens used for managing various states in a Pode application.
	These tokens enable coordinated control over application operations, such as cancellation,
	restart, suspension, resumption, and termination.

	The returned hashtable includes the following keys:
	- `Cancellation`: A token for general cancellation tasks.
	- `Restart`: A token for managing application restarts.
	- `Suspend`: A token for handling suspension operations.
	- `Resume`: A token for resuming operations after suspension.
	- `Terminate`: A token for managing application termination.

.EXAMPLE
	$tokens = New-PodeSuspensionToken
	Initializes a set of cancellation tokens and stores them in the `$tokens` variable.

.OUTPUTS
	[hashtable]
	A hashtable containing initialized cancellation tokens.

.NOTES
	This is an internal function and may change in future releases of Pode.
#>

function New-PodeSuspensionToken {
    return @{
        Cancellation = [System.Threading.CancellationTokenSource]::new()
        Restart      = [System.Threading.CancellationTokenSource]::new()
        Suspend      = [System.Threading.CancellationTokenSource]::new()
        Resume       = [System.Threading.CancellationTokenSource]::new()
        Terminate    = [System.Threading.CancellationTokenSource]::new()
    }
}