<#
.SYNOPSIS
  Generates a certificate signing request (CSR) and private key.

.DESCRIPTION
  This function creates a certificate signing request (CSR) using RSA or ECDSA key pairs.
  It allows specifying subject details, key usage, enhanced key usage (EKU), and custom extensions.
  The CSR and private key are automatically saved to files in the specified output directory.

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

.PARAMETER NotBefore
  The NotBefore date for the certificate request. Defaults to the current UTC time.

.PARAMETER CustomExtensions
  An array of additional custom certificate extensions.

.PARAMETER FriendlyName
  An optional friendly name for the certificate request.

.PARAMETER OutputPath
  The directory where the CSR and private key files will be saved. Defaults to the current working directory.

.OUTPUTS
  [PSCustomObject]
  Returns an object containing:
    - CsrPath: The file path of the CSR.
    - PrivateKeyPath: The file path of the private key.

.EXAMPLE
  $csr = New-PodeCertificateRequest -DnsName "example.com" -CommonName "example.com" -KeyType "RSA" -KeyLength 2048
  Generates an RSA CSR for "example.com" and saves it to the current working directory.

.EXAMPLE
  $csr = New-PodeCertificateRequest -DnsName "example.com" -KeyType "ECDSA" -KeyLength 384 -CertificatePurpose "ServerAuth" -OutputPath "C:\Certs"
  Generates an ECDSA CSR with an automatically assigned EKU for server authentication and saves it to "C:\Certs".

.NOTES
  - This function integrates with Pode’s certificate handling utilities.
  - The private key is exported in PKCS#8 format.
  - Ensure the private key is stored securely.
#>
function New-PodeCertificateRequest {
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
        [string[]]$EnhancedKeyUsages,

        # Optional NotBefore date for the certificate request.
        [Parameter()]
        [DateTime]$NotBefore = ([datetime]::UtcNow),

        # Additional custom extensions (as an array of certificate extension objects).
        [Parameter()]
        [object[]]$CustomExtensions,

        # Optional friendly name for display in certificate stores.
        [Parameter()]
        [string]$FriendlyName,

        [Parameter()]
        [string]$OutputPath = $PWD
    )
    # Call the certificate request function to generate the CSR and key pair.
    $csrParams = @{
        DnsName           = $DnsName
        CommonName        = $CommonName
        Organization      = $Organization
        Locality          = $Locality
        State             = $State
        Country           = $Country
        KeyType           = $KeyType
        KeyLength         = $KeyLength
        EnhancedKeyUsages = $EnhancedKeyUsages
        NotBefore         = $NotBefore
        CustomExtensions  = $CustomExtensions
        FriendlyName      = $FriendlyName
    }

    # Define the encoding based on the powershell edition
    $encoding = if ($PSVersionTable.PSEdition -eq 'Core') {
        'utf8NoBOM'
    }
    else {
        'utf8'
    }

    $csrObject = New-PodeCertificateRequestInternal @csrParams


    $csrPath = Join-Path -Path $OutputPath -ChildPath "$CommonName.csr"
    $keyPath = Join-Path -Path $OutputPath -ChildPath "$CommonName.key"

    $csrObject.Request | Out-File -FilePath $csrPath -Encoding $encoding
    $privateKeyBytes = $csrObject.PrivateKey.ExportPkcs8PrivateKey()
    $privateKeyBase64 = [Convert]::ToBase64String($privateKeyBytes)

    "-----BEGIN PRIVATE KEY-----`n$privateKeyBase64`n-----END PRIVATE KEY-----" | Out-File -FilePath $keyPath -Encoding $encoding

    Write-Verbose "CSR saved to: $csrPath"
    Write-Verbose "Private Key saved to: $keyPath"

    return [PSCustomObject]@{
        PsTypeName     = 'PodeCertificateRequestResult'
        CsrPath        = $csrPath
        PrivateKeyPath = $keyPath
    }

}

<#
.SYNOPSIS
  Generates a self-signed X.509 certificate.

.DESCRIPTION
  This function creates a self-signed X.509 certificate using RSA or ECDSA key pairs.
  It supports specifying subject details, key usage, enhanced key usage (EKU),
  and custom extensions. The generated certificate is returned as an X509Certificate2 object.

  By default, the private key is exportable so the certificate can be saved and reused.
  If the `-Ephemeral` parameter is specified, the certificate's private key **will not be persisted**
  and will only exist in memory for the current session.

.PARAMETER DnsName
  One or more DNS names (or IP addresses) to be included in the Subject Alternative Name (SAN).

.PARAMETER Loopback
  If specified, automatically sets `DnsName` to include:
    - `127.0.0.1`, `::1`, `localhost`
    - The current machine's IP (if not local)
    - The Pode server's hostname and FQDN (if available)

