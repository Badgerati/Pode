@{
    RestFulPort         = 8081
    Protocol            = 'Http'
    Address             = 'localhost'
    Certificate         = 'Certificate.pem'
    CertificateKey      = 'CertificateKey.key'
    CertificatePassword = 'password@01'
    SessionsTtlMinutes  = 360
    SelfSignedCertificate = $false
    Server              = @{
        Timeout                     = 60
        BodySize                    = 100MB
    }
    Web=@{
        OpenApi=@{
            DefaultDefinitionTag = 'v3.0.3'
        }
    }
}