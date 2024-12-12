
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
        [validateset( 'Cancellation' , 'Restart', 'Suspend', 'Resume', 'Terminate', 'Start' )]
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
    Closes and disposes of specified cancellation tokens in the Pode context.

.DESCRIPTION
    The `Close-PodeCancellationToken` function ensures proper cleanup of disposable cancellation tokens
    within the `$PodeContext`. It allows you to specify one or more token types to close and dispose of,
    or you can dispose of all tokens if no type is specified.

    Supported token types include:
    - `Cancellation`
    - `Restart`
    - `Suspend`
    - `Resume`
    - `Terminate`
    - `Start`

    This function is essential for managing resources during the lifecycle of a Pode application,
    especially when cleaning up during shutdown or restarting.

.PARAMETER Type
    Specifies the type(s) of cancellation tokens to close. Valid values are:
    `Cancellation`, `Restart`, `Suspend`, `Resume`, `Terminate`, `Start`.

    If this parameter is not specified, all tokens in `$PodeContext.Tokens` will be disposed of.

.EXAMPLE
    Close-PodeCancellationToken -Type 'Suspend'
    Closes and disposes of the `Suspend` cancellation token in the Pode context.

.EXAMPLE
    Close-PodeCancellationToken -Type 'Restart', 'Terminate'
    Closes and disposes of the `Restart` and `Terminate` cancellation tokens in the Pode context.

.EXAMPLE
    Close-PodeCancellationToken
    Closes and disposes of all tokens in the Pode context.

.NOTES
    This is an internal function and may change in future releases of Pode.

#>


function Close-PodeCancellationToken {
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateSet('Cancellation', 'Restart', 'Suspend', 'Resume', 'Terminate', 'Start' )]
        [string[]]
        $Type
    )
    if ($null -eq $Type) {
        $PodeContext.Tokens.Values | Close-PodeDisposable
    }
    else {
        foreach ($tokenType in $Type) {
            # Ensure cleanup of disposable tokens
            Close-PodeDisposable -Disposable $PodeContext.Tokens[$tokenType]
        }
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
    These tokens provide coordinated control over application operations, such as cancellation,
    restart, suspension, resumption, termination, and start operations.

    The returned hashtable includes the following keys:
    - `Cancellation`: A token specifically for managing endpoint cancellation tasks.
    - `Restart`: A token for managing application restarts.
    - `Suspend`: A token for handling suspension operations.
    - `Resume`: A token for resuming operations after suspension.
    - `Terminate`: A token for managing application termination.
    - `Start`: A token for monitoring application startup.

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
    # Initialize and return a hashtable containing various cancellation tokens.
    return @{
        # A cancellation token specifically for managing endpoint cancellation tasks.
        Cancellation = [System.Threading.CancellationTokenSource]::new()

        # A cancellation token specifically for managing application restart operations.
        Restart      = [System.Threading.CancellationTokenSource]::new()

        # A cancellation token for suspending operations in the Pode application.
        Suspend      = [System.Threading.CancellationTokenSource]::new()

        # A cancellation token for resuming operations after a suspension.
        Resume       = [System.Threading.CancellationTokenSource]::new()

        # A cancellation token for managing application termination.
        Terminate    = [System.Threading.CancellationTokenSource]::new()

        # A cancellation token for monitoring application startup.
        Start        = [System.Threading.CancellationTokenSource]::new()
    }
}



<#
.SYNOPSIS
    Waits for the Pode server to start by monitoring the cancellation token.

.DESCRIPTION
    This function repeatedly checks the `$PodeContext.Tokens.Start` cancellation token to determine if the Pode server has started.
    It pauses execution using `Start-Sleep` until the cancellation request is received.

.EXAMPLE
    Wait-PodeStartToken

    This example waits for the Pode server to start before proceeding with the rest of the script.

.NOTES
    This function is designed for internal use and may change in future releases of Pode.

.PARAMETER None
    This function does not take any parameters.

.OUTPUTS
    None

#>
function Wait-PodeStartToken {
    while ( !$PodeContext.Tokens.Start.IsCancellationRequested) {
        Start-Sleep 1
    }
}


<#
.SYNOPSIS
    Sets the Resume token for the Pode server to resume its operation from a suspended state.

.DESCRIPTION
    The Set-PodeResumeToken function ensures that the Resume token's cancellation is requested to signal that the server should
    resume its operation. Additionally, it resets other related tokens, such as Cancellation and Suspend, if they are in a requested state.
    This function prevents conflicts between tokens and ensures proper state management in the Pode server.

.NOTES
    This is an internal function and may change in future releases of Pode.

.EXAMPLE
    Set-PodeResumeToken

    Signals the Pode server to resume operations and resets relevant tokens.
#>
function Set-PodeResumeToken {

    # Ensure the Resume token is in a cancellation requested state
    if (!$PodeContext.Tokens.Resume.IsCancellationRequested) {
        $PodeContext.Tokens.Resume.Cancel()
    }

    # If the Cancellation token is in a requested state, reset it (unexpected scenario)
    if ($PodeContext.Tokens.Cancellation.IsCancellationRequested) {
        Reset-PodeCancellationToken -Type Cancellation
    }

    # Reset the Suspend token if it is in a cancellation requested state
    if ($PodeContext.Tokens.Suspend.IsCancellationRequested) {
        Reset-PodeCancellationToken -Type Suspend
    }
}

<#
.SYNOPSIS
    Sets the Restart token for the Pode server to initiate a restart.

.DESCRIPTION
    The Set-PodeRestartToken function ensures that the Restart token's cancellation is requested to signal that the server should
    initiate a restart. This function is a key part of managing the Pode server lifecycle and ensures proper state signaling.

.NOTES

    This is an internal function and may change in future releases of Pode.

.EXAMPLE
    Set-PodeRestartToken

    Signals the Pode server to initiate a restart by setting the Restart token.
#>
function Set-PodeRestartToken {
    # Ensure the Restart token is in a cancellation requested state
    if (!$PodeContext.Tokens.Restart.IsCancellationRequested) {
        $PodeContext.Tokens.Restart.Cancel()
    }
}


<#
.SYNOPSIS
    Sets the Suspend token for the Pode server to transition into a suspended state.

.DESCRIPTION
    The Set-PodeSuspendToken function ensures that the Suspend token's cancellation is requested to signal that the server should
    transition into a suspended state. Additionally, it sets the Cancellation token to prevent further operations while the server
    is suspended.

.NOTES
    This is an internal function and may change in future releases of Pode.

.EXAMPLE
    Set-PodeSuspendToken

    Signals the Pode server to transition into a suspended state by setting the Suspend token and the Cancellation token.
#>
function Set-PodeSuspendToken {
    # Ensure the Suspend token is in a cancellation requested state
    if (!$PodeContext.Tokens.Suspend.IsCancellationRequested) {
        $PodeContext.Tokens.Suspend.Cancel()
    }

    # Ensure the Cancellation token is in a cancellation requested state
    if (!$PodeContext.Tokens.Cancellation.IsCancellationRequested) {
        $PodeContext.Tokens.Cancellation.Cancel()
    }
}