.PARAMETER CommonName
  The Common Name (CN) for the certificate subject. Defaults to "SelfSigned".

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

.PARAMETER EnhancedKeyUsages
  A list of OID strings for Enhanced Key Usage (EKU), e.g., '1.3.6.1.5.5.7.3.1' for server authentication.

.PARAMETER CertificatePurpose
  The intended purpose of the certificate, which automatically sets the EKU.
  Supported values: 'ServerAuth', 'ClientAuth', 'CodeSigning', 'EmailSecurity', 'Custom'.
  Defaults to 'ServerAuth'.

.PARAMETER NotBefore
  The NotBefore date for the certificate validity start. Defaults to the current UTC time.

.PARAMETER CustomExtensions
  An array of additional custom certificate extensions.

.PARAMETER FriendlyName
  A friendly name for the certificate, used when storing it in a certificate store. Defaults to 'MyCertificate'.

.PARAMETER ValidityDays
  The number of days the certificate will remain valid. Defaults to 365 days.

.PARAMETER Ephemeral
  If specified, the certificate will be created with `EphemeralKeySet`, meaning the private key
  will **not be persisted** on disk or in the certificate store.

  This is useful for temporary certificates that should only exist in memory for the duration
  of the current session. Once the process exits, the private key will be lost.

.PARAMETER Password
 Specifies an optional password for protecting the exported PFX. If not provided, the PFX will be unprotected.

.PARAMETER Exportable
 If specified the certificate will be created with `Exportable`, meaning the certificate can be exported

.OUTPUTS
  [System.Security.Cryptography.X509Certificates.X509Certificate2]
  Returns the generated self-signed certificate as an X509Certificate2 object.

.EXAMPLE
  $cert = New-PodeSelfSignedCertificate -Loopback
  Creates a self-signed certificate for local addresses (`127.0.0.1`, `::1`, `localhost`, machine hostname).

.EXAMPLE
  $cert = New-PodeSelfSignedCertificate -DnsName "example.com" -KeyType "RSA" -KeyLength 2048
  Creates a self-signed RSA certificate for "example.com" with a 2048-bit key, valid for 365 days.

.EXAMPLE
  $cert = New-PodeSelfSignedCertificate -DnsName "internal.local" -Ephemeral
  Creates a self-signed certificate with a private key that exists **only in memory** for the current session.

.EXAMPLE
  $cert = New-PodeSelfSignedCertificate -DnsName "testserver.local" -KeyType "ECDSA" -KeyLength 384 -CertificatePurpose "ClientAuth" -ValidityDays 730
  Generates a self-signed ECDSA certificate for "testserver.local" with client authentication EKU, valid for 730 days.

.NOTES
  - The private key is embedded in the generated certificate.
  - By default, the certificate is **exportable** so it can be saved and reused.
  - If `-Ephemeral` is used, the private key will **only exist in memory** and cannot be exported or stored.
  - The `-Loopback` parameter is useful for local development, ensuring the certificate includes local identifiers.
