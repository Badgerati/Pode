
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
        [validateset( 'Cancellation' , 'Restart', 'Suspend', 'Resume', 'Terminate', 'Start', 'Disable' )]
        [string[]]
        $Type
    )
    foreach ($item in $type) {
        # Ensure cleanup of disposable tokens
        Close-PodeDisposable -Disposable $PodeContext.Tokens[$item]

        # Reinitialize the Token
        $PodeContext.Tokens[$item] = [System.Threading.CancellationTokenSource]::new()
    }
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
    - `Disable`

    This function is essential for managing resources during the lifecycle of a Pode application,
    especially when cleaning up during shutdown or restarting.

.PARAMETER Type
    Specifies the type(s) of cancellation tokens to close. Valid values are:
    `Cancellation`, `Restart`, `Suspend`, `Resume`, `Terminate`, `Start`,'Disable'.

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
        [ValidateSet('Cancellation', 'Restart', 'Suspend', 'Resume', 'Terminate', 'Start', 'Disable' )]
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
    The `Initialize-PodeCancellationToken` function initializes and returns a hashtable containing
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
    - `Disable`: A token for denying web access.

.EXAMPLE
    $tokens = Initialize-PodeCancellationToken
    Initializes a set of cancellation tokens and stores them in the `$tokens` variable.

.OUTPUTS
    [hashtable]
    A hashtable containing initialized cancellation tokens.

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function Initialize-PodeCancellationToken {
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

        # A cancellation token for denying any web request.
        Disable      = [System.Threading.CancellationTokenSource]::new()
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
    Close-PodeCancellationTokenRequest -Type Resume

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
    # Ensure the Suspend and Cancellation tokens is in a cancellation requested state
    Close-PodeCancellationTokenRequest -Type Suspend, Cancellation
}


<#
.SYNOPSIS
    Sets the cancellation token(s) for the specified Pode server actions.

.DESCRIPTION
    The `Close-PodeCancellationTokenRequest` function cancels one or more specified tokens within the Pode server.
    These tokens are used to manage the server's lifecycle actions, such as Restart, Suspend, Resume, or Terminate.
    The function takes a mandatory parameter `$Type`, which determines the token(s) to be canceled.
    Supported types include: `Cancellation`, `Restart`, `Suspend`, `Resume`, `Terminate`, `Start`, and `Disable`.

.PARAMETER Type
    Specifies the token(s) to be canceled. This parameter accepts one or more values from a predefined set.
    Allowed values: `Cancellation`, `Restart`, `Suspend`, `Resume`, `Terminate`, `Start`, `Disable`.

.EXAMPLE
    Close-PodeCancellationTokenRequest -Type 'Restart'

    Cancels the Restart token for the Pode server.

.EXAMPLE
    Close-PodeCancellationTokenRequest -Type 'Suspend','Terminate'

    Cancels both the Suspend and Terminate tokens for the Pode server.

.NOTES
    This function is an internal utility and may change in future releases of Pode.
#>
function Close-PodeCancellationTokenRequest {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Cancellation', 'Restart', 'Suspend', 'Resume', 'Terminate', 'Start', 'Disable')]
        [string[]]
        $Type
    )

    # Iterate over each provided type and cancel its corresponding token if not already canceled
    foreach ($item in $Type) {
        if ($PodeContext.Tokens.ContainsKey($item)) {
            if (! $PodeContext.Tokens[$item].IsCancellationRequested) {
                # Cancel the specified token
                $PodeContext.Tokens[$item].Cancel()
            }
        }
    }
}

<#
.SYNOPSIS
    Waits for a specific Pode server cancellation token to be reset.

.DESCRIPTION
    The `Wait-PodeCancellationTokenRequest` function continuously checks the status of a specified cancellation token
    in the Pode server context. It pauses execution in a loop until the token's cancellation request is cleared.

.PARAMETER Type
    Specifies the token to wait for. This parameter accepts one value from a predefined set.
    Allowed values: `Cancellation`, `Restart`, `Suspend`, `Resume`, `Terminate`, `Start`, `Disable`.

.EXAMPLE
    Wait-PodeCancellationTokenRequest -Type 'Restart'

    Waits until the Restart token is reset and no longer has a cancellation request.

.EXAMPLE
    Wait-PodeCancellationTokenRequest -Type 'Suspend'

    Waits for the Suspend token to be reset, pausing execution until the token is no longer in a cancellation state.

.NOTES
    - This function is part of Pode's internal utilities and may change in future releases.
    - It uses a simple loop with a 1-second sleep interval to reduce CPU usage while waiting.

