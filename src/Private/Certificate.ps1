<#
.SYNOPSIS
  Exports a private key in PEM format, optionally encrypting it with a password.

.DESCRIPTION
  This function exports a private key in PEM format using PKCS#8 encoding.
  If a password is provided, the private key is encrypted using AES-256-CBC
  with SHA-256 hashing and 100,000 iterations. The function supports both
  PowerShell 7+ and older versions, using native methods where available.

.PARAMETER Key
  The asymmetric key to export. Must be an instance of System.Security.Cryptography.AsymmetricAlgorithm.

.PARAMETER Password
  A secure string containing the password for encrypting the private key.
  If omitted, the private key is exported unencrypted.

.OUTPUTS
  [string]
  Returns the private key as a PEM-formatted string.

.EXAMPLE
  $rsa = [System.Security.Cryptography.RSA]::Create(2048)
  $pem = Export-PodePrivateKeyPem -Key $rsa
  Exports an unencrypted private key in PEM format.

.EXAMPLE
  $rsa = [System.Security.Cryptography.RSA]::Create(2048)
  $securePassword = ConvertTo-SecureString -String "MyStrongPass" -AsPlainText -Force
  $pem = Export-PodePrivateKeyPem -Key $rsa -Password $securePassword
  Exports an encrypted private key in PEM format using the provided password.

.NOTES
  This function ensures compatibility with both PowerShell 7+ (using native PEM methods)
  and older versions (manually constructing the PEM format). It is designed for use
  within Pode’s cryptographic handling utilities.
  This is an internal Pode function and may be subject to change.
#>
function Export-PodePrivateKeyPem {
    param (
        [Parameter(Mandatory = $true)]
        [System.Security.Cryptography.AsymmetricAlgorithm]
        $Key,

        [Parameter()]
        [securestring]
        $Password
    )
    $builder = [System.Text.StringBuilder]::new()

    if ($null -ne $Password) {
        if ($PSVersionTable.PSVersion.Major -ge 7) {
            # Export encrypted private key in PEM using the native method
            return $Key.ExportEncryptedPkcs8PrivateKeyPem(
                (Convert-PodeSecureStringToPlainText($Password)),
                [System.Security.Cryptography.PbeParameters]::new(
                    [System.Security.Cryptography.PbeEncryptionAlgorithm]::Aes256Cbc,
                    [System.Security.Cryptography.HashAlgorithmName]::SHA256,
                    100000
                )
            )
        }
        # For older versions, export encrypted key using PKCS#8 format
        $encryptedBytes = $Key.ExportEncryptedPkcs8PrivateKey(
            (Convert-PodeSecureStringToPlainText($Password)),
            [System.Security.Cryptography.PbeParameters]::new(
                [System.Security.Cryptography.PbeEncryptionAlgorithm]::Aes256Cbc,
                [System.Security.Cryptography.HashAlgorithmName]::SHA256,
                100000
            )
        )
        $base64Key = [Convert]::ToBase64String($encryptedBytes)
        $null = $builder.AppendLine('-----BEGIN ENCRYPTED PRIVATE KEY-----')
    }
    else {
        if ($PSVersionTable.PSVersion.Major -ge 7) {
            # Export unencrypted private key in PEM using the native method
            return $Key.ExportPkcs8PrivateKeyPem()
        }
        # For older versions, export unencrypted key using PKCS#8 format
        $unencryptedBytes = $Key.ExportPkcs8PrivateKey()
        $base64Key = [Convert]::ToBase64String($unencryptedBytes)
        $null = $builder.AppendLine('-----BEGIN PRIVATE KEY-----')
    }

    for ($i = 0; $i -lt $base64Key.Length; $i += 64) {
        $null = $builder.AppendLine($base64Key.Substring($i, [System.Math]::Min(64, $base64Key.Length - $i)))
    }
    $null = $builder.AppendLine('-----END PRIVATE KEY-----')
    return $builder.ToString()
}

<#
.SYNOPSIS
  Generates a certificate signing request (CSR) with specified parameters.

.DESCRIPTION
  This function creates a certificate signing request (CSR) using RSA or ECDSA key pairs.
  It supports specifying subject details, key usage, enhanced key usage (EKU),
  and custom extensions. The function returns a PSCustomObject containing
  the CSR in Base64 format, the request object, the generated private key,
  and additional metadata.

