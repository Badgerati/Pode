<#
  .SYNOPSIS
    A PowerShell script to set up a Pode server with JWT authentication and various route configurations.

  .DESCRIPTION
    This script initializes a Pode server that listens on a specified port, enables request and error logging,
    and configures JWT authentication using either the request header or query parameters. It also defines
    a protected route to fetch a list of users, requiring authentication.

  .PARAMETER Location
    Specifies where the API key (JWT token) is expected.
    Valid values: 'Header', 'Query'.
    Default: 'Header'.

  .EXAMPLE
    # Run the sample
    ./WebAuth-bearerJWT.ps1

    JWT payload:
    {
        "sub": "1234567890",
        "name": "morty",
        "username":"morty",
        "type": "Human",
        "id" : "M0R7Y302",
        "admin": true,
        "iat": 1516239022,
        "exp": 2634234231,
        "iss": "auth.example.com",
        "sub": "1234567890",
        "aud": "myapi.example.com",
        "nbf": 1690000000,
        "jti": "unique-token-id",
        "role": "admin"
    }

  .EXAMPLE
    # Example request using PS512 JWT authentication
    $headers = @{
        'Authorization' = 'Bearer eyJhbGciOiJQUzUxMiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6Im1vcnR5IiwidXNlcm5hbWUiOiJtb3J0eSIsInR5cGUiOiJIdW1hbiIsImlkIjoiTTBSN1kzMDIiLCJhZG1pbiI6dHJ1ZSwiaWF0IjoxNTE2MjM5MDIyLCJleHAiOjI2MzQyMzQyMzEsImlzcyI6IlBvZGUiLCJhdWQiOiJXZWJBdXRoLWJlYXJlckpXVC5wczEiLCJuYmYiOjE2OTAwMDAwMDAsImp0aSI6InVuaXF1ZS10b2tlbi1pZCIsInJvbGUiOiJhZG1pbiJ9.Vtkpm8aEtXLF5v79pO3lHyyK0Qh3WOLYD0-5bQfhl82pHCskRRrlh_ODbxXHfXexjCrVZjQdBEexUskEvzKy2vQYHm1Chor__7j2Amjso7ZOOJJ8AENKTguzqLm-Pj4k3t_bdLFJP-e-4Y-IOHlYX3ac0dqkVFB28RwPoYN6UNJ61o0uk-aNk0zTeaptwyxnY4eCU_hQLfZLAAa7e3feDLUR3YXQzwXjNscUQpfjOJqtY3RLVQZ6hdUNn63VdR8GTzeDNYJq-GJjABxFKvOWnYDjFMC605C_83I8KtM1_OOVpQLifp5j7aOjHhAuksLs5NwWk5WlCM2Uc2GVyF6DVA'
        'Accept'        = 'application/json'
    }

    $response = Invoke-RestMethod -Uri 'http://localhost:8081/users' -Method Get -Headers $headers

     .EXAMPLE
    # Example request using RS384 JWT authentication
    $headers = @{
        'Authorization' = 'Bearer eyJhbGciOiJSUzM4NCIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6Im1vcnR5IiwidXNlcm5hbWUiOiJtb3J0eSIsInR5cGUiOiJIdW1hbiIsImlkIjoiTTBSN1kzMDIiLCJhZG1pbiI6dHJ1ZSwiaWF0IjoxNTE2MjM5MDIyLCJleHAiOjI2MzQyMzQyMzEsImlzcyI6IlBvZGUiLCJhdWQiOiJXZWJBdXRoLWJlYXJlckpXVC5wczEiLCJuYmYiOjE2OTAwMDAwMDAsImp0aSI6InVuaXF1ZS10b2tlbi1pZCIsInJvbGUiOiJhZG1pbiJ9.h8oQKzYpRp1Mc5d-U-6HisQ04l4ucQpBn46WLun6goM-rapweVoj4xC3MPJ5nvP8Z5iEu1mxpF3KDskihI_BxOQMffFECleyf6Yw3IPY7IwV5DeEdmMOMSD8XlelxswMUBG_3wBPOuhKmFSN7rmXKbXaFWIC9ggEWNoK0e2B8ccNqaVZ_3EJAYQHpMivWIFBYQ5rav96ZcCoye19kFuLeMDEprtyBYVcdO-wCzEw2O-7BDul3ynhTY9znXGW7qBT7SyEB-VSo1X2lGten-L2w6vL4CA6RXQYeEiokjXw4OCFsnvkj736TrMKZg4WJ3ONsgnkhHavVL7BsTERPdaWeg'
        'Accept'        = 'application/json'
    }

    $response = Invoke-RestMethod -Uri 'http://localhost:8081/users' -Method Get -Headers $headers



  .EXAMPLE
    # Example request using HS256 JWT authentication
    $headers = @{
        'Authorization' = 'Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6Im1vcnR5IiwidXNlcm5hbWUiOiJtb3J0eSIsInR5cGUiOiJIdW1hbiIsImlkIjoiTTBSN1kzMDIiLCJhZG1pbiI6dHJ1ZSwiaWF0IjoxNTE2MjM5MDIyLCJleHAiOjI2MzQyMzQyMzEsImlzcyI6ImF1dGguZXhhbXBsZS5jb20iLCJhdWQiOiJteWFwaS5leGFtcGxlLmNvbSIsIm5iZiI6MTY5MDAwMDAwMCwianRpIjoidW5pcXVlLXRva2VuLWlkIiwicm9sZSI6ImFkbWluIn0.MRZ69oPv2MFNFaihvCAzmjCiFSXbwv1tfvSJJTx29wWUKo82YP-mwF6Asb1cgRyQoGhxKgQVpW2V_x1bdElGKg'
        'Accept'        = 'application/json'
    }

    $response = Invoke-RestMethod -Uri 'http://localhost:8081/users' -Method Get -Headers $headers

  .LINK
    https://github.com/Badgerati/Pode/blob/develop/examples/WebAuth-bearerJWT.ps1

  .NOTES
    - This script uses Pode to create a lightweight web server with authentication.
    - JWT authentication is handled via Bearer tokens passed in either the header or query.
    - Ensure the private key is securely stored and managed for RS256-based JWT signing.
    - Using query parameters for authentication is **discouraged** due to security risks.
    - Always use HTTPS in production to protect sensitive authentication data.

    Author: Pode Team
    License: MIT License
