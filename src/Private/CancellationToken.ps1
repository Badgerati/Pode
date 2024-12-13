
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
    - `Disable`: A token for denying web access.

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
    Set-PodeCancellationTokenRequest -Type Resume

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
    Set-PodeCancellationTokenRequest -Type Suspend, Cancellation
}


<#
.SYNOPSIS
    Sets the cancellation token(s) for the specified Pode server actions.

.DESCRIPTION
    The `Set-PodeCancellationTokenRequest` function cancels one or more specified tokens within the Pode server.
    These tokens are used to manage the server's lifecycle actions, such as Restart, Suspend, Resume, or Terminate.
    The function takes a mandatory parameter `$Type`, which determines the token(s) to be canceled.
    Supported types include: `Cancellation`, `Restart`, `Suspend`, `Resume`, `Terminate`, `Start`, and `Disable`.

.PARAMETER Type
    Specifies the token(s) to be canceled. This parameter accepts one or more values from a predefined set.
    Allowed values: `Cancellation`, `Restart`, `Suspend`, `Resume`, `Terminate`, `Start`, `Disable`.

.EXAMPLE
    Set-PodeCancellationTokenRequest -Type 'Restart'

    Cancels the Restart token for the Pode server.

.EXAMPLE
    Set-PodeCancellationTokenRequest -Type 'Suspend','Terminate'

    Cancels both the Suspend and Terminate tokens for the Pode server.

.NOTES
    This function is an internal utility and may change in future releases of Pode.
#>
function Set-PodeCancellationTokenRequest {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Cancellation', 'Restart', 'Suspend', 'Resume', 'Terminate', 'Start', 'Disable')]
        [string[]]
        $Type
    )

    # Iterate over each provided type and cancel its corresponding token if not already canceled
    $Type.ForEach({
            if ($PodeContext.Tokens.ContainsKey($_)) {
                if (!$PodeContext.Tokens[$_].IsCancellationRequested) {
                    # Cancel the specified token
                    $PodeContext.Tokens[$_].Cancel()
                }
            }
        })
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

    # Wait for the token to be reset
    while ($PodeContext.Tokens[$Type].IsCancellationRequested) {
        Start-Sleep -Seconds 1
    }
}



<#
.SYNOPSIS
    Tests whether specified Pode server tokens have active cancellation requests using logical operations.

.DESCRIPTION
    The `Test-PodeCancellationTokenRequest` function checks the cancellation state of one or more tokens
    within the Pode server context based on the specified logical operation (`AND`, `OR`, `XOR`, `NAND`, `NOR`, `XNOR`).
    - `AND` (default): Returns `$true` if all tokens have active cancellation requests.
    - `OR`: Returns `$true` if at least one token has an active cancellation request.
    - `XOR`: Returns `$true` if exactly one token has an active cancellation request.
    - `NAND`: Returns `$true` if not all tokens have active cancellation requests.
    - `NOR`: Returns `$true` if none of the tokens have active cancellation requests.
    - `XNOR`: Returns `$true` if an even number of tokens have active cancellation requests.

.PARAMETER Type
    Specifies the token(s) to check. This parameter accepts one or more values from a predefined set.
    Allowed values: `Cancellation`, `Restart`, `Suspend`, `Resume`, `Terminate`, `Start`, `Disable`.

.PARAMETER Operation
    Specifies the logical operation to apply when evaluating the token states.
    Allowed values: `AND`, `OR`, `XOR`, `NAND`, `NOR`, `XNOR`.
    Default is `AND`.

.OUTPUTS
    [bool] The result of the logical operation on the token cancellation states.

.EXAMPLE
    Test-PodeCancellationTokenRequest -Type 'Restart'

    Returns `$true` if the Restart token has an active cancellation request, otherwise `$false`.

.EXAMPLE
    Test-PodeCancellationTokenRequest -Type 'Suspend', 'Terminate' -Operation 'NAND'

    Returns `$true` if not all of Suspend and Terminate tokens have active cancellation requests.

.EXAMPLE
    Test-PodeCancellationTokenRequest -Type 'Suspend', 'Terminate'

    Defaults to `AND` operation. Returns `$true` if both Suspend and Terminate tokens have active cancellation requests.

.NOTES
    This function is part of Pode's internal utilities and may change in future releases.
#>
function Test-PodeCancellationTokenRequest {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Cancellation', 'Restart', 'Suspend', 'Resume', 'Terminate', 'Start', 'Disable')]
        [string[]]
        $Type,

        [Parameter()]
        [ValidateSet('AND', 'OR', 'XOR', 'NAND', 'NOR', 'XNOR')]
        [string]
        $Operation = 'AND'  # Default operation is AND
    )

    # Collect the state of each token
    $states = $Type | ForEach-Object {
        $PodeContext.Tokens[$_].IsCancellationRequested
    }

    # Evaluate based on the specified operation
    switch ($Operation) {
        'AND' {
            # Return true if all tokens have cancellation requests
            return ($states -notcontains $false)
        }
        'OR' {
            # Return true if at least one token has a cancellation request
            return ($states -contains $true)
        }
        'XOR' {
            # Return true if exactly one token has a cancellation request
            return ($states | Where-Object { $_ -eq $true }).Count -eq 1
        }
        'NAND' {
            # Return true if not all tokens have cancellation requests
            return ($states -contains $false)
        }
        'NOR' {
            # Return true if none of the tokens have cancellation requests
            return ($states -notcontains $true)
        }
        'XNOR' {
            # Return true if an even number of tokens have cancellation requests
            return (($states | Where-Object { $_ -eq $true }).Count % 2) -eq 0
        } 
    }
}

