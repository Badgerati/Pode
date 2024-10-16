using namespace System.Security.Cryptography

function Test-PodeIPLimit {
    param(
        [Parameter(Mandatory = $true)]
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
        Bytes  = $IP.GetAddressBytes()
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
            $active[$IP.String] = @{
                Rule = @{
                    Limit = -1
                }
            }

            return $true
        }

        # add ip to active list (ip if not grouped, else the subnet if it's grouped)
        $_ip = (Resolve-PodeValue -Check $_rule_ip.Grouped -TrueValue $_rule_ip.IP -FalseValue $IP.String)

        $active[$_ip] = @{
            Rule   = $_rule_ip
            Rate   = 1
            Expire = $now.AddSeconds($_rule_ip.Seconds)
        }

        # if limit is 0, it's never allowed
        return ($_rule_ip -ne 0)
    }
}

function Test-PodeRouteLimit {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [string]
        $Path
    )

    $type = 'Route'

    # get the limit rules and active list
    $rules = $PodeContext.Server.Limits.Rules[$type]
    $active = $PodeContext.Server.Limits.Active[$type]

    # if there are no rules, it's valid
    if (($null -eq $rules) -or ($rules.Count -eq 0)) {
        return $true
    }

    # now
    $now = [DateTime]::UtcNow

    # is the route active?
    $_active_route = $active[$Path]

    # the ip is active, or part of a grouped subnet
    if ($null -ne $_active_route) {
        # if limit is -1, always allowed
        if ($_active_route.Rule.Limit -eq -1) {
            return $true
        }

        # check expire time, a reset if needed
        if ($now -ge $_active_route.Expire) {
            $_active_route.Rate = 0
            $_active_route.Expire = $now.AddSeconds($_active_route.Rule.Seconds)
        }

        # are we over the limit?
        if ($_active_route.Rate -ge $_active_route.Rule.Limit) {
            return $false
        }

        # increment the rate
        $_active_route.Rate++
        return $true
    }

    # the route isn't active
    else {
        # get the route's rule
        $_rule_route = $rules[$Path]

        # if route not in rules, it's valid (add to active list as always allowed)
        if ($null -eq $_rule_route) {
            $active[$Path] = @{
                Rule = @{
                    Limit = -1
                }
            }

            return $true
        }

        # add route to active list
        $active[$Path] = @{
            Rule   = $_rule_route
            Rate   = 1
            Expire = $now.AddSeconds($_rule_route.Seconds)
        }

        # if limit is 0, it's never allowed
        return ($_rule_route -ne 0)
    }
}

<#
.SYNOPSIS
Checks if a given endpoint has exceeded its limit according to the defined rate limiting rules in Pode.

.DESCRIPTION
This function evaluates the rate limiting rules for a specified endpoint and determines if the endpoint is allowed to proceed based on the defined limits and the current usage rate. If the endpoint is not active or not defined in the rules, it is either allowed by default or added to the active list with its respective rule.

.PARAMETER EndpointName
The name of the endpoint to check against the rate limiting rules.

.EXAMPLE
Test-PodeEndpointLimit -EndpointName "MyEndpoint"
Checks if "MyEndpoint" is allowed to proceed based on the current rate limiting rules.

.EXAMPLE
$result = Test-PodeEndpointLimit -EndpointName $null
Checks if an unnamed endpoint (e.g., $null) is allowed, which always returns $true.

.RETURNS
[boolean] - Returns $true if the endpoint is allowed, otherwise $false.

.NOTES
This is an internal function and may change in future releases of Pode.
#>
function Test-PodeEndpointLimit {
    param(
        [Parameter()]
        [string]
        $EndpointName
    )

    $type = 'Endpoint'

    if ([string]::IsNullOrWhiteSpace($EndpointName)) {
        return $true
    }

    # get the limit rules and active list
    $rules = $PodeContext.Server.Limits.Rules[$type]
    $active = $PodeContext.Server.Limits.Active[$type]

    # if there are no rules, it's valid
    if (($null -eq $rules) -or ($rules.Count -eq 0)) {
        return $true
    }

    # now
    $now = [DateTime]::UtcNow

    # is the endpoint active?
    $_active_endpoint = $active[$EndpointName]

    # the endpoint is active
    if ($null -ne $_active_endpoint) {
        # if limit is -1, always allowed
        if ($_active_endpoint.Rule.Limit -eq -1) {
            return $true
        }

        # check expire time, a reset if needed
        if ($now -ge $_active_endpoint.Expire) {
            $_active_endpoint.Rate = 0
            $_active_endpoint.Expire = $now.AddSeconds($_active_endpoint.Rule.Seconds)
        }

        # are we over the limit?
        if ($_active_endpoint.Rate -ge $_active_endpoint.Rule.Limit) {
            return $false
        }

        # increment the rate
        $_active_endpoint.Rate++
        return $true
    }

    # the endpoint isn't active
    else {
        # get the endpoint's rule
        $_rule_endpoint = $rules[$EndpointName]

        # if endpoint not in rules, it's valid (add to active list as always allowed)
        if ($null -eq $_rule_endpoint) {
            $active[$EndpointName] = @{
                Rule = @{
                    Limit = -1
                }
            }

            return $true
        }

        # add endpoint to active list
        $active[$EndpointName] = @{
            Rule   = $_rule_endpoint
            Rate   = 1
            Expire = $now.AddSeconds($_rule_endpoint.Seconds)
        }

        # if limit is 0, it's never allowed
        return ($_rule_endpoint -ne 0)
    }
}