#>

param(
    [Parameter()]
    [ValidateSet('Header', 'Query' )]
    [string]
    $Location = 'Header'
)

try {
    # Determine the script path and Pode module path
    $ScriptPath = (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
    $podePath = Split-Path -Parent -Path $ScriptPath

    # Import the Pode module from the source path if it exists, otherwise from installed modules
    if (Test-Path -Path "$($podePath)/src/Pode.psm1" -PathType Leaf) {
        Import-Module "$($podePath)/src/Pode.psm1" -Force -ErrorAction Stop
    }
    else {
        Import-Module -Name 'Pode' -MaximumVersion 2.99 -ErrorAction Stop
    }
}
catch { throw }

# or just:
# Import-Module Pode

# create a server, and start listening on port 8081
Start-PodeServer -Threads 2 {

    # listen on localhost:8081
    Add-PodeEndpoint -Address localhost -Port 8081 -Protocol Http

    New-PodeLoggingMethod -File -Name 'requests' | Enable-PodeRequestLogging
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging
    $privateKey = ConvertTo-SecureString -Force -AsPlainText -String @'
-----BEGIN PRIVATE KEY-----
MIIEvwIBADANBgkqhkiG9w0BAQEFAASCBKkwggSlAgEAAoIBAQC7VJTUt9Us8cKj
MzEfYyjiWA4R4/M2bS1GB4t7NXp98C3SC6dVMvDuictGeurT8jNbvJZHtCSuYEvu
NMoSfm76oqFvAp8Gy0iz5sxjZmSnXyCdPEovGhLa0VzMaQ8s+CLOyS56YyCFGeJZ
qgtzJ6GR3eqoYSW9b9UMvkBpZODSctWSNGj3P7jRFDO5VoTwCQAWbFnOjDfH5Ulg
p2PKSQnSJP3AJLQNFNe7br1XbrhV//eO+t51mIpGSDCUv3E0DDFcWDTH9cXDTTlR
ZVEiR2BwpZOOkE/Z0/BVnhZYL71oZV34bKfWjQIt6V/isSMahdsAASACp4ZTGtwi
VuNd9tybAgMBAAECggEBAKTmjaS6tkK8BlPXClTQ2vpz/N6uxDeS35mXpqasqskV
laAidgg/sWqpjXDbXr93otIMLlWsM+X0CqMDgSXKejLS2jx4GDjI1ZTXg++0AMJ8
sJ74pWzVDOfmCEQ/7wXs3+cbnXhKriO8Z036q92Qc1+N87SI38nkGa0ABH9CN83H
mQqt4fB7UdHzuIRe/me2PGhIq5ZBzj6h3BpoPGzEP+x3l9YmK8t/1cN0pqI+dQwY
dgfGjackLu/2qH80MCF7IyQaseZUOJyKrCLtSD/Iixv/hzDEUPfOCjFDgTpzf3cw
ta8+oE4wHCo1iI1/4TlPkwmXx4qSXtmw4aQPz7IDQvECgYEA8KNThCO2gsC2I9PQ
DM/8Cw0O983WCDY+oi+7JPiNAJwv5DYBqEZB1QYdj06YD16XlC/HAZMsMku1na2T
N0driwenQQWzoev3g2S7gRDoS/FCJSI3jJ+kjgtaA7Qmzlgk1TxODN+G1H91HW7t
0l7VnL27IWyYo2qRRK3jzxqUiPUCgYEAx0oQs2reBQGMVZnApD1jeq7n4MvNLcPv
t8b/eU9iUv6Y4Mj0Suo/AU8lYZXm8ubbqAlwz2VSVunD2tOplHyMUrtCtObAfVDU
AhCndKaA9gApgfb3xw1IKbuQ1u4IF1FJl3VtumfQn//LiH1B3rXhcdyo3/vIttEk
48RakUKClU8CgYEAzV7W3COOlDDcQd935DdtKBFRAPRPAlspQUnzMi5eSHMD/ISL
DY5IiQHbIH83D4bvXq0X7qQoSBSNP7Dvv3HYuqMhf0DaegrlBuJllFVVq9qPVRnK
xt1Il2HgxOBvbhOT+9in1BzA+YJ99UzC85O0Qz06A+CmtHEy4aZ2kj5hHjECgYEA
mNS4+A8Fkss8Js1RieK2LniBxMgmYml3pfVLKGnzmng7H2+cwPLhPIzIuwytXywh
2bzbsYEfYx3EoEVgMEpPhoarQnYPukrJO4gwE2o5Te6T5mJSZGlQJQj9q4ZB2Dfz
et6INsK0oG8XVGXSpQvQh3RUYekCZQkBBFcpqWpbIEsCgYAnM3DQf3FJoSnXaMhr
VBIovic5l0xFkEHskAjFTevO86Fsz1C2aSeRKSqGFoOQ0tmJzBEs1R6KqnHInicD
TQrKhArgLXX4v3CddjfTRJkFWDbE/CkvKZNOrcf1nhaGCPspRJj2KUkj1Fhl9Cnc
dn/RsYEONbwQSjIfMPkvxF+8HQ==
-----END PRIVATE KEY-----
'@
    $publicKey = @'
-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAu1SU1LfVLPHCozMxH2Mo
4lgOEePzNm0tRgeLezV6ffAt0gunVTLw7onLRnrq0/IzW7yWR7QkrmBL7jTKEn5u
+qKhbwKfBstIs+bMY2Zkp18gnTxKLxoS2tFczGkPLPgizskuemMghRniWaoLcyeh
kd3qqGElvW/VDL5AaWTg0nLVkjRo9z+40RQzuVaE8AkAFmxZzow3x+VJYKdjykkJ
0iT9wCS0DRTXu269V264Vf/3jvredZiKRkgwlL9xNAwxXFg0x/XFw005UWVRIkdg
cKWTjpBP2dPwVZ4WWC+9aGVd+Gyn1o0CLelf4rEjGoXbAAEgAqeGUxrcIlbjXfbc
mwIDAQAB
-----END PUBLIC KEY-----
'@

    # setup bearer auth
    New-PodeAuthScheme -Bearer -BearerLocation $Location -AsJWT -Secret 'your-256-bit-secret' -PrivateKey $privateKey -PublicKey $publicKey | Add-PodeAuth -Name 'Validate' -Sessionless -ScriptBlock {
        param($jwt)

        # here you'd check a real user storage, this is just for example
        if ($jwt.username -ieq 'morty') {
            return @{
                User = @{
                    ID   = $jWt.id
                    Name = $jst.name
                    Type = $jst.type
                }
            }
        }

        return $null
    }

    # GET request to get list of users (since there's no session, authentication will always happen)
    Add-PodeRoute -Method Get -Path '/users' -Authentication 'Validate' -ScriptBlock {

        Write-PodeJsonResponse -Value @{
            Users = @(
                @{
                    Name = 'Deep Thought'
                    Age  = 42
                },
                @{
                    Name = 'Leeroy Jenkins'
                    Age  = 1337
                }
            )
        }
    }

}