.PARAMETER DnsName
  One or more DNS names (or IP addresses) to be included in the Subject Alternative Name (SAN).

.PARAMETER CommonName
  The Common Name (CN) for the certificate subject. Defaults to the first DNS name if not provided.

.PARAMETER Organization
  The organization (O) name to be included in the certificate subject.

.PARAMETER Locality
  The locality (L) name to be included in the certificate subject.

.PARAMETER State
  The state (S) name to be included in the certificate subject.

.PARAMETER Country
  The country (C) code (ISO 3166-1 alpha-2). Defaults to 'XX'.

.PARAMETER KeyType
  The cryptographic key type for the certificate request. Supported values: 'RSA', 'ECDSA'. Defaults to 'RSA'.

.PARAMETER KeyLength
  The key length for RSA (2048, 3072, 4096) or ECDSA (256, 384, 521). Defaults to 2048.

.PARAMETER CertificatePurpose
  The intended purpose of the certificate, which automatically sets the EKU.
  Supported values: 'ServerAuth', 'ClientAuth', 'CodeSigning', 'EmailSecurity', 'Custom'.

.PARAMETER EnhancedKeyUsages
  A list of OID strings for Enhanced Key Usage (EKU) if 'Custom' is selected as CertificatePurpose.

.PARAMETER CustomExtensions
  An array of additional custom certificate extensions.

.OUTPUTS
  [PSCustomObject] (PsTypeName = 'PodeCertificateRequest')
  Returns an object containing:
    - Request: The CSR in Base64 format.
    - CertificateRequest: The generated certificate request object.
    - PrivateKey: The generated private key.

.EXAMPLE
  $csr = New-PodeCertificateRequestInternal -DnsName "example.com" -CommonName "example.com" -KeyType "RSA" -KeyLength 2048
  Creates a certificate request for "example.com" using RSA with a 2048-bit key.

.EXAMPLE
  $csr = New-PodeCertificateRequestInternal -DnsName "example.com" -KeyType "ECDSA" -KeyLength 384 -CertificatePurpose "ServerAuth"
  Generates an ECDSA certificate request for "example.com" with an automatically assigned EKU for server authentication.

.NOTES
  This is an internal Pode function and may be subject to change.
  It is designed to integrate with Pode’s SSL and security handling mechanisms.
