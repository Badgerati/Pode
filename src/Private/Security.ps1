using namespace System.Security.Cryptography

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

function Test-PodeCsrfConfigured {
    return (!(Test-PodeIsEmpty $PodeContext.Server.Cookies.Csrf))
}


<#
.SYNOPSIS
  Loads an X.509 certificate from a file (PFX, PEM, or CER), optionally decrypting it with a password.

.DESCRIPTION
  This function reads an X.509 certificate from a file and loads it as an X509Certificate2 object.
  It supports:
    - PFX (PKCS#12) certificates with optional password decryption.
    - PEM certificates with a separate private key file.
    - CER (DER or Base64-encoded) certificates (public key only).

  It applies the appropriate key storage flags depending on the operating system and
  ensures compatibility with Pode’s certificate handling utilities.

.PARAMETER Certificate
  The file path to the certificate (.pfx, .pem, or .cer) to load.

.PARAMETER SecurePassword
  A secure string containing the password for decrypting the certificate (only applicable for PFX files).

.PARAMETER PrivateKeyPath
  The path to a separate private key file (only applicable for PEM certificates).
  Required if the PEM certificate does not contain the private key.

.PARAMETER Ephemeral
  If specified, the certificate will be created with `EphemeralKeySet`, meaning the private key
  will **not be persisted** on disk or in the certificate store.

  This is useful for temporary certificates that should only exist in memory for the duration
  of the current session. Once the process exits, the private key will be lost.

.PARAMETER Exportable
 If specified the certificate will be created with `Exportable`, meaning the certificate can be exported

.OUTPUTS
  [System.Security.Cryptography.X509Certificates.X509Certificate2]
  Returns an X.509 certificate object.

.EXAMPLE
  $cert = Get-PodeCertificateByFile -Certificate "C:\Certs\mycert.pfx" -SecurePassword (ConvertTo-SecureString -String "MyPass" -AsPlainText -Force)
  Loads a PFX certificate with a password.

.EXAMPLE
  $cert = Get-PodeCertificateByFile -Certificate "C:\Certs\mycert.pem" -PrivateKeyPath "C:\Certs\mykey.pem"
  Loads a PEM certificate with a separate private key.

.EXAMPLE
  $cert = Get-PodeCertificateByFile -Certificate "C:\Certs\mycert.cer"
  Loads a CER certificate (public key only).

.NOTES
  - CER files do not contain private keys and cannot be decrypted with a password.
  - PEM certificates may require a separate private key file.
  - Uses EphemeralKeySet storage on non-macOS platforms for security.
#>
function Get-PodeCertificateByFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Certificate,

        [Parameter()]
        [securestring]
        $SecurePassword = $null,

        [Parameter()]
        [string]
        $PrivateKeyPath = $null,

        [Parameter()]
        [switch]
        $Ephemeral,

        [Parameter()]
        [switch]
        $Exportable
    )

    # cert + key
    if (![string]::IsNullOrWhiteSpace($PrivateKeyPath)) {
        return (Get-PodeCertificateByPemFile -Certificate $Certificate -Password $Password -SecurePassword $SecurePassword -PrivateKeyPath $PrivateKeyPath)
    }


    $path = Get-PodeRelativePath -Path $Certificate -JoinRoot -Resolve

    # read the cert bytes from the file to avoid the use of obsolete constructors
    $certBytes = [System.IO.File]::ReadAllBytes($path)

    if ($Ephemeral -and !$IsMacOS) {
        $storageFlags = [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::EphemeralKeySet
    }
    else {
        $storageFlags = [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::DefaultKeySet
    }

    if ($Exportable) {
        $storageFlags = $storageFlags -bor [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable
    }

    if ( [System.IO.Path]::GetExtension($path).ToLower() -eq '.pfx') {
        if ($null -ne $SecurePassword) {
            return [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($certBytes, $SecurePassword, $storageFlags)
        }
    }
    # plain cert
    return [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($certBytes, $null, $storageFlags)
}

function Get-PodeCertificateByPemFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Certificate,

        [Parameter()]
        [securestring]
        $SecurePassword = $null,

        [Parameter()]
        [string]
        $PrivateKeyPath = $null
    )

    $cert = $null

    $certPath = Get-PodeRelativePath -Path $Certificate -JoinRoot -Resolve
    $keyPath = Get-PodeRelativePath -Path $PrivateKeyPath -JoinRoot -Resolve

    # pem's kinda work in .NET3/.NET5
    if ([version]$PSVersionTable.PSVersion -ge [version]'7.0.0') {
        $cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($certPath)
        $keyText = [System.IO.File]::ReadAllText($keyPath)
        try {
            $rsa = [RSA]::Create()

            # .NET5
            if ([version]$PSVersionTable.PSVersion -ge [version]'7.1.0') {
                if ($null -eq $SecurePassword ) {
                    $rsa.ImportFromPem($keyText)
                }
                else {
                    $rsa.ImportFromEncryptedPem($keyText, (Convert-PodeSecureStringToByteArray -SecureString $SecurePassword))
                }
            } # .NET3
            else {
                $keyBlocks = $keyText.Split('-', [System.StringSplitOptions]::RemoveEmptyEntries)
                $keyBytes = [System.Convert]::FromBase64String($keyBlocks[1])

                if ($keyBlocks[0] -ieq 'BEGIN PRIVATE KEY') {
                    $rsa.ImportPkcs8PrivateKey($keyBytes, [ref]$null)
                }
                elseif ($keyBlocks[0] -ieq 'BEGIN RSA PRIVATE KEY') {
                    $rsa.ImportRSAPrivateKey($keyBytes, [ref]$null)
                }
                elseif ($keyBlocks[0] -ieq 'BEGIN ENCRYPTED PRIVATE KEY') {
                    if ($null -ne $SecurePassword) {
                        [int32]$bytesRead = 0
                        $rsa.ImportEncryptedPkcs8PrivateKey( (Convert-PodeSecureStringToByteArray -SecureString $SecurePassword), $keyBytes, [ref]$bytesRead)
                    }
                }
                $cert = [System.Security.Cryptography.X509Certificates.RSACertificateExtensions]::CopyWithPrivateKey($cert, $rsa)
            }
        }
        catch {
            $ecsd = [ECDSA]::Create()
            if ([version]$PSVersionTable.PSVersion -ge [version]'7.1.0') {
                if ( $null -eq $SecurePassword ) {
                    $ecsd.ImportFromPem($keyText)
                }
                else {
                    $ecsd.ImportFromEncryptedPem($keyText, (Convert-PodeSecureStringToByteArray -SecureString $SecurePassword))

                }


                # .NET3
                else {
                    $keyBlocks = $keyText.Split('-', [System.StringSplitOptions]::RemoveEmptyEntries)
                    $keyBytes = [System.Convert]::FromBase64String($keyBlocks[1])

                    if ($keyBlocks[0] -ieq 'BEGIN PRIVATE KEY') {
                        $ecsd.ImportPkcs8PrivateKey($keyBytes, [ref]$null)
                    }
                    elseif ($keyBlocks[0] -ieq 'BEGIN RSA PRIVATE KEY') {
                        $ecsd.ImportRSAPrivateKey($keyBytes, [ref]$null)
                    }
                    elseif ($keyBlocks[0] -ieq 'BEGIN ENCRYPTED PRIVATE KEY') {
                        if ($null -ne $SecurePassword) {
                            [int32]$bytesRead = 0
                            $ecsd.ImportEncryptedPkcs8PrivateKey( (Convert-PodeSecureStringToByteArray -SecureString $SecurePassword), $keyBytes, [ref]$bytesRead)
                        }
                    }
                }


                $cert = [System.Security.Cryptography.X509Certificates.ECDsaCertificateExtensions]::CopyWithPrivateKey($cert, $ecsd)
            }
            $cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($cert.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Pkcs12))
        }
    }
    # for everything else, there's the openssl way
    else {
        $tempFile = Join-Path (Split-Path -Parent -Path $certPath) 'temp.pfx'

        try {
            if ($null -ne $SecurePassword) {
                $Password = Convert-PodeSecureStringToPlainText -SecureString $SecurePassword
            }
            if ([string]::IsNullOrWhiteSpace($Password)) {
                $Password = [string]::Empty
            }

            $result = openssl pkcs12 -inkey $keyPath -in $certPath -export -passin pass:$Password -password pass:$Password -out $tempFile
            if (!$?) {
                throw ($PodeLocale.failedToCreateOpenSslCertExceptionMessage -f $result) #"Failed to create openssl cert: $($result)"
            }

            $cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($tempFile, $Password)
        }
        finally {
            $null = Remove-Item $tempFile -Force
        }
    }

    return $cert
}

function Find-PodeCertificateInCertStore {
    param(
        [Parameter(Mandatory = $true)]
        [System.Security.Cryptography.X509Certificates.X509FindType]
        $FindType,

        [Parameter(Mandatory = $true)]
        [string]
        $Query,

        [Parameter(Mandatory = $true)]
        [System.Security.Cryptography.X509Certificates.StoreName]
        $StoreName,

        [Parameter(Mandatory = $true)]
        [System.Security.Cryptography.X509Certificates.StoreLocation]
        $StoreLocation
    )

    # fail if not windows
    if (!(Test-PodeIsWindows)) {
        # Certificate Thumbprints/Name are only supported on Windows
        throw ($PodeLocale.certificateThumbprintsNameSupportedOnWindowsExceptionMessage)
    }

    # open the currentuser\my store
    $x509store = [System.Security.Cryptography.X509Certificates.X509Store]::new($StoreName, $StoreLocation)

    try {
        # attempt to find the cert
        $x509store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadOnly)
        $x509certs = $x509store.Certificates.Find($FindType, $Query, $false)
    }
    finally {
        # close the store!
        if ($null -ne $x509store) {
            Close-PodeDisposable -Disposable $x509store -Close
        }
    }

    # fail if no cert found for query
    if (($null -eq $x509certs) -or ($x509certs.Count -eq 0)) {
        throw ($PodeLocale.noCertificateFoundExceptionMessage -f $StoreLocation, $StoreName, $Query) # "No certificate could be found in $($StoreLocation)\$($StoreName) for '$($Query)'"
    }

    return ([System.Security.Cryptography.X509Certificates.X509Certificate2]($x509certs[0]))
}

