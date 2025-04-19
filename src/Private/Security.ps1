<#
.SYNOPSIS
    Retrieves the CSRF token from the current web request.

.DESCRIPTION
    This internal function attempts to extract the CSRF token from a Pode web request.
    It searches in the following order: request payload, query string, and headers.
    If the token is not found in any of these locations, it returns $null.

.OUTPUTS
    [string] The CSRF token value if found; otherwise, $null.

.NOTES
    Internal Pode function - subject to change without notice.
#>
function Get-PodeCsrfToken {
    # key name to search
    $key = $PodeContext.Server.Cookies.Csrf.Name

    # check the payload
    if (!(Test-PodeIsEmpty $WebEvent.Data[$key])) {
        return $WebEvent.Data[$key]
    }

    # check the query string
    if (!(Test-PodeIsEmpty $WebEvent.Query[$key])) {
        return $WebEvent.Query[$key]
    }

    # check the headers
    $value = (Get-PodeHeader -Name $key)
    if (!(Test-PodeIsEmpty $value)) {
        return $value
    }

    return $null
}

<#
.SYNOPSIS
    Validates a CSRF token against a secret.

.DESCRIPTION
    Verifies that a CSRF token is correctly structured and matches the expected value
    derived from the provided secret. The token must start with the prefix "t:", and
    contain a salt followed by a signature. If the token structure is invalid or
    does not match the expected token, the validation fails.

.PARAMETER Secret
    The secret key used to validate the CSRF token.

.PARAMETER Token
    The CSRF token to validate.

.OUTPUTS
    [bool] Returns $true if the token is valid; otherwise, $false.

.NOTES
    Internal Pode function - subject to change without notice.
#>
function Test-PodeCsrfToken {
    param(
        [Parameter()]
        [string]
        $Secret,

        [Parameter()]
        [string]
        $Token
    )

    # if there's no token/secret, fail
    if ((Test-PodeIsEmpty $Secret) -or (Test-PodeIsEmpty $Token)) {
        return $false
    }

    # the token must start with "t:"
    if (!$Token.StartsWith('t:')) {
        return $false
    }

    # get the salt from the token
    $_token = $Token.Substring(2)
    $periodIndex = $_token.LastIndexOf('.')
    if ($periodIndex -eq -1) {
        return $false
    }

    $salt = $_token.Substring(0, $periodIndex)

    # ensure the token is valid
    if ((Restore-PodeCsrfToken -Secret $Secret -Salt $salt) -ne $Token) {
        return $false
    }

    return $true
}

<#
.SYNOPSIS
    Generates and caches a new CSRF secret if one does not already exist.

.DESCRIPTION
    Checks for an existing CSRF secret in the current session or cookie context.
    If no secret is found, generates a new secure GUID and stores it in the appropriate location.

.OUTPUTS
    [string] The existing or newly created CSRF secret.

.NOTES
    Internal Pode function - subject to change without notice.
#>
function New-PodeCsrfSecret {
    # see if there's already a secret in session/cookie
    $secret = (Get-PodeCsrfSecret)
    if (!(Test-PodeIsEmpty $secret)) {
        return $secret
    }

    # otherwise, make a new secret and cache it
    $secret = (New-PodeGuid -Secure -Length 16)
    Set-PodeCsrfSecret -Secret $secret
    return $secret
}

<#
.SYNOPSIS
    Retrieves the current CSRF secret from the session or cookie.

.DESCRIPTION
    Returns the CSRF secret based on configuration. If CSRF is configured to use cookies,
    the secret is read from a cookie. Otherwise, it is retrieved from the session data.

.OUTPUTS
    [string] The CSRF secret if found; otherwise, $null.

.NOTES
    Internal Pode function - subject to change without notice.
#>
function Get-PodeCsrfSecret {
    # key name to get secret
    $key = $PodeContext.Server.Cookies.Csrf.Name

    # are we getting it from a cookie, or session?
    if ($PodeContext.Server.Cookies.Csrf.UseCookies) {
        $cookie = Get-PodeCookie `
            -Name $PodeContext.Server.Cookies.Csrf.Name `
            -Secret $PodeContext.Server.Cookies.Csrf.Secret
        return $cookie.Value
    }

    # on session
    else {
        return $WebEvent.Session.Data[$key]
    }
}

