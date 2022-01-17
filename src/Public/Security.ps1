function Set-PodeSecurity
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('Simple', 'Strict')]
        [string]
        $Type
    )

    # general headers
    Set-PodeSecurityContentTypeOptions

    Set-PodeSecurityPermissionPolicy `
        -LayoutAnimations 'none' `
        -UnoptimisedImages 'none' `
        -OversizedImages 'none' `
        -SyncXhr 'none' `
        -UnsizedMedia 'none'

    Set-PodeSecurityCrossOrigin -Embed Require-Corp -Open Same-Origin -Resource Same-Origin
    Set-PodeSecurityAccessControl -Origin '*' -Methods '*' -Headers '*' -Duration 7200

    # type specific headers
    switch ($Type.ToLowerInvariant()) {
        'simple' {
            Set-PodeSecurityFrameOptions -Type SameOrigin
            Set-PodeSecurityReferrerPolicy -Type Strict-Origin
            Set-PodeSecurityContentSecurityPolicy -Default 'self' -Style 'self', 'unsafe-inline' -Scripts 'self', 'unsafe-inline' -Image 'self', 'data'
        }

        'strict' {
            Set-PodeSecurityFrameOptions -Type Deny
            Set-PodeSecurityReferrerPolicy -Type No-Referrer
            Set-PodeSecurityStrictTransportSecurity -Duration 31536000 -IncludeSubDomains
            Set-PodeSecurityContentSecurityPolicy -Default 'self' -Image 'self', 'data'
        }
    }
}

function Remove-PodeSecurity
{
    [CmdletBinding()]
    param()

    $PodeContext.Server.Security.Headers.Clear()
}

function Add-PodeSecurityHeader
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Name,

        [Parameter()]
        [string]
        $Value
    )

    if (![string]::IsNullOrWhiteSpace($Value)) {
        $PodeContext.Server.Security.Headers[$Name] = $Value
    }
}

function Remove-PodeSecurityHeader
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Name
    )

    $PodeContext.Server.Security.Headers.Remove($Name)
}

function Set-PodeSecurityFrameOptions
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('Deny', 'SameOrigin')]
        [string]
        $Type
    )

    Add-PodeSecurityHeader -Name 'X-Frame-Options' -Value $Type.ToUpperInvariant()
}

function Remove-PodeSecurityFrameOptions
{
    [CmdletBinding()]
    param()

    Remove-PodeSecurityHeader -Name 'X-Frame-Options'
}

function Set-PodeSecurityContentSecurityPolicy
{
    [CmdletBinding()]
    param(
        [Parameter()]
        [string[]]
        $Default,

        [Parameter()]
        [string[]]
        $Child,

        [Parameter()]
        [string[]]
        $Connect,

        [Parameter()]
        [string[]]
        $Font,

        [Parameter()]
        [string[]]
        $Frame,

        [Parameter()]
        [string[]]
        $Image,

        [Parameter()]
        [string[]]
        $Manifest,

        [Parameter()]
        [string[]]
        $Media,

        [Parameter()]
        [string[]]
        $Object,

        [Parameter()]
        [string[]]
        $Scripts,

        [Parameter()]
        [string[]]
        $Style,

        [Parameter()]
        [string[]]
        $BaseUri,

        [Parameter()]
        [string[]]
        $FormAction,

        [Parameter()]
        [string[]]
        $FrameAncestor,

        [Parameter()]
        [ValidateSet('', 'Allow-Downloads', 'Allow-Downloads-Without-User-Activation', 'Allow-Forms', 'Allow-Modals', 'Allow-Orientation-Lock',
            'Allow-Pointer-Lock', 'Allow-Popups', 'Allow-Popups-To-Escape-Sandbox', 'Allow-Presentation', 'Allow-Same-Origin', 'Allow-Scripts',
            'Allow-Storage-Access-By-User-Activation', 'Allow-Top-Navigation', 'Allow-Top-Navigation-By-User-Activation', 'None')]
        [string]
        $Sandbox = 'None',

        [switch]
        $UpgradeInsecureRequests
    )

    # build the header's value
    $values = @(
        Protect-PodeContentSecurityKeyword -Name 'default-src' -Value $Default
        Protect-PodeContentSecurityKeyword -Name 'child-src' -Value $Child
        Protect-PodeContentSecurityKeyword -Name 'connect-src' -Value $Connect
        Protect-PodeContentSecurityKeyword -Name 'font-src' -Value $Font
        Protect-PodeContentSecurityKeyword -Name 'frame-src' -Value $Frame
        Protect-PodeContentSecurityKeyword -Name 'img-src' -Value $Image
        Protect-PodeContentSecurityKeyword -Name 'manifest-src' -Value $Manifest
        Protect-PodeContentSecurityKeyword -Name 'media-src' -Value $Media
        Protect-PodeContentSecurityKeyword -Name 'object-src' -Value $Object
        Protect-PodeContentSecurityKeyword -Name 'script-src' -Value $Scripts
        Protect-PodeContentSecurityKeyword -Name 'style-src' -Value $Style
        Protect-PodeContentSecurityKeyword -Name 'base-uri' -Value $BaseUri
        Protect-PodeContentSecurityKeyword -Name 'form-action' -Value $FormAction
        Protect-PodeContentSecurityKeyword -Name 'frame-ancestors' -Value $FrameAncestor
    )

    if ($Sandbox -ine 'None') {
        $values += "sandbox $($Sandbox.ToLowerInvariant())".Trim()
    }

    if ($UpgradeInsecureRequests) {
        $values += 'upgrade-insecure-requests'
    }

    $values = ($values -ne $null)
    $value = ($values -join '; ')

    # add the header
    Add-PodeSecurityHeader -Name 'Content-Security-Policy' -Value $value

    # this is done to explicitly disable XSS auditors in browsers
    # as having it enabled has now been found to cause more vulnerabilities
    Add-PodeSecurityHeader -Name 'X-XSS-Protection' -Value "0"
}

function Remove-PodeSecurityContentSecurityPolicy
{
    [CmdletBinding()]
    param()

    Remove-PodeSecurityHeader -Name 'Content-Security-Policy'
    Remove-PodeSecurityHeader -Name 'X-XSS-Protection'
}

function Set-PodeSecurityPermissionPolicy
{
    [CmdletBinding()]
    param(
        [Parameter()]
        [string[]]
        $Accelerometer,

        [Parameter()]
        [string[]]
        $AmbientLightSensor,

        [Parameter()]
        [string[]]
        $Autoplay,

        [Parameter()]
        [string[]]
        $Battery,

        [Parameter()]
        [string[]]
        $Camera,

        [Parameter()]
        [string[]]
        $DisplayCapture,

        [Parameter()]
        [string[]]
        $DocumentDomain,

        [Parameter()]
        [string[]]
        $EncryptedMedia,

        [Parameter()]
        [string[]]
        $Fullscreen,

        [Parameter()]
        [string[]]
        $Gamepad,

        [Parameter()]
        [string[]]
        $Geolocation,

        [Parameter()]
        [string[]]
        $Gyroscope,

        [Parameter()]
        [string[]]
        $LayoutAnimations,

        [Parameter()]
        [string[]]
        $LegacyImageFormats,

        [Parameter()]
        [string[]]
        $Magnetometer,

        [Parameter()]
        [string[]]
        $Microphone,

        [Parameter()]
        [string[]]
        $Midi,

        [Parameter()]
        [string[]]
        $OversizedImages,

        [Parameter()]
        [string[]]
        $Payment,

        [Parameter()]
        [string[]]
        $PictureInPicture,

        [Parameter()]
        [string[]]
        $PublicKeyCredentials,

        [Parameter()]
        [string[]]
        $Speakers,

        [Parameter()]
        [string[]]
        $SyncXhr,

        [Parameter()]
        [string[]]
        $UnoptimisedImages,

        [Parameter()]
        [string[]]
        $UnsizedMedia,

        [Parameter()]
        [string[]]
        $Usb,

        [Parameter()]
        [string[]]
        $ScreenWakeLake,

        [Parameter()]
        [string[]]
        $WebShare,

        [Parameter()]
        [string[]]
        $XrSpatialTracking
    )

    # build the header's value
    $values = @(
        Protect-PodePermissionPolicyKeyword -Name 'accelerometer' -Value $Accelerometer
        Protect-PodePermissionPolicyKeyword -Name 'ambient-light-sensor' -Value $AmbientLightSensor
        Protect-PodePermissionPolicyKeyword -Name 'autoplay' -Value $Autoplay
        Protect-PodePermissionPolicyKeyword -Name 'battery' -Value $Battery
        Protect-PodePermissionPolicyKeyword -Name 'camera' -Value $Camera
        Protect-PodePermissionPolicyKeyword -Name 'display-capture' -Value $DisplayCapture
        Protect-PodePermissionPolicyKeyword -Name 'document-domain' -Value $DocumentDomain
        Protect-PodePermissionPolicyKeyword -Name 'encrypted-media' -Value $EncryptedMedia
        Protect-PodePermissionPolicyKeyword -Name 'fullscreen' -Value $Fullscreen
        Protect-PodePermissionPolicyKeyword -Name 'gamepad' -Value $Gamepad
        Protect-PodePermissionPolicyKeyword -Name 'geolocation' -Value $Geolocation
        Protect-PodePermissionPolicyKeyword -Name 'gyroscope' -Value $Gyroscope
        Protect-PodePermissionPolicyKeyword -Name 'layout-animations' -Value $LayoutAnimations
        Protect-PodePermissionPolicyKeyword -Name 'legacy-image-formats' -Value $LegacyImageFormats
        Protect-PodePermissionPolicyKeyword -Name 'magnetometer' -Value $Magnetometer
        Protect-PodePermissionPolicyKeyword -Name 'microphone' -Value $Microphone
        Protect-PodePermissionPolicyKeyword -Name 'midi' -Value $Midi
        Protect-PodePermissionPolicyKeyword -Name 'oversized-images' -Value $OversizedImages
        Protect-PodePermissionPolicyKeyword -Name 'payment' -Value $Payment
        Protect-PodePermissionPolicyKeyword -Name 'picture-in-picture' -Value $PictureInPicture
        Protect-PodePermissionPolicyKeyword -Name 'publickey-credentials-get' -Value $PublicKeyCredentials
        Protect-PodePermissionPolicyKeyword -Name 'speaker-selection' -Value $Speakers
        Protect-PodePermissionPolicyKeyword -Name 'sync-xhr' -Value $SyncXhr
        Protect-PodePermissionPolicyKeyword -Name 'unoptimized-images' -Value $UnoptimisedImages
        Protect-PodePermissionPolicyKeyword -Name 'unsized-media' -Value $UnsizedMedia
        Protect-PodePermissionPolicyKeyword -Name 'usb' -Value $Usb
        Protect-PodePermissionPolicyKeyword -Name 'screen-wake-lock' -Value $ScreenWakeLake
        Protect-PodePermissionPolicyKeyword -Name 'web-share' -Value $WebShare
        Protect-PodePermissionPolicyKeyword -Name 'xr-spatial-tracking' -Value $XrSpatialTracking
    )

    $values = ($values -ne $null)
    $value = ($values -join ', ')

    # add the header
    Add-PodeSecurityHeader -Name 'Permission-Policy' -Value $value
}

function Remove-PodeSecurityPermissionPolicy
{
    [CmdletBinding()]
    param()

    Remove-PodeSecurityHeader -Name 'Permission-Policy'
}

function Set-PodeSecurityReferrerPolicy
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('No-Referrer', 'No-Referrer-When-Downgrade', 'Same-Origin', 'Origin', 'Strict-Origin',
            'Origin-When-Cross-Origin', 'Strict-Origin-When-Cross-Origin', 'Unsafe-Url')]
        [string]
        $Type
    )

    Add-PodeSecurityHeader -Name 'Referrer-Policy' -Value $Type.ToLowerInvariant()
}

function Remove-PodeSecurityReferrerPolicy
{
    [CmdletBinding()]
    param()

    Remove-PodeSecurityHeader -Name 'Referrer-Policy'
}

function Set-PodeSecurityContentTypeOptions
{
    [CmdletBinding()]
    param()

    Add-PodeSecurityHeader -Name 'X-Content-Type-Options' -Value 'nosniff'
}

function Remove-PodeSecurityContentTypeOptions
{
    [CmdletBinding()]
    param()

    Remove-PodeSecurityHeader -Name 'X-Content-Type-Options'
}

function Set-PodeSecurityStrictTransportSecurity
{
    [CmdletBinding()]
    param(
        [Parameter()]
        [int]
        $Duration = 31536000,

        [switch]
        $IncludeSubDomains
    )

    if ($Duration -le 0) {
        throw "Invalid Strict-Transport-Security duration supplied: $($Duration). Should be greater than 0"
    }

    $value = "max-age=$($Duration)"
    
    if ($IncludeSubDomains) {
        $value += "; includeSubDomains"
    }

    Add-PodeSecurityHeader -Name 'Strict-Transport-Security' -Value $value
}

function Remove-PodeSecurityStrictTransportSecurity
{
    [CmdletBinding()]
    param()

    Remove-PodeSecurityHeader -Name 'Strict-Transport-Security'
}

function Set-PodeSecurityCrossOrigin
{
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateSet('', 'Unsafe-None', 'Require-Corp')]
        [string]
        $Embed = '',

        [Parameter()]
        [ValidateSet('', 'Unsafe-None', 'Same-Origin-Allow-Popups', 'Same-Origin')]
        [string]
        $Open = '',

        [Parameter()]
        [ValidateSet('', 'Same-Site', 'Same-Origin', 'Cross-Origin')]
        [string]
        $Resource = ''
    )

    Add-PodeSecurityHeader -Name 'Cross-Origin-Embedder-Policy' -Value $Embed.ToLowerInvariant()
    Add-PodeSecurityHeader -Name 'Cross-Origin-Opener-Policy' -Value $Open.ToLowerInvariant()
    Add-PodeSecurityHeader -Name 'Cross-Origin-Resource-Policy' -Value $Resource.ToLowerInvariant()
}

function Remove-PodeSecurityCrossOrigin
{
    [CmdletBinding()]
    param()

    Remove-PodeSecurityHeader -Name 'Cross-Origin-Embedder-Policy'
    Remove-PodeSecurityHeader -Name 'Cross-Origin-Opener-Policy'
    Remove-PodeSecurityHeader -Name 'Cross-Origin-Resource-Policy'
}

function Set-PodeSecurityAccessControl
{
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Origin,

        [Parameter()]
        [ValidateSet('', 'Delete', 'Get', 'Head', 'Merge', 'Options', 'Patch', 'Post', 'Put', 'Trace', '*')]
        [string[]]
        $Methods = '',

        [Parameter()]
        [string[]]
        $Headers,

        [Parameter()]
        [int]
        $Duration = 7200,

        [switch]
        $Credentials
    )

    # origin
    Add-PodeSecurityHeader -Name 'Access-Control-Allow-Origin' -Value $Origin

    # methods
    if (![string]::IsNullOrWhiteSpace($Methods)) {
        if ($Methods -icontains '*') {
            Add-PodeSecurityHeader -Name 'Access-Control-Allow-Methods' -Value '*'
        }
        else {
            Add-PodeSecurityHeader -Name 'Access-Control-Allow-Methods' -Value ($Methods -join ', ').ToUpperInvariant()
        }
    }

    # headers
    if (![string]::IsNullOrWhiteSpace($Headers)) {
        if ($Headers -icontains '*') {
            Add-PodeSecurityHeader -Name 'Access-Control-Allow-Headers' -Value '*'
        }
        else {
            Add-PodeSecurityHeader -Name 'Access-Control-Allow-Headers' -Value ($Headers -join ', ').ToUpperInvariant()
        }
    }

    # duration
    if ($Duration -le 0) {
        throw "Invalid Access-Control-Max-Age duration supplied: $($Duration). Should be greater than 0"
    }

    Add-PodeSecurityHeader -Name 'Access-Control-Max-Age' -Value $Duration

    # creds
    if ($Credentials) {
        Add-PodeSecurityHeader -Name 'Access-Control-Allow-Credentials' -Value 'true'
    }
}

function Remove-PodeSecurityAccessControl
{
    [CmdletBinding()]
    param()

    Remove-PodeSecurityHeader -Name 'Access-Control-Allow-Origin'
    Remove-PodeSecurityHeader -Name 'Access-Control-Allow-Methods'
    Remove-PodeSecurityHeader -Name 'Access-Control-Allow-Headers'
    Remove-PodeSecurityHeader -Name 'Access-Control-Max-Age'
    Remove-PodeSecurityHeader -Name 'Access-Control-Allow-Credentials'
}