function Get-PodeCertificateByThumbprint {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Thumbprint,

        [Parameter(Mandatory = $true)]
        [System.Security.Cryptography.X509Certificates.StoreName]
        $StoreName,

        [Parameter(Mandatory = $true)]
        [System.Security.Cryptography.X509Certificates.StoreLocation]
        $StoreLocation
    )

    return Find-PodeCertificateInCertStore `
        -FindType ([System.Security.Cryptography.X509Certificates.X509FindType]::FindByThumbprint) `
        -Query $Thumbprint `
        -StoreName $StoreName `
        -StoreLocation $StoreLocation
}

function Get-PodeCertificateByName {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $true)]
        [System.Security.Cryptography.X509Certificates.StoreName]
        $StoreName,

        [Parameter(Mandatory = $true)]
        [System.Security.Cryptography.X509Certificates.StoreLocation]
        $StoreLocation
    )

    return Find-PodeCertificateInCertStore `
        -FindType ([System.Security.Cryptography.X509Certificates.X509FindType]::FindBySubjectName) `
        -Query $Name `
        -StoreName $StoreName `
        -StoreLocation $StoreLocation
}

function New-PodeSelfSignedCertificate2 {
    $sanBuilder = [System.Security.Cryptography.X509Certificates.SubjectAlternativeNameBuilder]::new()
    $null = $sanBuilder.AddIpAddress([ipaddress]::Loopback)
    $null = $sanBuilder.AddIpAddress([ipaddress]::IPv6Loopback)
    $null = $sanBuilder.AddDnsName('localhost')

    if (![string]::IsNullOrWhiteSpace($PodeContext.Server.ComputerName)) {
        $null = $sanBuilder.AddDnsName($PodeContext.Server.ComputerName)
    }

    $rsa = [RSA]::Create(2048)
    $distinguishedName = [X500DistinguishedName]::new('CN=localhost')

    $req = [System.Security.Cryptography.X509Certificates.CertificateRequest]::new(
        $distinguishedName,
        $rsa,
        [HashAlgorithmName]::SHA256,
        [RSASignaturePadding]::Pkcs1
    )

    $flags = (
        [System.Security.Cryptography.X509Certificates.X509KeyUsageFlags]::DataEncipherment -bor
        [System.Security.Cryptography.X509Certificates.X509KeyUsageFlags]::KeyEncipherment -bor
        [System.Security.Cryptography.X509Certificates.X509KeyUsageFlags]::DigitalSignature
    )

    $null = $req.CertificateExtensions.Add(
        [System.Security.Cryptography.X509Certificates.X509KeyUsageExtension]::new(
            $flags,
            $false
        )
    )

    $oid = [OidCollection]::new()
    $null = $oid.Add([Oid]::new('1.3.6.1.5.5.7.3.1'))

    $req.CertificateExtensions.Add(
        [System.Security.Cryptography.X509Certificates.X509EnhancedKeyUsageExtension]::new(
            $oid,
            $false
        )
    )

    $null = $req.CertificateExtensions.Add($sanBuilder.Build())

    $cert = $req.CreateSelfSigned(
        [System.DateTimeOffset]::UtcNow.AddDays(-1),
        [System.DateTimeOffset]::UtcNow.AddYears(10)
    )

    if (Test-PodeIsWindows) {
        $cert.FriendlyName = 'localhost'
    }

    $cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new(
        $cert.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Pfx, 'self-signed'),
        'self-signed'
    )

    return $cert
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