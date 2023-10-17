function Get-PodeAccessMiddlewareScript {
    return {
        param($opts)

        if ($null -eq $WebEvent.Auth) {
            Set-PodeResponseStatus -Code 403
            return $false
        }

        # test access
        $WebEvent.Auth.IsAuthorised = Invoke-PodeAccessValidation -Name $opts.Name

        # 403 if unauthorised
        if (!$WebEvent.Auth.IsAuthorised) {
            Set-PodeResponseStatus -Code 403
        }

        # run next middleware or stop?
        return $WebEvent.Auth.IsAuthorised
    }
}

function Invoke-PodeAccessValidation {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    # get the access method
    $access = $PodeContext.Server.Authorisations.Methods[$Name]

    # if it's a merged access, re-call this function and check against "succeed" value
    if ($access.Merged) {
        foreach ($accName in $access.Access) {
            $result = Invoke-PodeAccessValidation -Name $accName

            # if the access passed, and we only need one access to pass, return true
            if ($result -and $access.PassOne) {
                return $true
            }

            # if the access failed, but we need all to pass, return false
            if (!$result -and !$access.PassOne) {
                return $false
            }
        }

        # if the last access failed, and we only need one access to pass, return false
        if (!$result -and $access.PassOne) {
            return $false
        }

        # if the last access succeeded, and we need all to pass, return true
        if ($result -and !$access.PassOne) {
            return $true
        }

        # default failure
        return $false
    }

    # main access validation logic
    return (Test-PodeAccessRoute -Name $Name)
}