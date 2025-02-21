
<#
.SYNOPSIS
Bind an endpoint to listen for incoming Requests.

.DESCRIPTION
Bind an endpoint to listen for incoming Requests. The endpoints can be HTTP, HTTPS, TCP or SMTP, with the option to bind certificates.

.PARAMETER Address
The IP/Hostname of the endpoint (Default: localhost).

.PARAMETER Port
The Port number of the endpoint.

.PARAMETER Hostname
An optional hostname for the endpoint, specifying a hostname restricts access to just the hostname.

.PARAMETER Protocol
The protocol of the supplied endpoint.

.PARAMETER Certificate
The path to a certificate that can be use to enable HTTPS

.PARAMETER CertificatePassword
The password for the certificate file referenced in Certificate

.PARAMETER CertificateKey
A key file to be paired with a PEM certificate file referenced in Certificate

.PARAMETER CertificateThumbprint
A certificate thumbprint to bind onto HTTPS endpoints (Windows).

.PARAMETER CertificateName
A certificate subject name to bind onto HTTPS endpoints (Windows).

.PARAMETER CertificateStoreName
The name of a certifcate store where a certificate can be found (Default: My) (Windows).

.PARAMETER CertificateStoreLocation
The location of a certifcate store where a certificate can be found (Default: CurrentUser) (Windows).

.PARAMETER X509Certificate
The raw X509 certificate that can be use to enable HTTPS

.PARAMETER TlsMode
The TLS mode to use on secure connections, options are Implicit or Explicit (SMTP only) (Default: Implicit).

.PARAMETER Name
An optional name for the endpoint, that can be used with other functions (Default: GUID).

.PARAMETER RedirectTo
The Name of another Endpoint to automatically generate a redirect route for all traffic.

.PARAMETER Description
A quick description of the Endpoint - normally used in OpenAPI.

.PARAMETER Acknowledge
An optional Acknowledge message to send to clients when they first connect, for TCP and SMTP endpoints only.

.PARAMETER SslProtocol
One or more optional SSL Protocols this endpoints supports. (Default: SSL3/TLS12 - Just TLS12 on MacOS).

.PARAMETER CRLFMessageEnd
If supplied, TCP endpoints will expect incoming data to end with CRLF.

.PARAMETER Force
Ignore Adminstrator checks for non-localhost endpoints.

.PARAMETER SelfSigned
Create and bind a self-signed certificate for HTTPS endpoints.

.PARAMETER AllowClientCertificate
Allow for client certificates to be sent on requests.

.PARAMETER PassThru
If supplied, the endpoint created will be returned.

.PARAMETER LookupHostname
If supplied, a supplied Hostname will have its IP Address looked up from host file or DNS.

.PARAMETER DualMode
If supplied, this endpoint will listen on both the IPv4 and IPv6 versions of the supplied -Address.
For IPv6, this will only work if the IPv6 address can convert to a valid IPv4 address.

.PARAMETER Default
If supplied, this endpoint will be the default one used for internally generating URLs.

.EXAMPLE
Add-PodeEndpoint -Address localhost -Port 8090 -Protocol Http

.EXAMPLE
Add-PodeEndpoint -Address localhost -Protocol Smtp

.EXAMPLE
Add-PodeEndpoint -Address dev.pode.com -Port 8443 -Protocol Https -SelfSigned

.EXAMPLE
Add-PodeEndpoint -Address 127.0.0.2 -Hostname dev.pode.com -Port 8443 -Protocol Https -SelfSigned