function Test-PodeIPAccess {
    param(
        [Parameter(Mandatory = $true)]
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
        Bytes  = $IP.GetAddressBytes()
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

function Add-PodeIPLimit {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [string]
        $IP,

        [Parameter(Mandatory = $true)]
        [int]
        $Limit,

        [Parameter(Mandatory = $true)]
        [int]
        $Seconds,

        [switch]
        $Group
    )

    # current limit type
    $type = 'IP'

    # ensure limit and seconds are non-zero and negative
    if ($Limit -le 0) {
        throw ($PodeLocale.limitValueCannotBeZeroOrLessExceptionMessage -f $IP) #"Limit value cannot be 0 or less for $($IP)"
    }

    if ($Seconds -le 0) {
        throw ($PodeLocale.secondsValueCannotBeZeroOrLessExceptionMessage -f $IP) #"Seconds value cannot be 0 or less for $($IP)"
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
            Limit   = $Limit
            Seconds = $Seconds
            Grouped = [bool]$Group
            IP      = $IP
            Lower   = @{
                Family = $_tmpLo.AddressFamily
                Bytes  = $_tmpLo.GetAddressBytes()
            }
            Upper   = @{
                Family = $_tmpHi.AddressFamily
                Bytes  = $_tmpHi.GetAddressBytes()
            }
        })
}

function Add-PodeRouteLimit {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [string]
        $Path,

        [Parameter(Mandatory = $true)]
        [int]
        $Limit,

        [Parameter(Mandatory = $true)]
        [int]
        $Seconds,

        [switch]
        $Group
    )

    # current limit type
    $type = 'Route'

    # ensure limit and seconds are non-zero and negative
    if ($Limit -le 0) {
        throw ($PodeLocale.limitValueCannotBeZeroOrLessExceptionMessage -f $IP) #"Limit value cannot be 0 or less for $($IP)"
    }

    if ($Seconds -le 0) {
        throw ($PodeLocale.secondsValueCannotBeZeroOrLessExceptionMessage -f $IP) #"Seconds value cannot be 0 or less for $($IP)"
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
            Limit   = $Limit
            Seconds = $Seconds
            Grouped = [bool]$Group
            Path    = $Path
        })
}

function Add-PodeEndpointLimit {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [string]
        $EndpointName,

        [Parameter(Mandatory = $true)]
        [int]
        $Limit,

        [Parameter(Mandatory = $true)]
        [int]
        $Seconds,

        [switch]
        $Group
    )

    # current limit type
    $type = 'Endpoint'

    # does the endpoint exist?
    $endpoint = Get-PodeEndpointByName -Name $EndpointName
    if ($null -eq $endpoint) {
        throw ($PodeLocale.endpointNameNotExistExceptionMessage -f $EndpointName) #"Endpoint not found: $($EndpointName)"
    }

    # ensure limit and seconds are non-zero and negative
    if ($Limit -le 0) {
        throw ($PodeLocale.limitValueCannotBeZeroOrLessExceptionMessage -f $IP) #"Limit value cannot be 0 or less for $($IP)"
    }

    if ($Seconds -le 0) {
        throw ($PodeLocale.secondsValueCannotBeZeroOrLessExceptionMessage -f $IP) #"Seconds value cannot be 0 or less for $($IP)"
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
    $rules.Add($EndpointName, @{
            Limit        = $Limit
            Seconds      = $Seconds
            Grouped      = [bool]$Group
            EndpointName = $EndpointName
        })
}

function Add-PodeIPAccess {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Allow', 'Deny')]
        [string]
        $Access,

        [Parameter(Mandatory = $true)]
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
                Bytes  = $_tmpLo.GetAddressBytes()
            }
            Upper = @{
                Family = $_tmpHi.AddressFamily
                Bytes  = $_tmpHi.GetAddressBytes()
            }
        })
}

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

function Get-PodeCertificateByFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Certificate,

        [Parameter()]
        [string]
        $Password = $null,

        [Parameter()]
        [string]
        $Key = $null
    )

    # cert + key
    if (![string]::IsNullOrWhiteSpace($Key)) {
        return (Get-PodeCertificateByPemFile -Certificate $Certificate -Password $Password -Key $Key)
    }

    $path = Get-PodeRelativePath -Path $Certificate -JoinRoot -Resolve

    # cert + password
    if (![string]::IsNullOrWhiteSpace($Password)) {
        return [X509Certificates.X509Certificate2]::new($path, $Password)
    }

    # plain cert
    return [X509Certificates.X509Certificate2]::new($path)
}