#>
function New-PodeSelfSignedCertificate {
    [CmdletBinding(DefaultParameterSetName = 'CommonName')]
    [OutputType([System.Security.Cryptography.X509Certificates.X509Certificate2])]
    param (
        # Required: one or more DNS names (or IP addresses)
        [Parameter(Mandatory = $false, ParameterSetName = 'DnsName')]
        [string[]]
        $DnsName,

        [Parameter(Mandatory = $false, ParameterSetName = 'DnsName')]
        [switch]
        $Loopback,

        # Subject parts
        [Parameter(Mandatory = $false, ParameterSetName = 'CommonName')]
        [string]
        $CommonName = 'SelfSigned',

        [Parameter()]
        [securestring]
        $Password = $null,

        [Parameter()]
        [string]$Organization,
        [Parameter()]
        [string]$Locality,
        [Parameter()]
        [string]$State,
        [Parameter()]
        [string]$Country = 'XX',

        # Key type and size
        [Parameter()]
        [ValidateSet('RSA', 'ECDSA')]
        [string]
        $KeyType = 'RSA',

        [Parameter()]
        [ValidateSet(2048, 3072, 4096, 256, 384, 521)]
        [int]
        $KeyLength = 2048,

        # Enhanced Key Usages (EKU) - e.g., '1.3.6.1.5.5.7.3.1' for server auth
        [Parameter()]
        [string[]]$EnhancedKeyUsages,

        [Parameter()]
        [ValidateSet('ServerAuth', 'ClientAuth', 'CodeSigning', 'EmailSecurity', 'Custom')]
        [string]
        $CertificatePurpose = 'ServerAuth',

        # Optional NotBefore date for certificate validity start
        [Parameter()]
        [DateTime]
        $NotBefore,

        # Additional custom extensions (as an array of extension objects)
        [Parameter()]
        [object[]]
        $CustomExtensions,

        # Friendly name for display in certificate stores
        [Parameter()]
        [string]
        $FriendlyName = 'MyCertificate',

        # Validity period (in days)
        [Parameter()]
        [int]
        $ValidityDays = 365,

        [Parameter()]
        [switch]
        $Ephemeral,

        [Parameter()]
        [switch]
        $Exportable

    )

    # Handle Loopback Parameter
    if ($Loopback) {
        if ($null -eq $DnsName) {
            $DnsName = @()
        }
        if ($DnsName -notcontains '127.0.0.1') {
            $DnsName += '127.0.0.1'
        }
        if ($DnsName -notcontains '::1') {
            $DnsName += '::1'
        }
        if ($DnsName -notcontains 'localhost') {
            $DnsName += 'localhost'
        }

        # Add machine-specific names if available
        if ((![string]::IsNullOrWhiteSpace($PodeContext.Server.ComputerName) ) -and ($DnsName -notcontains $PodeContext.Server.ComputerName)) {
            $DnsName += $PodeContext.Server.ComputerName
        }
        # Add machine-specific fqdn if available
        if ((![string]::IsNullOrWhiteSpace($PodeContext.Server.Fqdn)) -and
            ($PodeContext.Server.Fqdn -ne $PodeContext.Server.ComputerName) -and ($DnsName -notcontains $PodeContext.Server.Fqdn)) {
            $DnsName += $PodeContext.Server.Fqdn
        }
    }

    # Call the certificate request function to generate the CSR and key pair.
    $csrParams = @{
        DnsName            = $DnsName
        CommonName         = $CommonName
        Organization       = $Organization
        Locality           = $Locality
        State              = $State
        Country            = $Country
        KeyType            = $KeyType
        KeyLength          = $KeyLength
        CertificatePurpose = $CertificatePurpose
        EnhancedKeyUsages  = $EnhancedKeyUsages
        CustomExtensions   = $CustomExtensions
    }

    $csrObject = New-PodeCertificateRequestInternal @csrParams

    # Determine certificate validity dates.
    if ($null -eq $NotBefore) { $NotBefore = ([datetime]::UtcNow) }
    $startDate = $NotBefore
    $endDate = $NotBefore.AddDays($ValidityDays)

    try {
        # Create the self-signed certificate from the CSR.
        $cert = $csrObject.CertificateRequest.CreateSelfSigned(
            [System.DateTimeOffset]::new($startDate),
            [System.DateTimeOffset]::new($endDate)
        )

        # Set the friendly name if provided.
        if (![string]::IsNullOrEmpty($FriendlyName) -and (Test-PodeIsWindows)) {
            $cert.FriendlyName = $FriendlyName
        }

        # Export the certificate as a PFX (with a default password; adjust as needed).
        $pfxBytes = $cert.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Pfx , $Password)

        if ($Ephemeral -and !$IsMacOS) {
            $storageFlags = [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::EphemeralKeySet
        }
        else {
            $storageFlags = [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::DefaultKeySet
        }

        if ($Exportable) {
            $storageFlags = $storageFlags -bor [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable
        }
        $finalCert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new(
            $pfxBytes,
            $Password,
            $storageFlags
        )
        return $finalCert
    }
    catch {
        $_ | Write-PodeErrorLog
        throw
    }
}

<#
.SYNOPSIS
  Imports an X.509 certificate from a file (PFX, PEM, CER) or retrieves it from the Windows certificate store.

.DESCRIPTION
  This function imports an X.509 certificate using one of three methods:
    - From a certificate file (PFX, PEM, or CER).
    - From the Windows certificate store by thumbprint.
    - From the Windows certificate store by subject name.

  By default, the certificate is imported with an **ephemeral key**, meaning the private key
  exists **only for the current session** and is not persisted. If the `-Persistent` flag is
  specified, the private key will be stored in an exportable format.

.PARAMETER Path
  The path to the certificate file (.pfx, .pem, or .cer) to import.

.PARAMETER PrivateKeyPath
  The path to a separate private key file (for PEM format).
  Required if the certificate file does not contain the private key.

.PARAMETER CertificatePassword
  A secure string containing the password for decrypting a PFX certificate
  or an encrypted private key in PEM format.

.PARAMETER Exportable
  If specified, the certificate will be imported with an **exportable** private key,
  allowing it to be saved and reused across sessions.

  If not specified, the certificate will be imported **ephemerally**, meaning the
  private key will exist **only in memory** and will be lost when the process exits.

.PARAMETER CertificateThumbprint
  The thumbprint of a certificate stored in the Windows certificate store.

.PARAMETER CertificateName
  The subject name of a certificate stored in the Windows certificate store.

.PARAMETER CertificateStoreName
  The name of the Windows certificate store to search in when retrieving a certificate
  by thumbprint or subject name. Defaults to "My".

.PARAMETER CertificateStoreLocation
  The location of the Windows certificate store. Defaults to "CurrentUser".

.OUTPUTS
  [System.Security.Cryptography.X509Certificates.X509Certificate2]
  Returns the imported certificate as an X509Certificate2 object.

.EXAMPLE
  $cert = Import-PodeCertificate -Path "C:\Certs\mycert.pfx" -CertificatePassword (ConvertTo-SecureString -String "MyPass" -AsPlainText -Force)
  Imports a PFX certificate file with an ephemeral private key.

.EXAMPLE
  $cert = Import-PodeCertificate -Path "C:\Certs\mycert.pfx" -CertificatePassword (ConvertTo-SecureString -String "MyPass" -AsPlainText -Force) -Persistent
  Imports a PFX certificate file **with a persistent private key**, allowing it to be saved.

.EXAMPLE
  $cert = Import-PodeCertificate -Path "C:\Certs\mycert.cer"
  Imports a CER certificate file (public key only).

.EXAMPLE
  $cert = Import-PodeCertificate -CertificateThumbprint "D2C2F4F7A456B69D4F9E9F8C3D3D6E5A9C3EBA6F"
  Retrieves a certificate from the Windows certificate store using its thumbprint.

.EXAMPLE
  $cert = Import-PodeCertificate -CertificateName "MyAppCert" -CertificateStoreName "Root" -CertificateStoreLocation "LocalMachine"
  Retrieves a certificate by subject name from the LocalMachine\Root store.

.NOTES
  - The `-Persistent` flag should be used when you need to store the certificate for future use.
  - The default behavior (`EphemeralKeySet`) ensures the private key does not persist in the system.
  - When using a PEM certificate, ensure the private key is available if required.
  - Windows certificate store retrieval is only supported on Windows systems.
  - CER files contain only the public key and do not support private key decryption.
  - The improrted Certificate is not validated and returned as is.
#>
function Import-PodeCertificate {
    param (
        # Certificate-based parameters for RSA/ECDSA
        [Parameter(Mandatory = $true, ParameterSetName = 'CertFile')]
        [string]
        $Path,

        [Parameter(Mandatory = $false, ParameterSetName = 'CertFile')]
        [string]
        $PrivateKeyPath = $null,

        [Parameter(Mandatory = $false, ParameterSetName = 'CertFile')]
        [SecureString]
        $CertificatePassword,

        [Parameter(Mandatory = $false, ParameterSetName = 'CertFile')]
        [Parameter()]
        [switch]$Exportable,

        [Parameter(Mandatory = $true, ParameterSetName = 'CertThumb')]
        [string]
        $CertificateThumbprint,

        [Parameter(Mandatory = $true, ParameterSetName = 'CertName')]
        [string]
        $CertificateName,

        [Parameter(ParameterSetName = 'CertName')]
        [Parameter(ParameterSetName = 'CertThumb')]
        [System.Security.Cryptography.X509Certificates.StoreName]
        $CertificateStoreName = 'My',

        [Parameter(ParameterSetName = 'CertName')]
        [Parameter(ParameterSetName = 'CertThumb')]
        [System.Security.Cryptography.X509Certificates.StoreLocation]
        $CertificateStoreLocation = 'CurrentUser'
    )

    switch ($PSCmdlet.ParameterSetName) {
        'CertFile' {
            # If using a file-based certificate, ensure it exists, then load it
            if (!(Test-Path -Path $Path -PathType Leaf)) {
                throw ($PodeLocale.pathNotExistExceptionMessage -f $Path)
            }
            if (![string]::IsNullOrEmpty($PrivateKeyPath) -and !(Test-Path -Path $PrivateKeyPath -PathType Leaf)) {
                throw ($PodeLocale.pathNotExistExceptionMessage -f $PrivateKeyPath)
            }
            $X509Certificate = Get-PodeCertificateByFile -Certificate $Path -SecurePassword $CertificatePassword -PrivateKeyPath $PrivateKeyPath -Exportable:$Exportable
            break
        }

        'certthumb' {
            # Retrieve a certificate from the local store by thumbprint
            $X509Certificate = Get-PodeCertificateByThumbprint -Thumbprint $CertificateThumbprint -StoreName $CertificateStoreName -StoreLocation $CertificateStoreLocation
        }

        'certname' {
            # Retrieve a certificate from the local store by name
            $X509Certificate = Get-PodeCertificateByName -Name $CertificateName -StoreName $CertificateStoreName -StoreLocation $CertificateStoreLocation
        }
    }

    return $X509Certificate
}


<#
.SYNOPSIS
  Exports an X.509 certificate to a file (PFX, PEM, or CER) or installs it into the Windows certificate store.

.DESCRIPTION
  This function exports an X.509 certificate in various formats:
    - PFX (PKCS#12) with optional password protection.
    - PEM (Base64-encoded format), optionally including the private key.
    - CER (DER-encoded format).
  It also allows storing the certificate in the Windows certificate store.

  The function supports exporting private keys (if available) for PEM format, encrypting them if a password is provided.

.PARAMETER Certificate
  The X509Certificate2 object to export. This must be a valid certificate.

.PARAMETER Path
  The output file path (without an extension) where the certificate will be saved.
  Defaults to the current working directory with the certificate subject name.

.PARAMETER Format
  The format in which to export the certificate. Supported values: 'PFX', 'PEM', 'CER'.
  Defaults to 'PFX'.

.PARAMETER CertificatePassword
  A secure string containing the password for exporting the PFX format
  or encrypting the private key in PEM format.

.PARAMETER IncludePrivateKey
  When exporting in PEM format, this flag includes the private key in a separate `.key` file.

.PARAMETER CertificateStoreName
  The Windows certificate store name where the certificate should be installed.
  This parameter is required when using the 'WindowsStore' parameter set.

.PARAMETER CertificateStoreLocation
  The location of the Windows certificate store. Defaults to 'CurrentUser'.
  This parameter is required when using the 'WindowsStore' parameter set.

.OUTPUTS
  [string] or [hashtable]
  - If exporting to a file, returns the full file path(s) of the exported certificate.
  - If storing in Windows, returns `$true` if successful, `$false` otherwise.

.EXAMPLE
  $cert = Get-PodeCertificate -Path "mycert.pfx" -Password (ConvertTo-SecureString -String "MyPass" -AsPlainText -Force)
  Export-PodeCertificate -Certificate $cert -Path "C:\Certs\mycert" -Format "PEM" -IncludePrivateKey

  Exports the certificate as a PEM file with a separate private key file.

.EXAMPLE
  $cert = Get-PodeCertificate -Path "mycert.pfx" -Password (ConvertTo-SecureString -String "MyPass" -AsPlainText -Force)
  Export-PodeCertificate -Certificate $cert -CertificateStoreName "My" -CertificateStoreLocation "LocalMachine"

  Stores the certificate in the LocalMachine certificate store under "My".

.NOTES
  - This function integrates with Pode’s certificate handling utilities.
  - Windows store installation is only available on Windows.
  - PEM format supports exporting the private key separately, which can be encrypted with a password.
#>
function Export-PodeCertificate {
    [CmdletBinding(DefaultParameterSetName = 'File')]
    param (
        # The X509 Certificate object to export
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]
        $Certificate,

        [Parameter(Mandatory = $false, ParameterSetName = 'File')]
        [string]
        $Path,

        [Parameter(Mandatory = $false, ParameterSetName = 'File')]
        [ValidateSet('PFX', 'PEM', 'CER')]
        [string]
        $Format = 'PFX',

        [Parameter(Mandatory = $false, ParameterSetName = 'File')]
        [SecureString]
        $CertificatePassword,

        [Parameter(Mandatory = $false, ParameterSetName = 'File')]
        [switch]$IncludePrivateKey,

        [Parameter(Mandatory = $true, ParameterSetName = 'WindowsStore')]
        [System.Security.Cryptography.X509Certificates.StoreName]
        $CertificateStoreName,

        [Parameter(Mandatory = $true, ParameterSetName = 'WindowsStore')]
        [System.Security.Cryptography.X509Certificates.StoreLocation]
        $CertificateStoreLocation = 'CurrentUser'
    )

    process {


        switch ($PSCmdlet.ParameterSetName) {
            'File' {
                if (Test-Path -Path $Path -PathType Container) {
                    # Extract CN (Common Name) from Subject (ensures it only grabs CN=XX)
                    if ($Certificate.Subject -match 'CN=([^,]+)') {
                        $baseName = $matches[1]
                    }
                    else {
                        $baseName = $Certificate.Thumbprint  # Fallback to thumbprint
                    }

                    # Replace invalid filename characters and normalize spaces
                    $baseName = $baseName -replace '[\\/:*?"<>|]', '_' -replace '\s+', '_'

                    $filePath = Join-Path -Path $($PodeContext.Server.Root) -ChildPath $baseName
                }
                else {
                    $filePath = $Path
                }

                switch ($Format) {
                    'PFX' {
                        $pfxBytes = if ($CertificatePassword) {
                            $Certificate.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Pfx, $CertificatePassword)
                        }
                        else {
                            $Certificate.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Pfx)
                        }

                        $filePathWithExt = [PSCustomObject]@{ CertificateFile = "$FilePath.pfx" }
                        [System.IO.File]::WriteAllBytes($filePathWithExt.CertificateFile, $pfxBytes)
                        break
                    }
                    'CER' {
                        $cerBytes = $Certificate.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert)

                        $filePathWithExt = [PSCustomObject]@{ CertificateFile = "$FilePath.cer" }
                        [System.IO.File]::WriteAllBytes($filePathWithExt.CertificateFile, $cerBytes)
                        break
                    }
                    'PEM' {
                        if ($PSVersionTable.PSVersion.Major -lt 7) {
                            throw ($PodeLocale.pemCertificateNotSupportedByPwshVersionExceptionMessage -f $PSVersionTable.PSVersion)
                        }
                        # Export the certificate in PEM format
                        $pemCert = "-----BEGIN CERTIFICATE-----`n"
                        $pemCert += [Convert]::ToBase64String($Certificate.RawData, 'InsertLineBreaks')
                        $pemCert += "`n-----END CERTIFICATE-----"
                        $certFilePath = "$FilePath.pem"
                        $pemCert | Out-File -FilePath $certFilePath -Encoding utf8NoBOM

                        Write-Verbose "Certificate exported successfully: $certFilePath"

                        # If requested, export the private key to a separate file
                        if ($IncludePrivateKey -and $Certificate.HasPrivateKey) {
                            $pemKey = Export-PodePrivateKeyPem -Key $Certificate.PrivateKey -Password $CertificatePassword
                            $keyFilePath = "$FilePath.key"
                            $pemKey | Out-File -FilePath $keyFilePath -Encoding utf8NoBOM

                            Write-Verbose "Private key exported successfully: $keyFilePath"
                        }

                        # Return the certificate file path (and key file path if applicable)
                        $filePathWithExt = if ($IncludePrivateKey -and $Certificate.HasPrivateKey) {
                            [PSCustomObject]@{ CertificateFile = $certFilePath; PrivateKeyFile = $keyFilePath }
                        }
                        else {
                            [PSCustomObject]@{ CertificateFile = $certFilePath }
                        }
                        break
                    }
                }

                if ($Format -ne 'PEM') {
                    Write-Verbose "Certificate exported successfully: $($filePathWithExt.CertificateFile)"
                }
                return  $filePathWithExt
            }

            'WindowsStore' {
                if (Test-PodeIsWindows) {
                    $store = [System.Security.Cryptography.X509Certificates.X509Store]::new($CertificateStoreName, $CertificateStoreLocation)
                    $store.Open('ReadWrite')
                    $store.Add($Certificate)
                    $store.Close()

                    Write-Verbose "Certificate successfully stored in: $CertificateStoreLocation\$CertificateStoreName"
                    return  [PSCustomObject]@{CertificateStore = "$CertificateStoreLocation\$CertificateStoreName" }
                }
                return $null
            }
        }
    }
}