.EXAMPLE
Add-PodeEndpoint -Address live.pode.com -Protocol Https -CertificateThumbprint '2A9467F7D3940243D6C07DE61E7FCCE292'
#>
function Add-PodeEndpoint {
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    [OutputType([hashtable])]
    param(
        [Parameter()]
        [string]
        $Address = 'localhost',

        [Parameter()]
        [int]
        $Port = 0,

        [Parameter()]
        [string]
        $Hostname,

        [Parameter()]
        [ValidateSet('Http', 'Https', 'Smtp', 'Smtps', 'Tcp', 'Tcps', 'Ws', 'Wss')]
        [string]
        $Protocol,

        [Parameter(Mandatory = $true, ParameterSetName = 'CertFile')]
        [string]
        $Certificate = $null,

        [Parameter(ParameterSetName = 'CertFile')]
        [object]
        $CertificatePassword = $null,

        [Parameter(ParameterSetName = 'CertFile')]
        [string]
        $CertificateKey = $null,

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
        $CertificateStoreLocation = 'CurrentUser',

        [Parameter(Mandatory = $true, ParameterSetName = 'CertRaw')]
        [X509Certificate]
        $X509Certificate = $null,

        [Parameter(ParameterSetName = 'CertFile')]
        [Parameter(ParameterSetName = 'CertThumb')]
        [Parameter(ParameterSetName = 'CertName')]
        [Parameter(ParameterSetName = 'CertRaw')]
        [Parameter(ParameterSetName = 'CertSelf')]
        [ValidateSet('Implicit', 'Explicit')]
        [string]
        $TlsMode = 'Implicit',

        [Parameter()]
        [string]
        $Name = $null,

        [Parameter()]
        [string]
        $RedirectTo = $null,

        [Parameter()]
        [string]
        $Description,

        [Parameter()]
        [string]
        $Acknowledge,

        [Parameter()]
        [ValidateSet('Ssl2', 'Ssl3', 'Tls', 'Tls11', 'Tls12', 'Tls13')]
        [string[]]
        $SslProtocol = $null,

        [switch]
        $CRLFMessageEnd,

        [switch]
        $Force,

        [Parameter(ParameterSetName = 'CertSelf')]
        [switch]
        $SelfSigned,

        [switch]
        $AllowClientCertificate,

        [switch]
        $PassThru,

        [switch]
        $LookupHostname,

        [switch]
        $DualMode,

        [switch]
        $Default
    )

    # error if serverless
    Test-PodeIsServerless -FunctionName 'Add-PodeEndpoint' -ThrowError

    # if RedirectTo is supplied, then a Name is mandatory
    if (![string]::IsNullOrWhiteSpace($RedirectTo) -and [string]::IsNullOrWhiteSpace($Name)) {
        # A Name is required for the endpoint if the RedirectTo parameter is supplied
        throw ($PodeLocale.nameRequiredForEndpointIfRedirectToSuppliedExceptionMessage)
    }

    # get the type of endpoint
    $type = Get-PodeEndpointType -Protocol $Protocol

    # are we running as IIS for HTTP/HTTPS? (if yes, force the port, address and protocol)
    $isIIS = ((Test-PodeIsIIS) -and (@('Http', 'Ws') -icontains $type))
    if ($isIIS) {
        $Port = [int]$env:ASPNETCORE_PORT
        $Address = '127.0.0.1'
        $Hostname = [string]::Empty
        $Protocol = $type
    }

    # are we running as Heroku for HTTP/HTTPS? (if yes, force the port, address and protocol)
    $isHeroku = ((Test-PodeIsHeroku) -and (@('Http') -icontains $type))
    if ($isHeroku) {
        $Port = [int]$env:PORT
        $Address = '0.0.0.0'
        $Hostname = [string]::Empty
        $Protocol = $type
    }

    # parse the endpoint for host/port info
    if (![string]::IsNullOrWhiteSpace($Hostname) -and !(Test-PodeHostname -Hostname $Hostname)) {
        # Invalid hostname supplied
        throw ($PodeLocale.invalidHostnameSuppliedExceptionMessage -f $Hostname)
    }

    if ((Test-PodeHostname -Hostname $Address) -and ($Address -inotin @('localhost', 'all'))) {
        $Hostname = $Address
        $Address = 'localhost'
    }

    if (![string]::IsNullOrWhiteSpace($Hostname) -and $LookupHostname) {
        $Address = (Get-PodeIPAddressesForHostname -Hostname $Hostname -Type All | Select-Object -First 1)
    }

    $_endpoint = Get-PodeEndpointInfo -Address "$($Address):$($Port)"

    # if no name, set to guid, then check uniqueness
    if ([string]::IsNullOrWhiteSpace($Name)) {
        $Name = New-PodeGuid -Secure
    }

    if ($PodeContext.Server.Endpoints.ContainsKey($Name)) {
        # An endpoint named has already been defined
        throw ($PodeLocale.endpointAlreadyDefinedExceptionMessage -f $Name)
    }

    # protocol must be https for client certs, or hosted behind a proxy like iis
    if (($Protocol -ine 'https') -and !(Test-PodeIsHosted) -and $AllowClientCertificate) {
        # Client certificates are only supported on HTTPS endpoints
        throw ($PodeLocale.clientCertificatesOnlySupportedOnHttpsEndpointsExceptionMessage)
    }

    # explicit tls is only supported for smtp/tcp
    if (($type -inotin @('smtp', 'tcp')) -and ($TlsMode -ieq 'explicit')) {
        # The Explicit TLS mode is only supported on SMTPS and TCPS endpoints
        throw ($PodeLocale.explicitTlsModeOnlySupportedOnSmtpsTcpsEndpointsExceptionMessage)
    }

    # ack message is only for smtp/tcp
    if (($type -inotin @('smtp', 'tcp')) -and ![string]::IsNullOrEmpty($Acknowledge)) {
        # The Acknowledge message is only supported on SMTP and TCP endpoints
        throw ($PodeLocale.acknowledgeMessageOnlySupportedOnSmtpTcpEndpointsExceptionMessage)
    }

    # crlf message end is only for tcp
    if (($type -ine 'tcp') -and $CRLFMessageEnd) {
        # The CRLF message end check is only supported on TCP endpoints
        throw ($PodeLocale.crlfMessageEndCheckOnlySupportedOnTcpEndpointsExceptionMessage)
    }

    # new endpoint object
    $obj = @{
        Name         = $Name
        Description  = $Description
        DualMode     = $DualMode
        Address      = $null
        RawAddress   = $null
        Port         = $null
        IsIPAddress  = $true
        HostName     = $Hostname
        FriendlyName = $Hostname
        Url          = $null
        Ssl          = @{
            Enabled   = (@('https', 'wss', 'smtps', 'tcps') -icontains $Protocol)
            Protocols = $PodeContext.Server.Sockets.Ssl.Protocols
        }
        Protocol     = $Protocol.ToLowerInvariant()
        Type         = $type.ToLowerInvariant()
        Runspace     = @{
            PoolName = (Get-PodeEndpointRunspacePoolName -Protocol $Protocol)
        }
        Default      = $Default.IsPresent
        Certificate  = @{
            Raw                    = $X509Certificate
            SelfSigned             = $SelfSigned
            AllowClientCertificate = $AllowClientCertificate
            TlsMode                = $TlsMode
        }
        Tcp          = @{
            Acknowledge    = $Acknowledge
            CRLFMessageEnd = $CRLFMessageEnd
        }
    }

    # set ssl protocols
    if (!(Test-PodeIsEmpty $SslProtocol)) {
        $obj.Ssl.Protocols = (ConvertTo-PodeSslProtocol -Protocol $SslProtocol)
    }

    # set the ip for the context (force to localhost for IIS)
    $obj.Address = Get-PodeIPAddress $_endpoint.Host -DualMode:$DualMode
    $obj.IsIPAddress = [string]::IsNullOrWhiteSpace($obj.HostName)

    if ($obj.IsIPAddress) {
        if (!(Test-PodeIPAddressLocalOrAny -IP $obj.Address)) {
            $obj.FriendlyName = "$($obj.Address)"
        }
        else {
            $obj.FriendlyName = 'localhost'
        }
    }

    # set the port for the context, if 0 use a default port for protocol
    $obj.Port = $_endpoint.Port
    if (([int]$obj.Port) -eq 0) {
        $obj.Port = Get-PodeDefaultPort -Protocol $Protocol -TlsMode $TlsMode
    }

    if ($obj.IsIPAddress) {
        $obj.RawAddress = "$($obj.Address):$($obj.Port)"
    }
    else {
        $obj.RawAddress = "$($obj.FriendlyName):$($obj.Port)"
    }

    # set the url of this endpoint
    if (($obj.Protocol -eq 'http') -or ($obj.Protocol -eq 'https')) {
        $obj.Url = "$($obj.Protocol)://$($obj.FriendlyName):$($obj.Port)/"
    }
    else {
        $obj.Url = "$($obj.Protocol)://$($obj.FriendlyName):$($obj.Port)"
    }
    # if the address is non-local, then check admin privileges
    if (!$Force -and !(Test-PodeIPAddressLocal -IP $obj.Address) -and !(Test-PodeIsAdminUser)) {
        # Must be running with administrator privileges to listen on non-localhost addresses
        throw ($PodeLocale.mustBeRunningWithAdminPrivilegesExceptionMessage)
    }

    # has this endpoint been added before? (for http/https we can just not add it again)
    $exists = ($PodeContext.Server.Endpoints.Values | Where-Object {
        ($_.FriendlyName -ieq $obj.FriendlyName) -and ($_.Port -eq $obj.Port) -and ($_.Ssl.Enabled -eq $obj.Ssl.Enabled) -and ($_.Type -ieq $obj.Type)
        } | Measure-Object).Count

    # if we're dealing with a certificate, attempt to import it
    if (!(Test-PodeIsHosted) -and ($PSCmdlet.ParameterSetName -ilike 'cert*')) {
        # fail if protocol is not https
        if (@('https', 'wss', 'smtps', 'tcps') -inotcontains $Protocol) {
            # Certificate supplied for non-HTTPS/WSS endpoint
            throw ($PodeLocale.certificateSuppliedForNonHttpsWssEndpointExceptionMessage)
        }

        switch ($PSCmdlet.ParameterSetName.ToLowerInvariant()) {
            'certfile' {
                if ($CertificatePassword -is [string]) {
                    $securePassword = ConvertTo-SecureString -String $CertificatePassword -AsPlainText -Force
                }
                elseif ($CertificatePassword -is [securestring]) { $securePassword = $CertificatePassword }else {
                    #  'Error: Invalid type for {0}. Expected {1}, but received [{2}].
                    throw  ($PodeLocale.invalidTypeExceptionMessage -f '-CertificatePassword', '[string] or [SecureString]', $CertificatePassword.GetType().Name)
                }

                $obj.Certificate.Raw = Get-PodeCertificateByFile -Certificate $Certificate  -SecurePassword $securePassword  -PrivateKeyPath $CertificateKey
            }

            'certthumb' {
                $obj.Certificate.Raw = Get-PodeCertificateByThumbprint -Thumbprint $CertificateThumbprint -StoreName $CertificateStoreName -StoreLocation $CertificateStoreLocation
            }

            'certname' {
                $obj.Certificate.Raw = Get-PodeCertificateByName -Name $CertificateName -StoreName $CertificateStoreName -StoreLocation $CertificateStoreLocation
            }

            'certself' {
                $obj.Certificate.Raw = New-PodeSelfSignedCertificate -Loopback -CertificatePurpose ServerAuth -DnsName $obj.address.ToString() -Ephemeral
            }
        }

        # Validate the certificate's validity period before proceeding
        Test-PodeCertificateValidity -Certificate $obj.Certificate.Raw

        # Ensure the certificate is authorized for the expected purpose
        Test-PodeCertificateRestriction -Certificate $obj.Certificate.Raw -ExpectedPurpose ServerAuth
    }

    if (!$exists) {
        # set server type
        $_type = $type
        if ($_type -iin @('http', 'ws')) {
            $_type = 'http'
        }

        if ($PodeContext.Server.Types -inotcontains $_type) {
            $PodeContext.Server.Types += $_type
        }

        # add the new endpoint
        $PodeContext.Server.Endpoints[$Name] = $obj
        $PodeContext.Server.EndpointsMap["$($obj.Protocol)|$($obj.RawAddress)"] = $Name
    }

    # if RedirectTo is set, attempt to build a redirecting route
    if (!(Test-PodeIsHosted) -and ![string]::IsNullOrWhiteSpace($RedirectTo)) {
        $redir_endpoint = $PodeContext.Server.Endpoints[$RedirectTo]

        # ensure the name exists
        if (Test-PodeIsEmpty $redir_endpoint) {
            # An endpoint named has not been defined for redirecting
            throw ($PodeLocale.endpointNotDefinedForRedirectingExceptionMessage -f $RedirectTo)
        }

        # build the redirect route
        Add-PodeRoute -Method * -Path * -EndpointName $obj.Name -ArgumentList $redir_endpoint -ScriptBlock {
            param($endpoint)
            Move-PodeResponseUrl -EndpointName $endpoint.Name
        }
    }

    # return the endpoint?
    if ($PassThru) {
        return $obj
    }
}

