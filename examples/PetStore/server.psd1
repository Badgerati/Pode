@{
    RestFulPort         = 8081
    Protocol            = 'Https'
    Address             = 'localhost'
    Certificate         = 'Certificate.pem'
    CertificateKey      = 'CertificateKey.key'
    CertificatePassword = 'password@01'
    SessionsTtlMinutes  = 360
    Selfsigned          = $true
    Server              = @{
        Timeout  = 60
        BodySize = 100MB
    }
    Web                 = @{
        OpenApi = @{
            DefaultDefinitionTag = 'v3.0.3'
        }
    }
}