#>
function Wait-PodeCancellationTokenRequest {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Cancellation', 'Restart', 'Suspend', 'Resume', 'Terminate', 'Start', 'Disable')]
        [string]
        $Type
    )

    # Wait for the token to be reset, with exponential back-off
    $count = 1
    while ($PodeContext.Tokens[$Type].IsCancellationRequested) {
        Start-Sleep -Milliseconds (100 * $count)
        $count = [System.Math]::Min($count + 1, 20)
    }
}

<#
.SYNOPSIS
    Evaluates whether a specified Pode server token has an active cancellation request.

.DESCRIPTION
    The `Test-PodeCancellationTokenRequest` function checks the cancellation state of a given token
    in the Pode server context. It determines whether the token has been marked for cancellation
    and optionally waits for the cancellation to occur if the `-Wait` parameter is specified.

.PARAMETER Type
    Specifies the token to check for an active cancellation request.
    Acceptable values include predefined token types in Pode:
    - `Cancellation`
    - `Restart`
    - `Suspend`
    - `Resume`
    - `Terminate`
    - `Start`
    - `Disable`

.PARAMETER Wait
    If specified, waits until the token's cancellation request becomes active before returning the result.

.OUTPUTS
    [bool] Returns `$true` if the specified token has an active cancellation request, otherwise `$false`.

.EXAMPLE
    Test-PodeCancellationTokenRequest -Type 'Restart'

    Checks if the Restart token has an active cancellation request and returns `$true` or `$false`.

.EXAMPLE
    Test-PodeCancellationTokenRequest -Type 'Suspend' -Wait

    Waits until the Suspend token has an active cancellation request before returning `$true` or `$false`.

.NOTES
    This function is an internal utility for Pode and may be subject to change in future releases.
#>
function Test-PodeCancellationTokenRequest {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Cancellation', 'Restart', 'Suspend', 'Resume', 'Terminate', 'Start', 'Disable')]
        [string]
        $Type,

        [switch]
        $Wait
    )

    # Check if the specified token has an active cancellation request
    $cancelled = $PodeContext.Tokens[$Type].IsCancellationRequested

    # If -Wait is specified, block until the token's cancellation request becomes active
    if ($Wait) {
        Wait-PodeCancellationTokenRequest -Type $Type
    }

    return $cancelled
}


<#
.SYNOPSIS
    Resolves cancellation token requests and executes corresponding server actions.

.DESCRIPTION
    This internal function evaluates cancellation token requests to handle actions
    such as restarting the server, enabling/disabling the server, or suspending/resuming
    its operations. It interacts with the Pode server's context and state to perform
    the necessary operations based on the allowed actions and current state.

.NOTES
    This is an internal function and may change in future releases of Pode.

.EXAMPLE
    Resolve-PodeCancellationToken
    Evaluates any pending cancellation token requests and applies the appropriate server actions.
#>

function Resolve-PodeCancellationToken {
    #Retrieve the current state of the Pode server
    $serverState = Get-PodeServerState
    if ($PodeContext.Server.AllowedActions.Restart -and (Test-PodeCancellationTokenRequest -Type Restart)) {
        Restart-PodeInternalServer
        return
    }

    # Handle enable/disable server actions
    if ($PodeContext.Server.AllowedActions.Disable -and ($ServerState -eq [Pode.PodeServerState]::Running)) {
        if (Test-PodeServerIsEnabled) {
            if (Test-PodeCancellationTokenRequest -Type Disable) {
                Disable-PodeServerInternal
                Show-PodeConsoleInfo -ShowTopSeparator
                return
            }
        }
        else {
            if (! (Test-PodeCancellationTokenRequest -Type Disable)) {
                Enable-PodeServerInternal
                Show-PodeConsoleInfo -ShowTopSeparator
                return
            }
        }
    }
    # Handle suspend/resume actions
    if ($PodeContext.Server.AllowedActions.Suspend) {
        if ((Test-PodeCancellationTokenRequest -Type Resume) -and ($ServerState -eq [Pode.PodeServerState]::Resuming)) {
            #    if ((Test-PodeCancellationTokenRequest -Type Resume) -and (($ServerState -eq [Pode.PodeServerState]::Suspended) -or ($ServerState -eq [Pode.PodeServerState]::Resuming))) {
            Resume-PodeServerInternal -Timeout $PodeContext.Server.AllowedActions.Timeout.Resume
            return
        }
        #elseif ((Test-PodeCancellationTokenRequest -Type Suspend) -and (($ServerState -eq [Pode.PodeServerState]::Running) -or ($ServerState -eq [Pode.PodeServerState]::Suspending))) {
        elseif ((Test-PodeCancellationTokenRequest -Type Suspend) -and ($ServerState -eq [Pode.PodeServerState]::Suspending)) {
            Suspend-PodeServerInternal -Timeout $PodeContext.Server.AllowedActions.Timeout.Suspend
            return
        }
    }
}
