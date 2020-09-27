using namespace System.Security.Cryptography

function Test-PodeIPLimit
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        $IP
    )

    $type = 'IP'

    # get the limit rules and active list
    $rules = $PodeContext.Server.Limits.Rules[$type]
    $active = $PodeContext.Server.Limits.Active[$type]

    # if there are no rules, it's valid
    if (($null -eq $rules) -or ($rules.Count -eq 0)) {
        return $true
    }

    # get the ip address in bytes
    $IP = @{
        String = $IP.IPAddressToString
        Family = $IP.AddressFamily
        Bytes = $IP.GetAddressBytes()
    }

    # now
    $now = [DateTime]::UtcNow

    # is the ip active? (get a direct match, then try grouped subnets)
    $_active_ip = $active[$IP.String]
    if ($null -eq $_active_ip) {
        $_groups = @(foreach ($key in $active.Keys) {
            if ($active[$key].Rule.Grouped) {
                $active[$key]
            }
        })

        $_active_ip = @(foreach ($_group in $_groups) {
            if (Test-PodeIPAddressInRange -IP $IP -LowerIP $_group.Rule.Lower -UpperIP $_group.Rule.Upper) {
                $_group
                break
            }
        })[0]
    }

    # the ip is active, or part of a grouped subnet
    if ($null -ne $_active_ip) {
        # if limit is -1, always allowed
        if ($_active_ip.Rule.Limit -eq -1) {
            return $true
        }

        # check expire time, a reset if needed
        if ($now -ge $_active_ip.Expire) {
            $_active_ip.Rate = 0
            $_active_ip.Expire = $now.AddSeconds($_active_ip.Rule.Seconds)
        }

        # are we over the limit?
        if ($_active_ip.Rate -ge $_active_ip.Rule.Limit) {
            return $false
        }

        # increment the rate
        $_active_ip.Rate++
        return $true
    }

    # the ip isn't active
    else {
        # get the ip's rule
        $_rule_ip = @(foreach ($rule in $rules.Values) {
            if (Test-PodeIPAddressInRange -IP $IP -LowerIP $rule.Lower -UpperIP $rule.Upper) {
                $rule
                break
            }
        })[0]

        # if ip not in rules, it's valid
        # (add to active list as always allowed - saves running where search everytime)
        if ($null -eq $_rule_ip) {
            $active.Add($IP.String, @{
                Rule = @{
                    Limit = -1
                }
            })

            return $true
        }

        # add ip to active list (ip if not grouped, else the subnet if it's grouped)
        $_ip = (Resolve-PodeValue -Check $_rule_ip.Grouped -TrueValue $_rule_ip.IP -FalseValue $IP.String)

        $active.Add($_ip, @{
            Rule = $_rule_ip
            Rate = 1
            Expire = $now.AddSeconds($_rule_ip.Seconds)
        })

        # if limit is 0, it's never allowed
        return ($_rule_ip -ne 0)
    }
}

function Test-PodeIPAccess
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        $IP
    )

    $type = 'IP'

    # get permission lists for ip
    $allow = $PodeContext.Server.Access.Allow[$type]
    $deny = $PodeContext.Server.Access.Deny[$type]

    # are they empty?
    $alEmpty = (($null -eq $allow) -or ($allow.Count -eq 0))
    $dnEmpty = (($null -eq $deny) -or ($deny.Count -eq 0))

    # if both are empty, value is valid
    if ($alEmpty -and $dnEmpty) {
        return $true
    }

    # get the ip address in bytes
    $IP = @{
        Family = $IP.AddressFamily
        Bytes = $IP.GetAddressBytes()
    }

    # if value in allow, it's allowed
    if (!$alEmpty) {
        $match = @(foreach ($value in $allow.Values) {
            if (Test-PodeIPAddressInRange -IP $IP -LowerIP $value.Lower -UpperIP $value.Upper) {
                $value
                break
            }
        })[0]

        if ($null -ne $match) {
            return $true
        }
    }

    # if value in deny, it's disallowed
    if (!$dnEmpty) {
        $match = @(foreach ($value in $deny.Values) {
            if (Test-PodeIPAddressInRange -IP $IP -LowerIP $value.Lower -UpperIP $value.Upper) {
                $value
                break
            }
        })[0]

        if ($null -ne $match) {
            return $false
        }
    }

    # if we have an allow, it's disallowed (because it's not in there)
    if (!$alEmpty) {
        return $false
    }

    # otherwise it's allowed (because it's not in the deny)
    return $true
}