<#
.SYNOPSIS
  Retrieves the Enhanced Key Usage (EKU) purposes of an X.509 certificate.

.DESCRIPTION
  This internal function extracts the Enhanced Key Usage (EKU) extension (OID: 2.5.29.37)
  from an X.509 certificate and returns the recognized purposes.

  If the certificate has no EKU extension, an empty array is returned, indicating
  that the certificate has no usage restrictions.

.PARAMETER Certificate
  The X509Certificate2 object from which to retrieve the EKU purposes.

.OUTPUTS
  [object[]]
  Returns an array of recognized EKU purposes. Supported values:
    - 'ServerAuth'      (1.3.6.1.5.5.7.3.1)
    - 'ClientAuth'      (1.3.6.1.5.5.7.3.2)
    - 'CodeSigning'     (1.3.6.1.5.5.7.3.3)
    - 'EmailSecurity'   (1.3.6.1.5.5.7.3.4)

  If an unrecognized EKU OID is found, it is returned as `"Unknown (<OID>)"`.
  If no EKU extension is present, an empty array is returned.

.EXAMPLE
  $purposes = Get-PodeCertificatePurpose -Certificate $cert
  Retrieves the list of EKU purposes assigned to the given certificate.

#>
function Get-PodeCertificatePurpose {
    [CmdletBinding()]
    [OutputType([object[]])]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate
    )
    process {
        # Define known EKU OIDs and their purposes
        $purposeOids = @{
            '1.3.6.1.5.5.7.3.1' = 'ServerAuth'
            '1.3.6.1.5.5.7.3.2' = 'ClientAuth'
            '1.3.6.1.5.5.7.3.3' = 'CodeSigning'
            '1.3.6.1.5.5.7.3.4' = 'EmailSecurity'
        }

        # Retrieve the EKU extension (OID: 2.5.29.37)
        $ekuExtension = $Certificate.Extensions | Where-Object { $_.Oid.Value -eq '2.5.29.37' }

        if ($ekuExtension -and $ekuExtension -is [System.Security.Cryptography.X509Certificates.X509EnhancedKeyUsageExtension]) {
            # Use the EnhancedKeyUsages property which returns an OidCollection
            $purposes = @()
            foreach ($oid in $ekuExtension.EnhancedKeyUsages) {
                if ($purposeOids.ContainsKey($oid.Value)) {
                    $purposes += $purposeOids[$oid.Value]
                }
                else {
                    $purposes += "Unknown ($($oid.Value))"
                }
            }
            return $purposes
        }

        # If no EKU is present, return an empty array (no restrictions)
        return @()
    }
}