function Get-PodeCertificateByPemFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Certificate,

        [Parameter()]
        [string]
        $Password = $null,

        [Parameter()]
        [string]
        $Key = $null
    )

    $cert = $null

    $certPath = Get-PodeRelativePath -Path $Certificate -JoinRoot -Resolve
    $keyPath = Get-PodeRelativePath -Path $Key -JoinRoot -Resolve

    # pem's kinda work in .NET3/.NET5
    if ([version]$PSVersionTable.PSVersion -ge [version]'7.0.0') {
        $cert = [X509Certificates.X509Certificate2]::new($certPath)
        $keyText = [System.IO.File]::ReadAllText($keyPath)
        $rsa = [RSA]::Create()

        # .NET5
        if ([version]$PSVersionTable.PSVersion -ge [version]'7.1.0') {
            if ([string]::IsNullOrWhiteSpace($Password)) {
                $rsa.ImportFromPem($keyText)
            }
            else {
                $rsa.ImportFromEncryptedPem($keyText, $Password)
            }
        }

        # .NET3
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
                $rsa.ImportEncryptedPkcs8PrivateKey($Password, $keyBytes, [ref]$null)
            }
        }

        $cert = [X509Certificates.RSACertificateExtensions]::CopyWithPrivateKey($cert, $rsa)
        $cert = [X509Certificates.X509Certificate2]::new($cert.Export([X509Certificates.X509ContentType]::Pkcs12))
    }

    # for everything else, there's the openssl way
    else {
        $tempFile = Join-Path (Split-Path -Parent -Path $certPath) 'temp.pfx'

        try {
            if ([string]::IsNullOrWhiteSpace($Password)) {
                $Password = [string]::Empty
            }

            $result = openssl pkcs12 -inkey $keyPath -in $certPath -export -passin pass:$Password -password pass:$Password -out $tempFile
            if (!$?) {
                throw ($PodeLocale.failedToCreateOpenSslCertExceptionMessage -f $result) #"Failed to create openssl cert: $($result)"
            }

            $cert = [X509Certificates.X509Certificate2]::new($tempFile, $Password)
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
        [X509Certificates.X509FindType]
        $FindType,

        [Parameter(Mandatory = $true)]
        [string]
        $Query,

        [Parameter(Mandatory = $true)]
        [X509Certificates.StoreName]
        $StoreName,

        [Parameter(Mandatory = $true)]
        [X509Certificates.StoreLocation]
        $StoreLocation
    )

    # fail if not windows
    if (!(Test-PodeIsWindows)) {
        # Certificate Thumbprints/Name are only supported on Windows
        throw ($PodeLocale.certificateThumbprintsNameSupportedOnWindowsExceptionMessage)
    }

    # open the currentuser\my store
    $x509store = [X509Certificates.X509Store]::new($StoreName, $StoreLocation)

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
        throw ($PodeLocale.noCertificateFoundExceptionMessage -f $StoreLocation, $StoreName, $Query) # "No certificate could be found in $($StoreLocation)\$($StoreName) for '$($Query)'"
    }

    return ([X509Certificates.X509Certificate2]($x509certs[0]))
}

function Get-PodeCertificateByThumbprint {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Thumbprint,

        [Parameter(Mandatory = $true)]
        [X509Certificates.StoreName]
        $StoreName,

        [Parameter(Mandatory = $true)]
        [X509Certificates.StoreLocation]
        $StoreLocation
    )

    return Find-PodeCertificateInCertStore `
        -FindType ([X509Certificates.X509FindType]::FindByThumbprint) `
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
        [X509Certificates.StoreName]
        $StoreName,

        [Parameter(Mandatory = $true)]
        [X509Certificates.StoreLocation]
        $StoreLocation
    )

    return Find-PodeCertificateInCertStore `
        -FindType ([X509Certificates.X509FindType]::FindBySubjectName) `
        -Query $Name `
        -StoreName $StoreName `
        -StoreLocation $StoreLocation
}

function New-PodeSelfSignedCertificate {
    $sanBuilder = [X509Certificates.SubjectAlternativeNameBuilder]::new()
    $null = $sanBuilder.AddIpAddress([ipaddress]::Loopback)
    $null = $sanBuilder.AddIpAddress([ipaddress]::IPv6Loopback)
    $null = $sanBuilder.AddDnsName('localhost')

    if (![string]::IsNullOrWhiteSpace($PodeContext.Server.ComputerName)) {
        $null = $sanBuilder.AddDnsName($PodeContext.Server.ComputerName)
    }

    $rsa = [RSA]::Create(2048)
    $distinguishedName = [X500DistinguishedName]::new('CN=localhost')

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

    $null = $req.CertificateExtensions.Add(
        [X509Certificates.X509KeyUsageExtension]::new(
            $flags,
            $false
        )
    )

    $oid = [OidCollection]::new()
    $null = $oid.Add([Oid]::new('1.3.6.1.5.5.7.3.1'))

    $req.CertificateExtensions.Add(
        [X509Certificates.X509EnhancedKeyUsageExtension]::new(
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

    $cert = [X509Certificates.X509Certificate2]::new(
        $cert.Export([X509Certificates.X509ContentType]::Pfx, 'self-signed'),
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