#>
function New-PodeCertificateRequestInternal {
    [CmdletBinding(DefaultParameterSetName = 'CommonName')]
    [OutputType([PSCustomObject])]
    param (
        # Required: one or more DNS names (or IP addresses)
        [Parameter()]
        [string[]]
        $DnsName,

        # Subject parts
        [Parameter()]
        [string]
        $CommonName,

        [Parameter()]
        [string]
        $Organization,

        [Parameter()]
        [string]
        $Locality,

        [Parameter()]
        [string]
        $State,

        [Parameter()]
        [string]
        $Country = 'XX',

        # Key type and size
        [Parameter()]
        [ValidateSet('RSA', 'ECDSA')]
        [string]$KeyType = 'RSA',

        [Parameter()]
        [ValidateSet(2048, 3072, 4096, 256, 384, 521)]
        [int]$KeyLength = 2048,

        #Automatically set EKUs based on intended purpose
        [Parameter()]
        [ValidateSet('ServerAuth', 'ClientAuth', 'CodeSigning', 'EmailSecurity', 'Custom')]
        [string]
        $CertificatePurpose,

        # Enhanced Key Usages (EKU) - supply one or more OID strings if desired.
        [Parameter()]
        [string[]]
        $EnhancedKeyUsages,

        # Additional custom extensions (as an array of certificate extension objects).
        [Parameter()]
        [object[]]
        $CustomExtensions
    )

    # Assign EKU based on selected purpose
    $ekuOids = switch ($CertificatePurpose) {
        'ServerAuth' { @('1.3.6.1.5.5.7.3.1') }  # Server Authentication (HTTPS/TLS)
        'ClientAuth' { @('1.3.6.1.5.5.7.3.2') }  # Client Authentication (VPN, Mutual TLS)
        'CodeSigning' { @('1.3.6.1.5.5.7.3.3') }  # Code Signing (JWT, Software)
        'EmailSecurity' { @('1.3.6.1.5.5.7.3.4') }  # Email Security (S/MIME)
        'Custom' { $EnhancedKeyUsages }      # Use manually supplied OIDs
        default { $null }
    }

    # Ensure CommonName is set (fallback to first DNS entry if missing)
    if (-not $CommonName -and $DnsName.Count -gt 0) {
        $CommonName = $DnsName[0]
    }
    if (-not $CommonName) {
        $CommonName = 'SelfSigned'
    }


    # Build the Distinguished Name (DN) string.
    $subjectParts = @("CN=$CommonName")
    if (![string]::IsNullOrEmpty($Organization)) { $subjectParts += "O=$Organization" }
    if (![string]::IsNullOrEmpty($Locality)) { $subjectParts += "L=$Locality" }
    if (![string]::IsNullOrEmpty( $State)) { $subjectParts += "S=$State" }
    $subjectParts += "C=$Country"
    $SubjectDN = $subjectParts -join ', '

    # Initialize the SAN (Subject Alternative Name) builder.
    $sanBuilder = $null
    if ($DnsName) {
        $sanBuilder = [System.Security.Cryptography.X509Certificates.SubjectAlternativeNameBuilder]::new()
        foreach ($name in $DnsName) {
            $parsedIp = $null
            if ([System.Net.IPAddress]::TryParse($name, [ref]$parsedIp)) {
                $sanBuilder.AddIpAddress($parsedIp)
            }
            else {
                $sanBuilder.AddDnsName($name)
            }
        }
    }

    # Generate key pair and certificate request based on the chosen key type.
    switch ($KeyType) {
        'RSA' {
            if (@(2048, 3072, 4096) -notcontains $KeyLength ) {
                ($PodeLocale.unsupportedCertificateKeyLengthExceptionMessage -f $KeyLength)
            }
            $key = [System.Security.Cryptography.RSA]::Create($KeyLength)
            if (! $key) { throw $PodeLocale.failedToCreateCertificateRequestExceptionMessage }
            $distinguishedName = [X500DistinguishedName]::new($SubjectDN)
            $hashAlgorithm = [System.Security.Cryptography.HashAlgorithmName]::SHA256
            $rsaPadding = [System.Security.Cryptography.RSASignaturePadding]::Pkcs1
            $req = [System.Security.Cryptography.X509Certificates.CertificateRequest]::new(
                $distinguishedName,
                $key,
                $hashAlgorithm,
                $rsaPadding
            )
        }
        'ECDSA' {
            $curveOid = switch ($KeyLength) {
                256 { '1.2.840.10045.3.1.7' }  # nistP256
                384 { '1.3.132.0.34' }         # nistP384
                521 { '1.3.132.0.35' }         # nistP521
                default { throw ($PodeLocale.unsupportedCertificateKeyLengthExceptionMessage -f $KeyLength) }
            }
            $curve = [System.Security.Cryptography.ECCurve]::CreateFromOid(
                [System.Security.Cryptography.Oid]::new($curveOid)
            )
            $key = [System.Security.Cryptography.ECDsa]::Create($curve)
            if (-not $key) { throw $PodeLocale.failedToCreateCertificateRequestExceptionMessage }
            $hashAlgorithm = switch ($KeyLength) {
                256 { [System.Security.Cryptography.HashAlgorithmName]::SHA256 }
                384 { [System.Security.Cryptography.HashAlgorithmName]::SHA384 }
                521 { [System.Security.Cryptography.HashAlgorithmName]::SHA512 }
            }
            $req = [System.Security.Cryptography.X509Certificates.CertificateRequest]::new(
                $SubjectDN,
                $key,
                $hashAlgorithm
            )
        }
    }

    if (! $req) { throw $PodeLocale.failedToCreateCertificateRequestExceptionMessage }

    # Add Basic Constraints (as a CA: false certificate).
    $req.CertificateExtensions.Add(
        [System.Security.Cryptography.X509Certificates.X509BasicConstraintsExtension]::new($false, $false, 0, $true)
    )

    # Add Key Usage extension.
    $keyUsageFlags = (
        [System.Security.Cryptography.X509Certificates.X509KeyUsageFlags]::DigitalSignature -bor
        [System.Security.Cryptography.X509Certificates.X509KeyUsageFlags]::KeyEncipherment -bor
        [System.Security.Cryptography.X509Certificates.X509KeyUsageFlags]::DataEncipherment
    )
    $req.CertificateExtensions.Add(
        [System.Security.Cryptography.X509Certificates.X509KeyUsageExtension]::new($keyUsageFlags, $false)
    )

    # Add Subject Alternative Name (SAN) extension.
    if ($sanBuilder) {
        $req.CertificateExtensions.Add($sanBuilder.Build())
    }

    # Add EKU extension
    if ($ekuOids) {
        $oidCollection = [System.Security.Cryptography.OidCollection]::new()
        foreach ($oid in $ekuOids) {
            $oidCollection.Add([System.Security.Cryptography.Oid]::new($oid)) | Out-Null
        }
        $ekuExtension = [System.Security.Cryptography.X509Certificates.X509EnhancedKeyUsageExtension]::new($oidCollection, $false)
        $req.CertificateExtensions.Add($ekuExtension)
    }

    # Add any additional custom extensions.
    if ($CustomExtensions) {
        foreach ($ext in $CustomExtensions) {
            $req.CertificateExtensions.Add($ext)
        }
    }

    # Create the signing request (CSR) in PKCS#10 format.
    $csrBytes = $req.CreateSigningRequest()
    $csrBase64 = [System.Convert]::ToBase64String($csrBytes)

    return [PSCustomObject]@{
        PsTypeName         = 'PodeCertificateRequest'
        Request            = $csrBase64
        CertificateRequest = $req
        PrivateKey         = $key
    }
}