function Add-PodeIPLimit
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [string]
        $IP,

        [Parameter(Mandatory=$true)]
        [int]
        $Limit,

        [Parameter(Mandatory=$true)]
        [int]
        $Seconds,

        [switch]
        $Group
    )

    # current limit type
    $type = 'IP'

    # ensure limit and seconds are non-zero and negative
    if ($Limit -le 0) {
        throw "Limit value cannot be 0 or less for $($IP)"
    }

    if ($Seconds -le 0) {
        throw "Seconds value cannot be 0 or less for $($IP)"
    }

    # get current rules
    $rules = $PodeContext.Server.Limits.Rules[$type]

    # setup up perm type
    if ($null -eq $rules) {
        $PodeContext.Server.Limits.Rules[$type] = @{}
        $PodeContext.Server.Limits.Active[$type] = @{}
        $rules = $PodeContext.Server.Limits.Rules[$type]
    }

    # have we already added the ip?
    elseif ($rules.ContainsKey($IP)) {
        return
    }

    # calculate the lower/upper ip bounds
    if (Test-PodeIPAddressIsSubnetMask -IP $IP) {
        $_tmp = Get-PodeSubnetRange -SubnetMask $IP
        $_tmpLo = Get-PodeIPAddress -IP $_tmp.Lower
        $_tmpHi = Get-PodeIPAddress -IP $_tmp.Upper
    }
    elseif (Test-PodeIPAddressAny -IP $IP) {
        $_tmpLo = Get-PodeIPAddress -IP '0.0.0.0'
        $_tmpHi = Get-PodeIPAddress -IP '255.255.255.255'
    }
    else {
        $_tmpLo = Get-PodeIPAddress -IP $IP
        $_tmpHi = $_tmpLo
    }

    # add limit rule for ip
    $rules.Add($IP, @{
        Limit = $Limit
        Seconds = $Seconds
        Grouped = [bool]$Group
        IP = $IP
        Lower = @{
            Family = $_tmpLo.AddressFamily
            Bytes = $_tmpLo.GetAddressBytes()
        }
        Upper = @{
            Family = $_tmpHi.AddressFamily
            Bytes = $_tmpHi.GetAddressBytes()
        }
    })
}

function Add-PodeRouteLimit
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [string]
        $Path,

        [Parameter(Mandatory=$true)]
        [int]
        $Limit,

        [Parameter(Mandatory=$true)]
        [int]
        $Seconds,

        [switch]
        $Group
    )

    # current limit type
    $type = 'Route'

    # ensure limit and seconds are non-zero and negative
    if ($Limit -le 0) {
        throw "Limit value cannot be 0 or less for $($IP)"
    }

    if ($Seconds -le 0) {
        throw "Seconds value cannot be 0 or less for $($IP)"
    }

    # get current rules
    $rules = $PodeContext.Server.Limits.Rules[$type]

    # setup up perm type
    if ($null -eq $rules) {
        $PodeContext.Server.Limits.Rules[$type] = @{}
        $PodeContext.Server.Limits.Active[$type] = @{}
        $rules = $PodeContext.Server.Limits.Rules[$type]
    }

    # have we already added the route?
    elseif ($rules.ContainsKey($Path)) {
        return
    }

    # add limit rule for the route
    $rules.Add($Path, @{
        Limit = $Limit
        Seconds = $Seconds
        Grouped = [bool]$Group
        Path = $Path
    })
}