<#
.SYNOPSIS
  Validates an X.509 certificate for both general validity and intended usage.

.DESCRIPTION
  This function performs comprehensive validation on an X.509 certificate. It checks:
    - That the certificate’s validity period (NotBefore and NotAfter) is current.
    - That the certificate chain is valid (including optional revocation checking).
    - That the certificate meets security criteria (e.g. not using weak algorithms).
    - Optionally, that the certificate’s Enhanced Key Usage (EKU) includes the expected purpose.

  New parameters:
    - **ExpectedPurpose**: When provided, the function checks if the certificate’s EKU includes this purpose.
      Valid values: ServerAuth, ClientAuth, CodeSigning, EmailSecurity.
    - **Strict**: When used with ExpectedPurpose, if any unknown EKU is present, validation fails.
    - **AllowWeakAlgorithms**: When specified, certificates using weak algorithms are allowed.
    - **DenySelfSigned**: When specified, self-signed certificates are rejected.

  If any validation step fails, the function writes an error and returns `$false`. Otherwise, it returns `$true`.

.PARAMETER Certificate
  The X509Certificate2 object to validate.

.PARAMETER CheckRevocation
  A switch that enables revocation checking (online or offline).

.PARAMETER OfflineRevocation
  A switch that forces revocation checking to use only cached CRLs.

