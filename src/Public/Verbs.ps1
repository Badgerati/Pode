function Add-PodeVerb
{
    [CmdletBinding(DefaultParameterSetName='Script')]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Verb,

        [Parameter(ParameterSetName='Script')]
        [scriptblock]
        $ScriptBlock,

        [Parameter(Mandatory=$true, ParameterSetName='File')]
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

    # find placeholder parameters in verb (ie: COMMAND :parameter)
    $Verb = Update-PodeRoutePlaceholders -Path $Verb

    # get endpoints from name
    if (!$PodeContext.Server.FindEndpoints.Tcp) {
        $PodeContext.Server.FindEndpoints.Tcp = !(Test-PodeIsEmpty $EndpointName)
    }

    $endpoints = Find-PodeEndpoints -EndpointName $EndpointName

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

    # check if the scriptblock has any using vars
    $ScriptBlock, $usingVars = Invoke-PodeUsingScriptConversion -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState

    # check for state/session vars
    $ScriptBlock = Invoke-PodeStateScriptConversion -ScriptBlock $ScriptBlock
    $ScriptBlock = Invoke-PodeSessionScriptConversion -ScriptBlock $ScriptBlock

    # add the verb(s)
    Write-Verbose "Adding Verb: $($Verb)"
    $PodeContext.Server.Verbs[$Verb] += @(foreach ($_endpoint in $endpoints) {
        @{
            Logic = $ScriptBlock
            UsingVariables = $usingVars
            Endpoint = @{
                Protocol = $_endpoint.Protocol
                Address = $_endpoint.Address.Trim()
                Name = $_endpoint.Name
            }
            Arguments = $ArgumentList
            Verb = $Verb
            Connection = @{
                UpgradeToSsl = $UpgradeToSsl
                Close = $Close
            }
        }
    })
}

function Remove-PodeVerb
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Verb,

        [Parameter()]
        [string]
        $EndpointName
    )

    # ensure the verb placeholders are replaced
    $Verb = Update-PodeRoutePlaceholders -Path $Verb

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

function Clear-PodeVerbs
{
    [CmdletBinding()]
    param()

    $PodeContext.Server.Verbs.Clear()
}

function Get-PodeVerb
{
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
        $Verb = Update-PodeRoutePlaceholders -Path $Verb
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

function Use-PodeVerbs
{
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Path
    )

    Use-PodeFolder -Path $Path -DefaultPath 'verbs'
}