function Add-PodeEndpointLimit
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [string]
        $EndpointName,

        [Parameter(Mandatory=$true)]
        [int]
        $Limit,

        [Parameter(Mandatory=$true)]
        [int]
        $Seconds,

        [switch]
        $Group
    )

    # current limit type
    $type = 'Endpoint'

    # ensure limit and seconds are non-zero and negative
    if ($Limit -le 0) {
        throw "Limit value cannot be 0 or less for $($IP)"
    }

    if ($Seconds -le 0) {
        throw "Seconds value cannot be 0 or less for $($IP)"
    }

    # get current rules
    $rules = $PodeContext.Server.Limits.Rules[$type]

    # setup up perm type
    if ($null -eq $rules) {
        $PodeContext.Server.Limits.Rules[$type] = @{}
        $PodeContext.Server.Limits.Active[$type] = @{}
        $rules = $PodeContext.Server.Limits.Rules[$type]
    }

    # have we already added the endpoint?
    elseif ($rules.ContainsKey($EndpointName)) {
        return
    }

    # add limit rule for the endpoint
    $rules.Add($Path, @{
        Limit = $Limit
        Seconds = $Seconds
        Grouped = [bool]$Group
        EndpointName = $EndpointName
    })
}

function Add-PodeIPAccess
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet('Allow', 'Deny')]
        [string]
        $Access,

        [Parameter(Mandatory=$true)]
        [string]
        $IP
    )

    # current access type
    $type = 'IP'

    # get opposite permission
    $opp = "$(if ($Access -ieq 'allow') { 'Deny' } else { 'Allow' })"

    # get permission lists for type
    $permType = $PodeContext.Server.Access[$Access][$type]
    $oppType = $PodeContext.Server.Access[$opp][$type]

    # setup up perm type
    if ($null -eq $permType) {
        $PodeContext.Server.Access[$Access][$type] = @{}
        $permType = $PodeContext.Server.Access[$Access][$type]
    }

    # have we already added the ip?
    elseif ($permType.ContainsKey($IP)) {
        return
    }

    # remove from opp type
    if ($null -ne $oppType -and $oppType.ContainsKey($IP)) {
        $oppType.Remove($IP)
    }

    # calculate the lower/upper ip bounds
    if (Test-PodeIPAddressIsSubnetMask -IP $IP) {
        $_tmp = Get-PodeSubnetRange -SubnetMask $IP
        $_tmpLo = Get-PodeIPAddress -IP $_tmp.Lower
        $_tmpHi = Get-PodeIPAddress -IP $_tmp.Upper
    }
    elseif (Test-PodeIPAddressAny -IP $IP) {
        $_tmpLo = Get-PodeIPAddress -IP '0.0.0.0'
        $_tmpHi = Get-PodeIPAddress -IP '255.255.255.255'
    }
    else {
        $_tmpLo = Get-PodeIPAddress -IP $IP
        $_tmpHi = $_tmpLo
    }

    # add access rule for ip
    $permType.Add($IP, @{
        Lower = @{
            Family = $_tmpLo.AddressFamily
            Bytes = $_tmpLo.GetAddressBytes()
        }
        Upper = @{
            Family = $_tmpHi.AddressFamily
            Bytes = $_tmpHi.GetAddressBytes()
        }
    })
}