<#
.SYNOPSIS
    Stores the CSRF secret in the session or cookie.

.DESCRIPTION
    Based on configuration, this function sets the CSRF secret either as a cookie
    (with optional encryption) or directly in the session data.

.PARAMETER Secret
    The CSRF secret to store.

.OUTPUTS
    None.

.NOTES
    Internal Pode function - subject to change without notice.
#>
function Set-PodeCsrfSecret {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Secret
    )

    # key name to set secret under
    $key = $PodeContext.Server.Cookies.Csrf.Name

    # are we setting this on a cookie, or session?
    if ($PodeContext.Server.Cookies.Csrf.UseCookies) {
        $null = Set-PodeCookie `
            -Name $PodeContext.Server.Cookies.Csrf.Name `
            -Value $Secret `
            -Secret $PodeContext.Server.Cookies.Csrf.Secret
    }

    # on session
    else {
        $WebEvent.Session.Data[$key] = $Secret
    }
}

<#
.SYNOPSIS
    Reconstructs a CSRF token from a secret and a salt.

.DESCRIPTION
    Builds a CSRF token using the provided salt and secret by computing a SHA256 hash.
    The format of the returned token is: "t:<salt>.<hash>".

.PARAMETER Secret
    The secret key used in the token generation.

.PARAMETER Salt
    A unique salt string used to derive the token.

.OUTPUTS
    [string] The reconstructed CSRF token.

.NOTES
    Internal Pode function - subject to change without notice.
#>
function Restore-PodeCsrfToken {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Secret,

        [Parameter(Mandatory = $true)]
        [string]
        $Salt
    )

    return "t:$($Salt).$(Invoke-PodeSHA256Hash -Value "$($Salt)-$($Secret)")"
}

<#
.SYNOPSIS
    Checks if CSRF protection is configured.

.DESCRIPTION
    Returns $true if CSRF is enabled and configured within the server context;
    otherwise, returns $false.

.OUTPUTS
    [bool] Whether CSRF is configured.

.NOTES
    Internal Pode function - subject to change without notice.
#>
function Test-PodeCsrfConfigured {
    return (!(Test-PodeIsEmpty $PodeContext.Server.Cookies.Csrf))
}


function Protect-PodeContentSecurityKeyword {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter()]
        [string[]]
        $Value,

        [switch]
        $Append
    )

    # cache it
    if ($Append -and !(Test-PodeIsEmpty $PodeContext.Server.Security.Cache.ContentSecurity[$Name])) {
        $Value += @($PodeContext.Server.Security.Cache.ContentSecurity[$Name])
    }

    $PodeContext.Server.Security.Cache.ContentSecurity[$Name] = $Value

    # do nothing if no value
    if (($null -eq $Value) -or ($Value.Length -eq 0)) {
        return $null
    }

    # keywords
    $Name = $Name.ToLowerInvariant()

    $keywords = @(
        # standard keywords
        'none',
        'self',
        'strict-dynamic',
        'report-sample',
        'inline-speculation-rules',

        # unsafe keywords
        'unsafe-inline',
        'unsafe-eval',
        'unsafe-hashes',
        'wasm-unsafe-eval'
    )

    $schemes = @(
        'http',
        'https',
        'data',
        'blob',
        'filesystem',
        'mediastream',
        'ws',
        'wss',
        'ftp',
        'mailto',
        'tel',
        'file'
    )

    # build the value
    $values = @(foreach ($v in $Value) {
            if ($keywords -icontains $v) {
                "'$($v.ToLowerInvariant())'"
                continue
            }

            if ($schemes -icontains $v) {
                "$($v.ToLowerInvariant()):"
                continue
            }

            $v
        })

    return "$($Name) $($values -join ' ')"
}

function Protect-PodePermissionsPolicyKeyword {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter()]
        [string[]]
        $Value,

        [switch]
        $Append
    )

    # cache it
    if ($Append -and !(Test-PodeIsEmpty $PodeContext.Server.Security.Cache.PermissionsPolicy[$Name])) {
        if (($Value.Length -eq 0) -or (@($PodeContext.Server.Security.Cache.PermissionsPolicy[$Name])[0] -ine 'none')) {
            $Value += @($PodeContext.Server.Security.Cache.PermissionsPolicy[$Name])
        }
    }

    $PodeContext.Server.Security.Cache.PermissionsPolicy[$Name] = $Value

    # do nothing if no value
    if (($null -eq $Value) -or ($Value.Length -eq 0)) {
        return $null
    }

    # build value
    $Name = $Name.ToLowerInvariant()

    if ($Value -icontains 'none') {
        return "$($Name)=()"
    }

    $keywords = @(
        'self'
    )

    $values = @(foreach ($v in $Value) {
            if ($keywords -icontains $v) {
                $v
                continue
            }

            "`"$($v)`""
        })

    return "$($Name)=($($values -join ' '))"
}

