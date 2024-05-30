function Find-PodeVerb {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Verb,

        [Parameter()]
        [string]
        $EndpointName
    )

    # if we have a perfect match for the verb, return it
    $found = Get-PodeVerbByLiteral -Verbs $PodeContext.Server.Verbs[$Verb] -EndpointName $EndpointName
    if ($null -ne $found) {
        return $found
    }

    # otherwise, match regex on the verbs (first match only)
    $valid = @(foreach ($key in $PodeContext.Server.Verbs.Keys) {
            if (($key -ine '*') -and ($Verb -imatch "^$($key)$")) {
                $key
                break
            }
        })[0]

    if ($null -eq $valid) {
        return $null
    }

    # is the verb valid for any protocols/endpoints?
    $found = Get-PodeVerbByLiteral -Verbs $PodeContext.Server.Verbs[$valid] -EndpointName $EndpointName
    if ($null -eq $found) {
        return $null
    }

    return $found
}

function Get-PodeVerbByLiteral {
    param(
        [Parameter()]
        [hashtable[]]
        $Verbs,

        [Parameter()]
        [string]
        $EndpointName
    )

    # if verbs is already null/empty just return
    if (($null -eq $Verbs) -or ($Verbs.Length -eq 0)) {
        return $null
    }

    # get the verb
    return (Get-PodeVerbsByLiteral -Verbs $Verbs -EndpointName $EndpointName)
}

function Get-PodeVerbsByLiteral {
    param(
        [Parameter()]
        [hashtable[]]
        $Verbs,

        [Parameter()]
        [string]
        $EndpointName
    )

    # see if a verb has the endpoint name
    if (![string]::IsNullOrWhiteSpace($EndpointName)) {
        foreach ($verb in $Verbs) {
            if ($verb.Endpoint.Name -ieq $EndpointName) {
                return $verb
            }
        }
    }

    # else find first default verb
    foreach ($verb in $Verbs) {
        if ([string]::IsNullOrWhiteSpace($verb.Endpoint.Name)) {
            return $verb
        }
    }

    return $null
}

function Test-PodeVerbAndError {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Verb,

        [Parameter()]
        [string]
        $Protocol,

        [Parameter()]
        [string]
        $Address
    )

    $found = @($PodeContext.Server.Verbs[$Verb])

    if (($found | Where-Object { ($_.Endpoint.Protocol -ieq $Protocol) -and ($_.Endpoint.Address -ieq $Address) } | Measure-Object).Count -eq 0) {
        return
    }

    $_url = $Protocol
    if (![string]::IsNullOrEmpty($_url) -and ![string]::IsNullOrWhiteSpace($Address)) {
        $_url = "$($_url)://$($Address)"
    }
    elseif (![string]::IsNullOrWhiteSpace($Address)) {
        $_url = $Address
    }

    if ([string]::IsNullOrEmpty($_url)) {
        throw ($msgTable.verbAlreadyDefinedExceptionMessage -f $Verb) #"[Verb] $($Verb): Already defined"
    }
    else {
        throw ($msgTable.verbAlreadyDefinedForUrlExceptionMessage -f $Verb, $_url) # "[Verb] $($Verb): Already defined for $($_url)"
    }
}