function Get-PodeCsrfToken
{
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

function Test-PodeCsrfToken
{
    param (
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

function New-PodeCsrfSecret
{
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

function Get-PodeCsrfSecret
{
    # key name to get secret
    $key = $PodeContext.Server.Cookies.Csrf.Name

    # are we getting it from a cookie, or session?
    if ($PodeContext.Server.Cookies.Csrf.UseCookies) {
        return (Get-PodeCookie `
            -Name $PodeContext.Server.Cookies.Csrf.Name `
            -Secret $PodeContext.Server.Cookies.Csrf.Secret).Value
    }

    # on session
    else {
        return $WebEvent.Session.Data[$key]
    }
}

function Set-PodeCsrfSecret
{
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Secret
    )

    # key name to set secret under
    $key = $PodeContext.Server.Cookies.Csrf.Name

    # are we setting this on a cookie, or session?
    if ($PodeContext.Server.Cookies.Csrf.UseCookies) {
        (Set-PodeCookie `
            -Name $PodeContext.Server.Cookies.Csrf.Name `
            -Value $Secret `
            -Secret $PodeContext.Server.Cookies.Csrf.Secret) | Out-Null
    }

    # on session
    else {
        $WebEvent.Session.Data[$key] = $Secret
    }
}

function Restore-PodeCsrfToken
{
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Secret,

        [Parameter(Mandatory=$true)]
        [string]
        $Salt
    )

    return "t:$($Salt).$(Invoke-PodeSHA256Hash -Value "$($Salt)-$($Secret)")"
}

function Test-PodeCsrfConfigured
{
    return (!(Test-PodeIsEmpty $PodeContext.Server.Cookies.Csrf))
}

function Get-PodeCertificateByFile
{
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Certificate,

        [Parameter()]
        [string]
        $Password = $null
    )

    $path = Get-PodeRelativePath -Path $Certificate -JoinRoot -Resolve
    $cert = $null

    if ([string]::IsNullOrWhiteSpace($Password)) {
        $cert = [X509Certificates.X509Certificate2]::new($path)
    }
    else {
        $cert = [X509Certificates.X509Certificate2]::new($path, $Password)
    }

    return $cert
}

function Find-PodeCertificateInCertStore
{
    param(
        [Parameter(Mandatory=$true)]
        [X509Certificates.X509FindType]
        $FindType,

        [Parameter(Mandatory=$true)]
        [string]
        $Query
    )

    # fail if not windows
    if (!(Test-PodeIsWindows)) {
        throw "Certificate Thumbprints/Name are only supported on Windows"
    }

    # open the currentuser\my store
    $x509store = [X509Certificates.X509Store]::new(
        [X509Certificates.StoreName]::My,
        [X509Certificates.StoreLocation]::CurrentUser
    )

    try {
        # attempt to find the cert
        $x509store.Open([X509Certificates.OpenFlags]::ReadOnly)
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
        throw "No certificate could be found in CurrentUser\My for '$($Thumbprint)'"
    }

    return ([X509Certificates.X509Certificate2]($x509certs[0]))
}

function Get-PodeCertificateByThumbprint
{
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Thumbprint
    )

    return (Find-PodeCertificateInCertStore -FindType [X509FindType]::FindByThumbprint -Query $Thumbprint)
}

function Get-PodeCertificateByName
{
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Name
    )

    return (Find-PodeCertificateInCertStore -FindType [X509FindType]::FindBySubjectName -Query $Name)
}

function New-PodeSelfSignedCertificate
{
    $sanBuilder = [X509Certificates.SubjectAlternativeNameBuilder]::new()
    $sanBuilder.AddIpAddress([ipaddress]::Loopback) | Out-Null
    $sanBuilder.AddIpAddress([ipaddress]::IPv6Loopback) | Out-Null
    $sanBuilder.AddDnsName('localhost') | Out-Null

    if (![string]::IsNullOrWhiteSpace($env:COMPUTERNAME)) {
        $sanBuilder.AddDnsName($env:COMPUTERNAME) | Out-Null
    }

    $rsa = [RSA]::Create(2048)
    $distinguishedName = [X500DistinguishedName]::new("CN=localhost")

    $req = [X509Certificates.CertificateRequest]::new(
        $distinguishedName,
        $rsa,
        [HashAlgorithmName]::SHA256,
        [RSASignaturePadding]::Pkcs1
    )

    $flags = (
        [X509Certificates.X509KeyUsageFlags]::DataEncipherment -bor
        [X509Certificates.X509KeyUsageFlags]::KeyEncipherment -bor
        [X509Certificates.X509KeyUsageFlags]::DigitalSignature
    )

    $req.CertificateExtensions.Add(
        [X509Certificates.X509KeyUsageExtension]::new(
            $flags,
            $false
        )
    ) | Out-Null

    $oid = [OidCollection]::new()
    $oid.Add([Oid]::new('1.3.6.1.5.5.7.3.1')) | Out-Null

    $req.CertificateExtensions.Add(
        [X509Certificates.X509EnhancedKeyUsageExtension]::new(
            $oid,
            $false
        )
    )

    $req.CertificateExtensions.Add($sanBuilder.Build()) | Out-Null

    $cert = $req.CreateSelfSigned(
        [System.DateTimeOffset]::UtcNow.AddDays(-1),
        [System.DateTimeOffset]::UtcNow.AddYears(10)
    )

    if (Test-PodeIsWindows) {
        $cert.FriendlyName = 'localhost'
    }

    $cert = [X509Certificates.X509Certificate2]::new(
        $cert.Export([X509Certificates.X509ContentType]::Pfx, 'self-signed'),
        'self-signed'
    )

    return $cert
}