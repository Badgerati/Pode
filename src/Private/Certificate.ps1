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



<#
.SYNOPSIS
  Loads an X.509 certificate from a file (PFX, PEM, or CER), optionally decrypting it with a password,
  and optionally appending additional chain certificates.

.DESCRIPTION
  This function reads an X.509 certificate from a file and loads it as an X509Certificate2 object.
  It supports:
    - PFX (PKCS#12) certificates with optional password decryption.
    - PEM certificates with a separate private key file.
    - CER (DER or Base64‑encoded) certificates (public key only).
    - Appending one or more additional chain certificates (PEM or CER) to build a full certificate chain,
      and re‑exporting as PFX if a password is provided.

  It applies the appropriate key storage flags depending on the operating system and
  ensures compatibility with Pode’s certificate handling utilities.

.PARAMETER Certificate
  The file path to the certificate (.pfx, .pem, or .cer) to load.

.PARAMETER SecurePassword
  A secure string containing the password for decrypting the certificate (only applicable for PFX files)
  and for re‑exporting the combined chain if `ChainFile` is provided.

.PARAMETER PrivateKeyPath
  The path to a separate private key file (only applicable for PEM certificates).
  Required if the PEM certificate does not contain the private key.

.PARAMETER Ephemeral
  If specified, the certificate will be created with `EphemeralKeySet`, meaning the private key
  will **not be persisted** on disk or in the certificate store.

.PARAMETER Exportable
  If specified, the certificate will be created with the `Exportable` flag, allowing it to be exported later.

.PARAMETER ChainFile
  An array of file paths to additional certificate files (PEM or CER) to include in the chain.
  Each file will be parsed for one or more certificates and appended to the primary certificate.
  If `SecurePassword` is provided, the full chain will be re‑exported as a single PFX.
  Powershell 7.5+ is required for this feature.

.OUTPUTS
  [System.Security.Cryptography.X509Certificates.X509Certificate2]
  Returns an X.509 certificate object containing the primary cert (and chain, if requested).

.EXAMPLE
  # Load a PFX with password
  $cert = Get-PodeCertificateByFile `
    -Certificate "C:\Certs\mycert.pfx" `
    -SecurePassword (ConvertTo-SecureString "MyPass" -AsPlainText -Force)

.EXAMPLE
  # Load a PEM plus private key
  $cert = Get-PodeCertificateByFile `
    -Certificate "C:\Certs\mycert.pem" `
    -PrivateKeyPath "C:\Certs\mykey.pem"

.EXAMPLE
  # Load a CER (public only)
  $cert = Get-PodeCertificateByFile -Certificate "C:\Certs\mycert.cer"

.EXAMPLE
  # Load a PFX and append chain files, re-exporting as PFX
  $cert = Get-PodeCertificateByFile `
    -Certificate "C:\Certs\server.pfx" `
    -SecurePassword (ConvertTo-SecureString "ChainPass" -AsPlainText -Force) `
    -ChainFile @("C:\Certs\intermediate.pem","C:\Certs\root.cer")

.NOTES
  - CER files do not contain private keys and cannot be decrypted with a password.
  - PEM certificates may require a separate private‑key file.
  - Uses `EphemeralKeySet` storage on non‑macOS platforms for in‑memory keys.
  - When `ChainFile` is used with a password, the collective chain is exported to PFX and reloaded,
    ensuring the returned certificate contains the full chain.
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
        $Exportable,

        [Parameter()]
        [string[]]$ChainFile = $null
    )

    $path = Get-PodeRelativePath -Path $Certificate -JoinRoot -Resolve

    if ($Ephemeral -and !$IsMacOS) {
        $storageFlags = [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::EphemeralKeySet
    }
    else {
        $storageFlags = [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::DefaultKeySet
    }

    # if user explicitly asked for Exportable *or* we know
    # we’re going to re-export with a chain, mark it now
    if ($Exportable -or ($ChainFile -and $ChainFile.Count -gt 0)) {
        $storageFlags = $storageFlags -bor [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable
    }

    # If a PrivateKeyPath is provided, delegate to the PEM specialized function.
    if (! [string]::IsNullOrWhiteSpace($PrivateKeyPath)) {
        $cert = Get-PodeCertificateByPemFile -Certificate $Certificate -SecurePassword $SecurePassword -PrivateKeyPath $PrivateKeyPath -storageFlags $storageFlags
    }
    else {
        # Read certificate bytes to avoid use of obsolete constructors.
        $certBytes = [System.IO.File]::ReadAllBytes($path)
        $cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($certBytes, $SecurePassword, $storageFlags)
    }


    # Process chain certificates if one or more chain file paths are provided.
    if ($ChainFile -and $ChainFile.Count -gt 0) {
        if ($PSVersionTable.PSVersion -lt [version]'7.5.0') {
            throw ($PodeLocale.chainCertificateNotSupportedByPwshVersionExceptionMessage -f $PSVersionTable.PSVersion)
        }
        # Initialize the collection with the primary certificate.
        $certCollection = [System.Security.Cryptography.X509Certificates.X509Certificate2Collection]::new()
        $null = $certCollection.Add($cert)

        foreach ($chainPath in $ChainFile) {
            if (Test-Path $chainPath) {
                $resolvedChainPath = Get-PodeRelativePath -Path $chainPath -JoinRoot -Resolve
                $chainContent = Get-Content -Path $resolvedChainPath -Raw

                # Split the file into certificate blocks by the PEM delimiter.
                $pemBlocks = $chainContent -split '-----END CERTIFICATE-----' | ForEach-Object {
                    if ($_ -match '-----BEGIN CERTIFICATE-----') {
                        $_ + '-----END CERTIFICATE-----'
                    }
                } | Where-Object { $_ -and $_.Trim().Length -gt 0 }

                foreach ($pem in $pemBlocks) {

                    $base64 = $pem -replace '-----BEGIN CERTIFICATE-----', '' `
                        -replace '-----END CERTIFICATE-----', '' `
                        -replace '\s+', ''
                    $chainCert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new([System.Convert]::FromBase64String($base64))
                    $null = $certCollection.Add($chainCert)

                }
            }
            else {
                throw ($PodeLocale.noCertificateFoundExceptionMessage -f $chainPath, '', 'import') # "Certificate chain file not found: $chainPath"
            }
        }

        # Optionally combine the certificates into a single PFX.
        $pfxBytes = $certCollection.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Pfx, (Convert-PodeSecureStringToPlainText -SecureString $SecurePassword))
        $cert = [System.Security.Cryptography.X509Certificates.X509CertificateLoader]::LoadPkcs12Collection(
            $pfxBytes,
          (Convert-PodeSecureStringToPlainText -SecureString $SecurePassword),
            $storageFlags,
            [System.Security.Cryptography.X509Certificates.Pkcs12LoaderLimits]::Defaults
        )
    }

    return $cert
}

<#
.SYNOPSIS
Loads an X.509 certificate from a PEM file and associates it with a corresponding private key, returning an X509Certificate2 object.

.DESCRIPTION
This function reads an X.509 certificate from a PEM-formatted file and combines it with a corresponding private key from a separate PEM file. It supports both RSA and ECDSA keys, handling encrypted and unencrypted private keys. The resulting X509Certificate2 object includes the private key and is instantiated with specified key storage flags to control key persistence and exportability.

.PARAMETER Certificate
The file path to the PEM-formatted certificate file.

.PARAMETER SecurePassword
A secure string containing the password for decrypting the private key, if it is encrypted.

.PARAMETER PrivateKeyPath
The file path to the PEM-formatted private key file corresponding to the certificate.

.PARAMETER storageFlags
Specifies the key storage flags to use when instantiating the X509Certificate2 object. These flags determine how and where the private key is stored, such as in memory or on disk, and whether it is exportable.

.OUTPUTS
[System.Security.Cryptography.X509Certificates.X509Certificate2]
Returns an X.509 certificate object that includes the associated private key.

.EXAMPLE
$cert = Get-PodeCertificateByPemFile -Certificate "C:\Certs\mycert.pem" -PrivateKeyPath "C:\Certs\mykey.pem" -storageFlags ([System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable)
Loads a PEM certificate and its corresponding private key, returning an exportable X509Certificate2 object.

.EXAMPLE
$password = ConvertTo-SecureString -String "MyPass" -AsPlainText -Force
$cert = Get-PodeCertificateByPemFile -Certificate "C:\Certs\mycert.pem" -PrivateKeyPath "C:\Certs\mykey.pem" -SecurePassword $password -storageFlags ([System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable)
Loads an encrypted PEM private key using the provided password and combines it with the certificate.

.NOTES
- Requires PowerShell 7.0 or later due to the use of ImportFromPem and related methods.
- The function handles both PKCS#1 and PKCS#8 private key formats.
- Ensure that the certificate and private key files correspond to each other to avoid mismatches.
- The resulting certificate object can be used for secure communications, such as HTTPS bindings or client authentication.
#>
function Get-PodeCertificateByPemFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Certificate,

        [Parameter()]
        [securestring]
        $SecurePassword = $null,

        [Parameter(Mandatory = $true)]
        [string]
        $PrivateKeyPath,

        [Parameter(Mandatory = $true)]
        [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]
        $storageFlags
    )

    if ($PSVersionTable.PSVersion.Major -lt 7) {
        throw ($PodeLocale.pemCertificateNotSupportedByPwshVersionExceptionMessage -f $PSVersionTable.PSVersion)
    }

    $cert = $null

    $certPath = Get-PodeRelativePath -Path $Certificate -JoinRoot -Resolve
    $keyPath = Get-PodeRelativePath -Path $PrivateKeyPath -JoinRoot -Resolve

    # pem's kinda work in .NET3/.NET5
    if ([version]$PSVersionTable.PSVersion -ge [version]'7.0.0') {
        $cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($certPath, $SecurePassword, $storageFlags)
        $keyText = [System.IO.File]::ReadAllText($keyPath)
        try {
            $rsa = [System.Security.Cryptography.RSA]::Create()

            # .NET5
            if ([version]$PSVersionTable.PSVersion -ge [version]'7.1.0') {
                if ($null -eq $SecurePassword ) {
                    $rsa.ImportFromPem($keyText)
                }
                else {
                    $rsa.ImportFromEncryptedPem($keyText, (Convert-PodeSecureStringToPlainText -SecureString $SecurePassword))
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
                        $rsa.ImportEncryptedPkcs8PrivateKey( (Convert-PodeSecureStringToPlainText -SecureString $SecurePassword), $keyBytes, [ref]$bytesRead)
                    }
                }
            }
            $cert = [System.Security.Cryptography.X509Certificates.RSACertificateExtensions]::CopyWithPrivateKey($cert, $rsa)
        }
        catch {
            $ecsd = [System.Security.Cryptography.ECDsa]::Create()
            if ([version]$PSVersionTable.PSVersion -ge [version]'7.1.0') {
                if ( $null -eq $SecurePassword ) {
                    $ecsd.ImportFromPem($keyText)
                }
                else {
                    $ecsd.ImportFromEncryptedPem($keyText, (Convert-PodeSecureStringToByteArray -SecureString $SecurePassword))

                }
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
        # Export the certificate to a byte array in PKCS#12 format
        $certificateBytes = $cert.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Pkcs12, $SecurePassword)

        if ($PSVersionTable.PSVersion -ge [version]'7.5.0') {
            #[System.Security.Cryptography.X509Certificates.X509Certificate2]::new is deprecated in .NET 9.0
            $cert = [System.Security.Cryptography.X509Certificates.X509CertificateLoader]::LoadPkcs12(
                $certificateBytes,
                (Convert-PodeSecureStringToPlainText -SecureString $SecurePassword),
                $storageFlags,
                [System.Security.Cryptography.X509Certificates.Pkcs12LoaderLimits]::Defaults
            )
        }
        else {
            $cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new(
                $certificateBytes,
                (Convert-PodeSecureStringToPlainText -SecureString $SecurePassword),
                $storageFlags
            )
        }
    }

    return $cert
}


<#
.SYNOPSIS
    Finds and returns an X.509 certificate from the Windows certificate store.

.DESCRIPTION
    This function searches the specified Windows certificate store using a provided query
    (such as a thumbprint or subject name) and returns the first matching X509Certificate2 object.

    The function only works on Windows platforms, as certificate store operations are not supported cross-platform.

.PARAMETER FindType
    The type of search to perform in the certificate store (e.g., FindByThumbprint, FindBySubjectName).
    Uses the [System.Security.Cryptography.X509Certificates.X509FindType] enum.

.PARAMETER Query
    The query string to search for (e.g., thumbprint or subject name, depending on FindType).

.PARAMETER StoreName
    The logical store name to open (e.g., My, Root, CA).
    Uses the [System.Security.Cryptography.X509Certificates.StoreName] enum.

.PARAMETER StoreLocation
    The location of the certificate store (e.g., CurrentUser or LocalMachine).
    Uses the [System.Security.Cryptography.X509Certificates.StoreLocation] enum.

.EXAMPLE
    Find-PodeCertificateInCertStore -FindType Thumbprint -Query 'ABCD1234...' -StoreName My -StoreLocation CurrentUser

    Returns the certificate with the specified thumbprint from the CurrentUser\My store.

.NOTES
    Throws an exception if the platform is not Windows or no matching certificate is found.

    This function is used internally by Pode for loading certificates securely from the Windows cert store.

#>
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


<#
.SYNOPSIS
    Retrieves an X.509 certificate from the certificate store by thumbprint.

.DESCRIPTION
    Searches the specified certificate store (by name and location) for a certificate
    that matches the given thumbprint. Returns the first matching certificate found.

.PARAMETER Thumbprint
    The thumbprint of the certificate to find.

.PARAMETER StoreName
    The name of the certificate store to search (e.g., My, Root, etc.).

.PARAMETER StoreLocation
    The location of the certificate store (e.g., LocalMachine or CurrentUser).

.OUTPUTS
    [System.Security.Cryptography.X509Certificates.X509Certificate2]
    The matching certificate, if found.

.NOTES
    Internal Pode function - subject to change without notice.
#>
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

<#
.SYNOPSIS
    Retrieves an X.509 certificate from the certificate store by subject name.

.DESCRIPTION
    Searches the specified certificate store (by name and location) for a certificate
    that matches the given subject name. Returns the first matching certificate found.

.PARAMETER Name
    The subject name of the certificate to find.

.PARAMETER StoreName
    The name of the certificate store to search (e.g., My, Root, etc.).

.PARAMETER StoreLocation
    The location of the certificate store (e.g., LocalMachine or CurrentUser).

.OUTPUTS
    [System.Security.Cryptography.X509Certificates.X509Certificate2]
    The matching certificate, if found.

.NOTES
    Internal Pode function - subject to change without notice.
#>
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