<#
.SYNOPSIS
  Validates whether an X.509 certificate is authorized for a specific purpose.

.DESCRIPTION
  This internal function checks if an X.509 certificate contains the necessary Enhanced Key Usage (EKU)
  for an expected purpose. If the certificate lacks the required EKU, an exception is thrown.

  If `-Strict` mode is enabled, the function also rejects certificates containing unknown EKUs.

.PARAMETER Certificate
  The X509Certificate2 object to validate.

.PARAMETER ExpectedPurpose
  The required purpose for the certificate. Supported values:
    - 'ServerAuth'      (1.3.6.1.5.5.7.3.1)
    - 'ClientAuth'      (1.3.6.1.5.5.7.3.2)
    - 'CodeSigning'     (1.3.6.1.5.5.7.3.3)
    - 'EmailSecurity'   (1.3.6.1.5.5.7.3.4)

.PARAMETER Strict
  If specified, the function will **fail** if the certificate contains unknown EKUs.

.OUTPUTS
  [boolean]
  Returns `$true` if the certificate is valid for the specified purpose.
  Throws an exception if the certificate lacks the required EKU or contains unknown EKUs in `-Strict` mode.

.EXAMPLE
  Test-PodeCertificateRestriction -Certificate $cert -ExpectedPurpose 'ServerAuth'
  Validates whether the given certificate can be used for server authentication.

.EXAMPLE
  Test-PodeCertificateRestriction -Certificate $cert -ExpectedPurpose 'ClientAuth' -Strict
  Validates whether the certificate is authorized for client authentication, rejecting unknown EKUs.

.NOTES
  This is an internal Pode function and may be subject to change.
#>
function Test-PodeCertificateRestriction {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate,

        [Parameter(Mandatory = $true)]
        [ValidateSet('ServerAuth', 'ClientAuth', 'CodeSigning', 'EmailSecurity')]
        [string]$ExpectedPurpose,

        [Parameter()]
        [switch]$Strict
    )

    # Get the actual purposes of the certificate
    $purposes = Get-PodeCertificatePurpose -Certificate $Certificate

    # If the certificate has no EKU and no restrictions, allow it (but warn)
    if ($purposes.Count -eq 0 -and ! $Strict) {
        Write-Verbose 'Certificate has no EKU restrictions. It can be used for any purpose.'
        return
    }

    # If the expected purpose is not in the list, throw an exception
    if ($ExpectedPurpose -notin $purposes) {
        throw ($PodeLocale.certificateNotValidForPurposeExceptionMessage -f $ExpectedPurpose, ($purposes -join ', '))
    }

    # If strict mode is enabled, fail if there are any unknown EKUs
    if ($Strict -and ($purposes -match '^Unknown')) {
        throw ($PodeLocale.certificateUnknownEkusStrictModeExceptionMessage -f ($purposes -join ', '))
    }

    # Certificate is valid for the expected purpose
    Write-Verbose "Certificate is valid for '$ExpectedPurpose'. Found purposes: $($purposes -join ', ')"

}