<#
.SYNOPSIS
Sets the Content Security Policy (CSP) header for a Pode web server.

.DESCRIPTION
The `Set-PodeSecurityContentSecurityPolicyInternal` function constructs and sets the Content Security Policy (CSP) header based on the provided parameters. The function supports an optional switch to append the header value and explicitly disables XSS auditors in modern browsers to prevent vulnerabilities.

.PARAMETER Params
A hashtable containing the various CSP directives to be set.

.PARAMETER Append
A switch indicating whether to append the header value.

.EXAMPLE
$policyParams = @{
    Default = "'self'"
    ScriptSrc = "'self' 'unsafe-inline'"
    StyleSrc = "'self' 'unsafe-inline'"
}
Set-PodeSecurityContentSecurityPolicyInternal -Params $policyParams

.EXAMPLE
$policyParams = @{
    Default = "'self'"
    ImgSrc = "'self' data:"
    ConnectSrc = "'self' https://api.example.com"
    UpgradeInsecureRequests = $true
}
Set-PodeSecurityContentSecurityPolicyInternal -Params $policyParams -Append

.NOTES
This is an internal function and may change in future releases of Pode.
#>
function Set-PodeSecurityContentSecurityPolicyInternal {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSPossibleIncorrectComparisonWithNull', '')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]
        $Params,

        [Parameter()]
        [switch]
        $Append
    )

    # build the header's value
    $values = @(
        Protect-PodeContentSecurityKeyword -Name 'default-src' -Value $Params.Default -Append:$Append
        Protect-PodeContentSecurityKeyword -Name 'child-src' -Value $Params.Child -Append:$Append
        Protect-PodeContentSecurityKeyword -Name 'connect-src' -Value $Params.Connect -Append:$Append
        Protect-PodeContentSecurityKeyword -Name 'font-src' -Value $Params.Font -Append:$Append
        Protect-PodeContentSecurityKeyword -Name 'frame-src' -Value $Params.Frame -Append:$Append
        Protect-PodeContentSecurityKeyword -Name 'img-src' -Value $Params.Image -Append:$Append
        Protect-PodeContentSecurityKeyword -Name 'manifest-src' -Value $Params.Manifest -Append:$Append
        Protect-PodeContentSecurityKeyword -Name 'media-src' -Value $Params.Media -Append:$Append
        Protect-PodeContentSecurityKeyword -Name 'object-src' -Value $Params.Object -Append:$Append
        Protect-PodeContentSecurityKeyword -Name 'script-src' -Value $Params.Scripts -Append:$Append
        Protect-PodeContentSecurityKeyword -Name 'style-src' -Value $Params.Style -Append:$Append
        Protect-PodeContentSecurityKeyword -Name 'base-uri' -Value $Params.BaseUri -Append:$Append
        Protect-PodeContentSecurityKeyword -Name 'form-action' -Value $Params.FormAction -Append:$Append
        Protect-PodeContentSecurityKeyword -Name 'frame-ancestors' -Value $Params.FrameAncestor -Append:$Append
        Protect-PodeContentSecurityKeyword -Name 'fenched-frame-src' -Value $Params.FencedFrame -Append:$Append
        Protect-PodeContentSecurityKeyword -Name 'prefetch-src' -Value $Params.Prefetch -Append:$Append
        Protect-PodeContentSecurityKeyword -Name 'script-src-attr' -Value $Params.ScriptAttr -Append:$Append
        Protect-PodeContentSecurityKeyword -Name 'script-src-elem' -Value $Params.ScriptElem -Append:$Append
        Protect-PodeContentSecurityKeyword -Name 'style-src-attr' -Value $Params.StyleAttr -Append:$Append
        Protect-PodeContentSecurityKeyword -Name 'style-src-elem' -Value $Params.StyleElem -Append:$Append
        Protect-PodeContentSecurityKeyword -Name 'worker-src' -Value $Params.Worker -Append:$Append
    )

    # add "report-uri" if supplied
    if (![string]::IsNullOrWhiteSpace($Params.ReportUri)) {
        $values += "report-uri $($Params.ReportUri)".Trim()
    }

    if (![string]::IsNullOrWhiteSpace($Params.Sandbox) -and ($Params.Sandbox -ine 'None')) {
        $values += "sandbox $($Params.Sandbox.ToLowerInvariant())".Trim()
    }

    if ($Params.UpgradeInsecureRequests) {
        $values += 'upgrade-insecure-requests'
    }

    # Filter out $null values from the $values array using the array filter `-ne $null`. This approach
    # is equivalent to using `$values | Where-Object { $_ -ne $null }` but is more efficient. The `-ne $null`
    # operator is faster because it is a direct array operation that internally skips the overhead of
    # piping through a cmdlet and processing each item individually.
    $values = ($values -ne $null)
    $value = ($values -join '; ')

    # Add the Content Security Policy header to the response or relevant context. This cmdlet
    # sets the HTTP header with the name 'Content-Security-Policy' and the constructed value.
    # if ReportOnly is set, the header name is set to 'Content-Security-Policy-Report-Only'.
    $header = 'Content-Security-Policy'
    if ($Params.ReportOnly) {
        $header = 'Content-Security-Policy-Report-Only'
    }

    Add-PodeSecurityHeader -Name $header -Value $value

    # this is done to explicitly disable XSS auditors in modern browsers
    # as having it enabled has now been found to cause more vulnerabilities
    if ($Params.XssBlock) {
        Add-PodeSecurityHeader -Name 'X-XSS-Protection' -Value '1; mode=block'
    }
    else {
        Add-PodeSecurityHeader -Name 'X-XSS-Protection' -Value '0'
    }
}