<#
.SYNOPSIS
Get an Endpoint(s).

.DESCRIPTION
Get an Endpoint(s).

.PARAMETER Address
An Address to filter the endpoints.

.PARAMETER Port
A Port to filter the endpoints.

.PARAMETER Hostname
A Hostname to filter the endpoints.

.PARAMETER Protocol
A Protocol to filter the endpoints.

.PARAMETER Name
Any endpoints Names to filter endpoints.

.EXAMPLE
Get-PodeEndpoint -Address 127.0.0.1

.EXAMPLE
Get-PodeEndpoint -Protocol Http

.EXAMPLE
Get-PodeEndpoint -Name Admin, User
#>
function Get-PodeEndpoint {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Address,

        [Parameter()]
        [int]
        $Port = 0,

        [Parameter()]
        [string]
        $Hostname,

        [Parameter()]
        [ValidateSet('', 'Http', 'Https', 'Smtp', 'Smtps', 'Tcp', 'Tcps', 'Ws', 'Wss')]
        [string]
        $Protocol,

        [Parameter()]
        [string[]]
        $Name
    )

    if ((Test-PodeHostname -Hostname $Address) -and ($Address -inotin @('localhost', 'all'))) {
        $Hostname = $Address
        $Address = 'localhost'
    }

    $endpoints = $PodeContext.Server.Endpoints.Values

    # if we have an address, filter
    if (![string]::IsNullOrWhiteSpace($Address)) {
        if (($Address -eq '*') -or $PodeContext.Server.IsHeroku) {
            $Address = '0.0.0.0'
        }

        if ($PodeContext.Server.IsIIS -or ($Address -ieq 'localhost')) {
            $Address = '127.0.0.1'
        }

        $endpoints = @(foreach ($endpoint in $endpoints) {
                if ($endpoint.Address.ToString() -ine $Address) {
                    continue
                }

                $endpoint
            })
    }

    # if we have a hostname, filter
    if (![string]::IsNullOrWhiteSpace($Hostname)) {
        $endpoints = @(foreach ($endpoint in $endpoints) {
                if ($endpoint.Hostname.ToString() -ine $Hostname) {
                    continue
                }

                $endpoint
            })
    }

    # if we have a port, filter
    if ($Port -gt 0) {
        if ($PodeContext.Server.IsIIS) {
            $Port = [int]$env:ASPNETCORE_PORT
        }

        if ($PodeContext.Server.IsHeroku) {
            $Port = [int]$env:PORT
        }

        $endpoints = @(foreach ($endpoint in $endpoints) {
                if ($endpoint.Port -ne $Port) {
                    continue
                }

                $endpoint
            })
    }

    # if we have a protocol, filter
    if (![string]::IsNullOrWhiteSpace($Protocol)) {
        if ($PodeContext.Server.IsIIS -or $PodeContext.Server.IsHeroku) {
            $Protocol = 'Http'
        }

        $endpoints = @(foreach ($endpoint in $endpoints) {
                if ($endpoint.Protocol -ine $Protocol) {
                    continue
                }

                $endpoint
            })
    }

    # further filter by endpoint names
    if (($null -ne $Name) -and ($Name.Length -gt 0)) {
        $endpoints = @(foreach ($_name in $Name) {
                foreach ($endpoint in $endpoints) {
                    if ($endpoint.Name -ine $_name) {
                        continue
                    }

                    $endpoint
                }
            })
    }

    # return
    return $endpoints
}
