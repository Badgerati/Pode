<#
.SYNOPSIS
Adds a Verb for a TCP data.

.DESCRIPTION
Adds a Verb for a TCP data.

.PARAMETER Verb
The Verb for the Verb.

.PARAMETER ScriptBlock
A ScriptBlock for the Verb's main logic.

.PARAMETER EndpointName
The EndpointName of an Endpoint(s) this Verb should be bound against.

.PARAMETER FilePath
A literal, or relative, path to a file containing a ScriptBlock for the Verb's main logic.

.PARAMETER ArgumentList
An array of arguments to supply to the Verb's ScriptBlock.

.PARAMETER UpgradeToSsl
If supplied, the Verb will auto-upgrade the connection to use SSL.

.PARAMETER Close
If supplied, the Verb will auto-close the connection.

.EXAMPLE
Add-PodeVerb -Verb 'Hello' -ScriptBlock { /* logic */ }

.EXAMPLE
Add-PodeVerb -Verb 'Hello' -ScriptBlock { /* logic */ } -ArgumentList 'arg1', 'arg2'

.EXAMPLE
Add-PodeVerb -Verb 'Quit' -Close

.EXAMPLE
Add-PodeVerb -Verb 'StartTls' -UpgradeToSsl
#>
function Add-PodeVerb {
    [CmdletBinding(DefaultParameterSetName = 'Script')]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Verb,

        [Parameter(ParameterSetName = 'Script')]
        [scriptblock]
        $ScriptBlock,

        [Parameter(Mandatory = $true, ParameterSetName = 'File')]
        [string]
        $FilePath,

        [Parameter()]
        [object[]]
        $ArgumentList,

        [Parameter()]
        [string[]]
        $EndpointName,

        [switch]
        $UpgradeToSsl,

        [switch]
        $Close
    )

    # Record the operation on the main log
    Write-PodeMainLog -Operation $MyInvocation.MyCommand.Name -Parameters $PSBoundParameters

    # find placeholder parameters in verb (ie: COMMAND :parameter)
    $Verb = Resolve-PodePlaceholder -Path $Verb

    # get endpoints from name
    $endpoints = Find-PodeEndpoint -EndpointName $EndpointName

    # ensure the verb doesn't already exist for each endpoint
    foreach ($_endpoint in $endpoints) {
        Test-PodeVerbAndError -Verb $Verb -Protocol $_endpoint.Protocol -Address $_endpoint.Address
    }

    # if scriptblock and file path are all null/empty, error
    if ((Test-PodeIsEmpty $ScriptBlock) -and (Test-PodeIsEmpty $FilePath) -and !$Close -and !$UpgradeToSsl) {
        throw "[Verb] $($Verb): No logic passed"
    }

    # if we have a file path supplied, load that path as a scriptblock
    if ($PSCmdlet.ParameterSetName -ieq 'file') {
        $ScriptBlock = Convert-PodeFileToScriptBlock -FilePath $FilePath
    }

    # check for scoped vars
    $ScriptBlock, $usingVars = Convert-PodeScopedVariables -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState

    # add the verb(s)
    Write-Verbose "Adding Verb: $($Verb)"
    $PodeContext.Server.Verbs[$Verb] += @(foreach ($_endpoint in $endpoints) {
            @{
                Logic          = $ScriptBlock
                UsingVariables = $usingVars
                Endpoint       = @{
                    Protocol = $_endpoint.Protocol
                    Address  = $_endpoint.Address.Trim()
                    Name     = $_endpoint.Name
                }
                Arguments      = $ArgumentList
                Verb           = $Verb
                Connection     = @{
                    UpgradeToSsl = $UpgradeToSsl
                    Close        = $Close
                }
            }
        })
}

<#
.SYNOPSIS
Remove a specific Verb.

.DESCRIPTION
Remove a specific Verb.

.PARAMETER Verb
The Verb of the Verb to remove.

.PARAMETER EndpointName
The EndpointName of an Endpoint(s) bound to the Verb to be removed.

.EXAMPLE
Remove-PodeVerb -Verb 'Hello'

.EXAMPLE
Remove-PodeVerb -Verb 'Hello :username' -EndpointName User
#>
function Remove-PodeVerb {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Verb,

        [Parameter()]
        [string]
        $EndpointName
    )

    # Record the operation on the main log
    Write-PodeMainLog -Operation $MyInvocation.MyCommand.Name -Parameters $PSBoundParameters

    # ensure the verb placeholders are replaced
    $Verb = Resolve-PodePlaceholder -Path $Verb

    # ensure verb does exist
    if (!$PodeContext.Server.Verbs.Contains($Verb)) {
        return
    }

    # remove the verb's logic
    $PodeContext.Server.Verbs[$Verb] = @($PodeContext.Server.Verbs[$Verb] | Where-Object {
            $_.Endpoint.Name -ine $EndpointName
        })

    # if the verb has no more logic, just remove it
    if ((Get-PodeCount $PodeContext.Server.Verbs[$Verb]) -eq 0) {
        $null = $PodeContext.Server.Verbs.Remove($Verb)
    }
}

<#
.SYNOPSIS
Removes all added Verbs.

.DESCRIPTION
Removes all added Verbs.

.EXAMPLE
Clear-PodeVerbs
#>
function Clear-PodeVerbs {
    [CmdletBinding()]
    param()

    # Record the operation on the main log
    Write-PodeMainLog -Operation $MyInvocation.MyCommand.Name -Parameters $PSBoundParameters

    $PodeContext.Server.Verbs.Clear()
}

<#
.SYNOPSIS
Get a Verb(s).

.DESCRIPTION
Get a Verb(s).

.PARAMETER Verb
A Verb to filter the verbs.

.PARAMETER EndpointName
The name of an endpoint to filter verbs.

.EXAMPLE
Get-PodeVerb -Verb 'Hello'

.EXAMPLE
Get-PodeVerb -Verb 'Hello :username' -EndpointName User
#>
function Get-PodeVerb {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Verb,

        [Parameter()]
        [string[]]
        $EndpointName
    )

    # start off with every verb
    $verbs = @()

    # if we have a verb, filter
    if (![string]::IsNullOrWhiteSpace($Verb)) {
        $Verb = Resolve-PodePlaceholder -Path $Verb
        $verbs = $PodeContext.Server.Verbs[$Verb]
    }
    else {
        foreach ($v in $PodeContext.Server.Verbs.Values) {
            $verbs += $v
        }
    }

    # further filter by endpoint names
    if (($null -ne $EndpointName) -and ($EndpointName.Length -gt 0)) {
        $verbs = @(foreach ($name in $EndpointName) {
                foreach ($v in $verbs) {
                    if ($v.Endpoint.Name -ine $name) {
                        continue
                    }

                    $v
                }
            })
    }

    # return
    return $verbs
}

<#
.SYNOPSIS
Automatically loads verb ps1 files

.DESCRIPTION
Automatically loads verb ps1 files from either a /verbs folder, or a custom folder. Saves space dot-sourcing them all one-by-one.

.PARAMETER Path
Optional Path to a folder containing ps1 files, can be relative or literal.

.EXAMPLE
Use-PodeVerbs

.EXAMPLE
Use-PodeVerbs -Path './my-verbs'
#>
function Use-PodeVerbs {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Path
    )

    Use-PodeFolder -Path $Path -DefaultPath 'verbs'
}