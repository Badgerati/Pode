# Certificates

Pode has the ability to generate and bind self-signed certificates (for dev/testing), as well as the ability to bind existing certificates for HTTPS or JWT.

## Setting Up HTTPS in Pode

Pode provides multiple ways to configure HTTPS on [`Add-PodeEndpoint`](../../Functions/Core/Add-PodeEndpoint):

- **File-based certificates:**
  - `-Certificate`: Path to a `.cer` or `.pem` file.
  - `-Certificate` with `-CertificatePassword`: Path to a `.pfx` file and its password.
  - `-Certificate` with `-CertificateKey`: Paths to a certificate/key PEM file pair.
  - `-Certificate`, `-CertificateKey`, and `-CertificatePassword`: Paths to an encrypted PEM file pair and its password.

- **Windows Certificate Store:**
  - `-CertificateThumbprint`: Uses a certificate installed at `Cert:\CurrentUser\My`.
  - `-CertificateName`: Uses a certificate installed at `Cert:\CurrentUser\My` by name.

- **X.509 Certificates:**
  - `-X509Certificate`: Provides a certificate object of type `X509Certificate2`.
  - `-SelfSigned`: Generates a quick self-signed `X509Certificate` for development.

- **Custom Certificate Management:**
  - Pode’s built-in functions allow better control over certificate creation, import, and export.

## Usage

### Generating a Certificate Signing Request (CSR)

To generate a Certificate Signing Request (CSR) along with a private key, use the `New-PodeCertificateRequest` function:

```powershell
$csr = New-PodeCertificateRequest -DnsName "example.com" -CommonName "example.com" -KeyType "RSA" -KeyLength 2048
```

This will create a CSR file and a private key file in the current directory. You can specify additional parameters such as organization details and certificate purposes.

#### Using a CSR to Obtain a Certificate

Once you have generated a CSR, you need to submit it to a **Certificate Authority (CA)** (such as Let's Encrypt, DigiCert, or a private CA) to receive a signed certificate. The process typically involves:

1. Uploading or providing the `.csr` file to the CA.
2. Completing domain validation steps (if required).
3. Receiving the signed certificate (`.cer`, `.pem`, or `.pfx`) from the CA.
4. Importing the signed certificate into Pode for use.

Example: Importing the signed certificate after receiving it from the CA:

```powershell
$cert = Import-PodeCertificate -FilePath "C:\Certs\signed-cert.pfx" -CertificatePassword (ConvertTo-SecureString "MyPass" -AsPlainText -Force)
```

### Exporting a Certificate

Pode allows exporting certificates in various formats such as PFX and PEM. To export a certificate:

```powershell
Export-PodeCertificate -Certificate $cert -FilePath "C:\Certs\mycert" -Format "PFX" -CertificatePassword (ConvertTo-SecureString "MyPass" -AsPlainText -Force)
```

or as a PEM file with a separate private key:

```powershell
Export-PodeCertificate -Certificate $cert -FilePath "C:\Certs\mycert" -Format "PEM" -IncludePrivateKey
```

### Checking a Certificate’s Purpose

A certificate's **purpose** is defined by its **Enhanced Key Usage (EKU)** attributes, which specify what the certificate is allowed to be used for. Common EKU values include:

- `ServerAuth` – Used for server authentication in HTTPS.
- `ClientAuth` – Used for client authentication in mutual TLS setups.
- `CodeSigning` – Used for digitally signing software and scripts.
- `EmailSecurity` – Used for securing email communication.

Pode can extract the EKU of a certificate to determine its intended purposes:

```powershell
$purposes = Get-PodeCertificatePurpose -Certificate $cert
$purposes
```

#### Enforcing Certificate Purpose

When Pode validates a certificate, it ensures that the certificate’s EKU matches the expected usage. If a certificate is used for an endpoint but lacks the required EKU (e.g., using a `CodeSigning` certificate for `ServerAuth`), Pode will reject the certificate and fail to bind it to the endpoint.

For example, if an HTTPS endpoint is created, the certificate **must** include `ServerAuth`:

```powershell
$cert = New-PodeSelfSignedCertificate -DnsName "example.com" -CertificatePurpose ServerAuth

Start-PodeServer {
    Add-PodeEndpoint -Address * -Port 8443 -Protocol Https -X509Certificate $cert
}
```

If the certificate lacks the correct EKU, Pode will return an error when attempting to bind it.

### Importing an Existing Certificate

To import a certificate from a file or the Windows certificate store:

```powershell
$cert = Import-PodeCertificate -FilePath "C:\Certs\mycert.pfx" -CertificatePassword (ConvertTo-SecureString "MyPass" -AsPlainText -Force)
```

or, to retrieve a certificate by thumbprint:

```powershell
$cert = Import-PodeCertificate -CertificateThumbprint "D2C2F4F7A456B69D4F9E9F8C3D3D6E5A9C3EBA6F"
```

## SSL Protocols

The default allowed SSL protocols are SSL3 and TLS1.2 (or just TLS1.2 on MacOS), but you can change these to any of: SSL2, SSL3, TLS, TLS11, TLS12, TLS13. This is specified in your `server.psd1` configuration file:

```powershell
@{
    Server = @{
        Ssl= @{
            Protocols = @('TLS', 'TLS11', 'TLS12')
        }
    }
}
```

## Using Certificates for JWT Authentication

Pode supports using X.509 certificates for JWT authentication. You can specify a certificate for signing and verifying JWTs by providing `-X509Certificate` when creating a bearer authentication scheme:

```powershell
$cert = Import-PodeCertificate -FilePath "C:\Certs\jwt-signing-cert.pfx" -CertificatePassword (ConvertTo-SecureString "MyPass" -AsPlainText -Force)

Start-PodeServer {
    New-PodeAuthBearerScheme `
        -AsJWT `
        -X509Certificate $cert |
    Add-PodeAuth -Name 'JWTAuth' -Sessionless -ScriptBlock {
        param($token)

        # Validate and extract user details
        return @{ User = $user }
    }
}
```

Alternatively, you can use a self-signed certificate for development and testing:

```powershell
Start-PodeServer {
    New-PodeAuthBearerScheme `
        -AsJWT `
        -SelfSigned |
    Add-PodeAuth -Name 'JWTAuth' -Sessionless -ScriptBlock {
        param($token)

        # Validate and extract user details
        return @{ User = $user }
    }
}
```

Using certificates for JWT authentication provides enhanced security by enabling asymmetric signing (RSA/ECDSA) rather than using a shared secret.