.PARAMETER AllowWeakAlgorithms
  A switch that, when provided, allows certificates with weak signature algorithms.

.PARAMETER DenySelfSigned
  A switch that, when provided, rejects self-signed certificates.

.PARAMETER ExpectedPurpose
  An optional string specifying the expected Enhanced Key Usage (EKU) for the certificate.
  Valid values: ServerAuth, ClientAuth, CodeSigning, EmailSecurity.
    - 'ServerAuth'      (1.3.6.1.5.5.7.3.1)
    - 'ClientAuth'      (1.3.6.1.5.5.7.3.2)
    - 'CodeSigning'     (1.3.6.1.5.5.7.3.3)
    - 'EmailSecurity'   (1.3.6.1.5.5.7.3.4)

.PARAMETER Strict
  A switch that, when used with ExpectedPurpose, enforces that no unknown EKUs are present.

.OUTPUTS
  [boolean] Returns `$true` if the certificate passes all validation and restriction checks, otherwise `$false`.

.EXAMPLE
  Test-PodeCertificate -Certificate $cert
  Performs basic validity and chain checks on the certificate.

.EXAMPLE
  Test-PodeCertificate -Certificate $cert -CheckRevocation
  Also performs online revocation checking.

.EXAMPLE
  Test-PodeCertificate -Certificate $cert -ExpectedPurpose CodeSigning -Strict
  Validates the certificate and ensures it is explicitly intended for CodeSigning.