<#
.SYNOPSIS
Sets the Permissions Policy header for a Pode web server.

.DESCRIPTION
The `Set-PodeSecurityPermissionsPolicy` function constructs and sets the Permissions Policy header based on the provided parameters. The function supports an optional switch to append the header value.

.PARAMETER Params
A hashtable containing the various permissions policies to be set.

.PARAMETER Append
A switch indicating whether to append the header value.

.EXAMPLE
$policyParams = @{
    Accelerometer = 'none'
    Camera = 'self'
    Microphone = '*'
}
Set-PodeSecurityPermissionsPolicy -Params $policyParams

.EXAMPLE
$policyParams = @{
    Autoplay = 'self'
    Geolocation = 'none'
}
Set-PodeSecurityPermissionsPolicy -Params $policyParams -Append

.NOTES
This is an internal function and may change in future releases of Pode.
#>
function Set-PodeSecurityPermissionsPolicyInternal {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSPossibleIncorrectComparisonWithNull', '')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]
        $Params,

        [Parameter()]
        [switch]
        $Append
    )

    # build the header's value
    $values = @(
        Protect-PodePermissionsPolicyKeyword -Name 'accelerometer' -Value $Params.Accelerometer -Append:$Append
        Protect-PodePermissionsPolicyKeyword -Name 'ambient-light-sensor' -Value $Params.AmbientLightSensor -Append:$Append
        Protect-PodePermissionsPolicyKeyword -Name 'autoplay' -Value $Params.Autoplay -Append:$Append
        Protect-PodePermissionsPolicyKeyword -Name 'battery' -Value $Params.Battery -Append:$Append
        Protect-PodePermissionsPolicyKeyword -Name 'camera' -Value $Params.Camera -Append:$Append
        Protect-PodePermissionsPolicyKeyword -Name 'display-capture' -Value $Params.DisplayCapture -Append:$Append
        Protect-PodePermissionsPolicyKeyword -Name 'document-domain' -Value $Params.DocumentDomain -Append:$Append
        Protect-PodePermissionsPolicyKeyword -Name 'encrypted-media' -Value $Params.EncryptedMedia -Append:$Append
        Protect-PodePermissionsPolicyKeyword -Name 'fullscreen' -Value $Params.Fullscreen -Append:$Append
        Protect-PodePermissionsPolicyKeyword -Name 'gamepad' -Value $Params.Gamepad -Append:$Append
        Protect-PodePermissionsPolicyKeyword -Name 'geolocation' -Value $Params.Geolocation -Append:$Append
        Protect-PodePermissionsPolicyKeyword -Name 'gyroscope' -Value $Params.Gyroscope -Append:$Append
        Protect-PodePermissionsPolicyKeyword -Name 'interest-cohort' -Value $Params.InterestCohort -Append:$Append
        Protect-PodePermissionsPolicyKeyword -Name 'layout-animations' -Value $Params.LayoutAnimations -Append:$Append
        Protect-PodePermissionsPolicyKeyword -Name 'legacy-image-formats' -Value $Params.LegacyImageFormats -Append:$Append
        Protect-PodePermissionsPolicyKeyword -Name 'magnetometer' -Value $Params.Magnetometer -Append:$Append
        Protect-PodePermissionsPolicyKeyword -Name 'microphone' -Value $Params.Microphone  -Append:$Append
        Protect-PodePermissionsPolicyKeyword -Name 'midi' -Value $Params.Midi  -Append:$Append
        Protect-PodePermissionsPolicyKeyword -Name 'oversized-images' -Value $Params.OversizedImages  -Append:$Append
        Protect-PodePermissionsPolicyKeyword -Name 'payment' -Value $Params.Payment -Append:$Append
        Protect-PodePermissionsPolicyKeyword -Name 'picture-in-picture' -Value $Params.PictureInPicture  -Append:$Append
        Protect-PodePermissionsPolicyKeyword -Name 'publickey-credentials-get' -Value $Params.PublicKeyCredentials  -Append:$Append
        Protect-PodePermissionsPolicyKeyword -Name 'speaker-selection' -Value $Params.Speakers  -Append:$Append
        Protect-PodePermissionsPolicyKeyword -Name 'sync-xhr' -Value $Params.SyncXhr -Append:$Append
        Protect-PodePermissionsPolicyKeyword -Name 'unoptimized-images' -Value $Params.UnoptimisedImages -Append:$Append
        Protect-PodePermissionsPolicyKeyword -Name 'unsized-media' -Value $Params.UnsizedMedia -Append:$Append
        Protect-PodePermissionsPolicyKeyword -Name 'usb' -Value $Params.Usb -Append:$Append
        Protect-PodePermissionsPolicyKeyword -Name 'screen-wake-lock' -Value $Params.ScreenWakeLake -Append:$Append
        Protect-PodePermissionsPolicyKeyword -Name 'web-share' -Value $Params.WebShare -Append:$Append
        Protect-PodePermissionsPolicyKeyword -Name 'xr-spatial-tracking' -Value $Params.XrSpatialTracking -Append:$Append
    )

    # Filter out $null values from the $values array using the array filter `-ne $null`. This approach
    # is equivalent to using `$values | Where-Object { $_ -ne $null }` but is more efficient. The `-ne $null`
    # operator is faster because it is a direct array operation that internally skips the overhead of
    # piping through a cmdlet and processing each item individually.
    $values = ($values -ne $null)
    $value = ($values -join ', ')

    # Add the constructed Permissions Policy header to the response or relevant context. This cmdlet
    # sets the HTTP header with the name 'Permissions-Policy' and the constructed value.
    Add-PodeSecurityHeader -Name 'Permissions-Policy' -Value $value
}