#>
function Test-PodeCertificate {
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]
        $Certificate,

        [Parameter()]
        [switch]$CheckRevocation,

        [Parameter()]
        [switch]$OfflineRevocation,

        [Parameter()]
        [switch]$AllowWeakAlgorithms,

        [Parameter()]
        [switch]$DenySelfSigned,

        [Parameter()]
        [ValidateSet('ServerAuth', 'ClientAuth', 'CodeSigning', 'EmailSecurity')]
        [string]$ExpectedPurpose,

        [Parameter()]
        [switch]$Strict
    )
    process {
        # Validate certificate validity period
        $currentDate = [System.DateTime]::UtcNow
        $notBefore = $Certificate.NotBefore.ToUniversalTime()
        $notAfter = $Certificate.NotAfter.ToUniversalTime()

        if ($currentDate -lt $notBefore) {
            Write-Error ($PodeLocale.certificateNotValidYetExceptionMessage -f $Certificate.Subject, $notBefore)
            return $false
        }
        if ($currentDate -gt $notAfter) {
            Write-Error ($PodeLocale.certificateExpiredExceptionMessage -f $Certificate.Subject, $notAfter)
            return $false
        }
        Write-Verbose "Certificate $($Certificate.Subject) is within its valid period."

        # Option: Deny self-signed certificates if requested.
        if ($DenySelfSigned -and ($Certificate.Subject -eq $Certificate.Issuer)) {
            Write-Error $PodeLocale.selfSignedCertificatesNotAllowedExceptionMessage
            return $false
        }

        # For CA-issued certificates, check signature validity.
        # Self-signed certificates: skip signature verification but log a message.
        if ($Certificate.Subject -ne $Certificate.Issuer) {
            if (! $Certificate.Verify()) {
                Write-Error ($PodeLocale.certificateSignatureInvalidExceptionMessage -f $Certificate.Subject)
                return $false
            }
        }
        else {
            Write-Verbose 'Self-signed certificate detected: skipping signature verification.'
        }

        # Initialize the certificate chain.
        $chain = [System.Security.Cryptography.X509Certificates.X509Chain]::new()

        # For self-signed certificates, allow an unknown certificate authority and disable revocation checks.
        if ($Certificate.Subject -eq $Certificate.Issuer) {
            $chain.ChainPolicy.VerificationFlags = [System.Security.Cryptography.X509Certificates.X509VerificationFlags]::AllowUnknownCertificateAuthority
            $CheckRevocation = $false
            Write-Verbose 'Self-signed certificate detected: revocation check disabled.'
        }

        # Apply revocation policy.
        if ($CheckRevocation) {
            $chain.ChainPolicy.RevocationMode = if ($OfflineRevocation) {
                [System.Security.Cryptography.X509Certificates.X509RevocationMode]::Offline
            }
            else {
                [System.Security.Cryptography.X509Certificates.X509RevocationMode]::Online
            }
            Write-Verbose "Revocation checking set to: $($chain.ChainPolicy.RevocationMode)"
        }
        else {
            $chain.ChainPolicy.RevocationMode = [System.Security.Cryptography.X509Certificates.X509RevocationMode]::NoCheck
        }

        # Build the certificate chain.
        $isValidChain = $chain.Build($Certificate)
        if (-not $isValidChain) {
            foreach ($status in $chain.ChainStatus) {
                if ($status.Status -eq [System.Security.Cryptography.X509Certificates.X509ChainStatusFlags]::UntrustedRoot) {
                    Write-Error ($PodeLocale.certificateUntrustedRootExceptionMessage -f $Certificate.Subject)
                    return $false
                }
                if ($status.Status -eq [System.Security.Cryptography.X509Certificates.X509ChainStatusFlags]::Revoked) {
                    Write-Error ($PodeLocale.certificateRevokedExceptionMessage -f $Certificate.Subject, $status.StatusInformation)
                    return $false
                }
                if ($status.Status -eq [System.Security.Cryptography.X509Certificates.X509ChainStatusFlags]::NotTimeValid) {
                    Write-Error ($PodeLocale.certificateExpiredIntermediateExceptionMessage -f $Certificate.Subject)
                    return $false
                }
            }
            Write-Error ($PodeLocale.certificateValidationFailedExceptionMessage -f $Certificate.Subject)
            return $false
        }
        Write-Verbose 'Certificate chain validation successful.'

        # Check for weak algorithms unless weak ones are allowed.
        if (-not $AllowWeakAlgorithms) {
            $weakAlgorithms = @('md5RSA', 'sha1RSA', 'sha1ECDSA', 'RSA-1024')
            if ($Certificate.SignatureAlgorithm.FriendlyName -in $weakAlgorithms) {
                Write-Error ($PodeLocale.certificateWeakAlgorithmExceptionMessage -f $Certificate.Subject, $Certificate.SignatureAlgorithm.FriendlyName)
                return $false
            }
        }

        # If an ExpectedPurpose is provided, check the certificate's EKU restrictions.
        if ($ExpectedPurpose) {
            # Retrieve the EKU values via a helper function.
            $purposes = Get-PodeCertificatePurpose -Certificate $Certificate
            if ($purposes.Count -eq 0 -and ! $Strict) {
                Write-Verbose 'Certificate has no EKU restrictions; it can be used for any purpose.'
            }
            elseif ($ExpectedPurpose -notin $purposes) {
                Write-Error ($PodeLocale.certificateNotValidForPurposeExceptionMessage -f $ExpectedPurpose, ($purposes -join ', '))
                return $false
            }
            if ($Strict -and ($purposes -match '^Unknown')) {
                Write-Error ($PodeLocale.certificateUnknownEkusStrictModeExceptionMessage -f ($purposes -join ', '))
                return $false
            }
            Write-Verbose "Certificate is valid for the expected purpose '$ExpectedPurpose'. Found purposes: $($purposes -join ', ')"
        }

        return $true
    }
}