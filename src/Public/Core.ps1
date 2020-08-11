<#
.SYNOPSIS
Starts a Pode Server with the supplied ScriptBlock.

.DESCRIPTION
Starts a Pode Server with the supplied ScriptBlock.

.PARAMETER ScriptBlock
The main logic for the Server.

.PARAMETER FilePath
A literal, or relative, path to a file containing a ScriptBlock for the Server's logic.
The directory of this file will be used as the Server's root path - unless a specific -RootPath is supplied.

.PARAMETER Interval
For 'Service' type Servers, will invoke the ScriptBlock every X seconds.

.PARAMETER Name
An optional name for the Server (intended for future ideas).

.PARAMETER Threads
The numbers of threads to use for Web and TCP servers.

.PARAMETER RootPath
An override for the Server's root path.

.PARAMETER Request
Intended for Serverless environments, this is Requests details that Pode can parse and use.

.PARAMETER Type
The server type, to define how Pode should run and deal with incoming Requests.

.PARAMETER StatusPageExceptions
An optional value of Show/Hide to control where Stacktraces are shown in the Status Pages.
If supplied this value will override the ShowExceptions setting in the server.psd1 file.

.PARAMETER DisableTermination
Disables the ability to terminate the Server.

.PARAMETER Quiet
Disables any output from the Server.

.PARAMETER Browse
Open the web Server's default endpoint in your default browser.

.PARAMETER CurrentPath
Sets the Server's root path to be the current working path - for -FilePath only.

.EXAMPLE
Start-PodeServer { /* logic */ }

.EXAMPLE
Start-PodeServer -Interval 10 { /* logic */ }

.EXAMPLE
Start-PodeServer -Request $LambdaInput -Type 'AwsLambda' { /* logic */ }
#>
function Start-PodeServer
{
    [CmdletBinding(DefaultParameterSetName='Script')]
    param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true, Position=0, ParameterSetName='Script')]
        [scriptblock]
        $ScriptBlock,

        [Parameter(Mandatory=$true, ParameterSetName='File')]
        [string]
        $FilePath,

        [Parameter()]
        [int]
        $Interval = 0,

        [Parameter()]
        [string]
        $Name,

        [Parameter()]
        [int]
        $Threads = 1,

        [Parameter()]
        [string]
        $RootPath,

        [Parameter()]
        $Request,

        [Parameter()]
        [ValidateSet('', 'AzureFunctions', 'AwsLambda')]
        [string]
        $Type = [string]::Empty,

        [Parameter()]
        [ValidateSet('', 'Hide', 'Show')]
        [string]
        $StatusPageExceptions = [string]::Empty,

        [switch]
        $DisableTermination,

        [switch]
        $Quiet,

        [switch]
        $Browse,

        [Parameter(ParameterSetName='File')]
        [switch]
        $CurrentPath
    )

    # ensure the session is clean
    $PodeContext = $null
    $ShowDoneMessage = $true

    try {
        # if we have a filepath, resolve it - and extract a root path from it
        if ($PSCmdlet.ParameterSetName -ieq 'file') {
            $FilePath = Get-PodeRelativePath -Path $FilePath -Resolve -TestPath

            # if not already supplied, set root path
            if ([string]::IsNullOrWhiteSpace($RootPath)) {
                if ($CurrentPath) {
                    $RootPath = $PWD.Path
                }
                else {
                    $RootPath = Split-Path -Parent -Path $FilePath
                }
            }
        }

        # configure the server's root path
        if (!(Test-IsEmpty $RootPath)) {
            $RootPath = Get-PodeRelativePath -Path $RootPath -RootPath $MyInvocation.PSScriptRoot -JoinRoot -Resolve -TestPath
        }

        # create main context object
        $PodeContext = New-PodeContext `
            -ScriptBlock $ScriptBlock `
            -FilePath $FilePath `
            -Threads $Threads `
            -Interval $Interval `
            -ServerRoot (Protect-PodeValue -Value $RootPath -Default $MyInvocation.PSScriptRoot) `
            -ServerType $Type `
            -StatusPageExceptions $StatusPageExceptions `
            -DisableTermination:$DisableTermination `
            -Quiet:$Quiet

        # set it so ctrl-c can terminate, unless serverless/iis, or disabled
        if (!$PodeContext.Server.DisableTermination) {
            [Console]::TreatControlCAsInput = $true
        }

        # start the file monitor for interally restarting
        Start-PodeFileMonitor

        # start the server
        Start-PodeInternalServer -Request $Request -Browse:$Browse

        # at this point, if it's just a one-one off script, return
        if ([string]::IsNullOrWhiteSpace($PodeContext.Server.Type) -or $PodeContext.Server.IsServerless) {
            return
        }

        # sit here waiting for termination/cancellation, or to restart the server
        while (!(Test-PodeTerminationPressed -Key $key) -and !($PodeContext.Tokens.Cancellation.IsCancellationRequested)) {
            Start-Sleep -Seconds 1

            # get the next key presses
            $key = Get-PodeConsoleKey

            # check for internal restart
            if (($PodeContext.Tokens.Restart.IsCancellationRequested) -or (Test-PodeRestartPressed -Key $key)) {
                Restart-PodeInternalServer
            }

            # check for open browser
            if (Test-PodeOpenBrowserPressed -Key $key) {
                Start-Process (Get-PodeEndpointUrl)
            }
        }

        Write-PodeHost 'Terminating...' -NoNewline -ForegroundColor Yellow
        $PodeContext.Tokens.Cancellation.Cancel()
    }
    catch {
        $ShowDoneMessage = $false
        throw
    }
    finally {
        # clean the runspaces and tokens
        Close-PodeServerInternal -ShowDoneMessage:$ShowDoneMessage

        # clean the session
        $PodeContext = $null
    }
}

<#
.SYNOPSIS
Closes the Pode server.

.DESCRIPTION
Closes the Pode server.

.EXAMPLE
Close-PodeServer
#>
function Close-PodeServer
{
    [CmdletBinding()]
    param()

    $PodeContext.Tokens.Cancellation.Cancel()
}

<#
.SYNOPSIS
Helper wrapper function to start a Pode web server for a static website at the current directory.

.DESCRIPTION
Helper wrapper function to start a Pode web server for a static website at the current directory.

.PARAMETER Threads
The numbers of threads to use for requests.

.PARAMETER RootPath
An override for the Server's root path.

.PARAMETER Address
The IP/Hostname of the endpoint.

.PARAMETER Port
The Port number of the endpoint.

.PARAMETER Https
Start the server using HTTPS.

.PARAMETER Certificate
The path to a certificate that can be use to enable HTTPS.

.PARAMETER CertificatePassword
The password for the certificate referenced in CertificateFile.

.PARAMETER X509Certificate
The raw X509 certificate that can be use to enable HTTPS.

.PARAMETER Path
The URI path for the static Route.

.PARAMETER Defaults
An array of default pages to display, such as 'index.html'.

.PARAMETER DownloadOnly
When supplied, all static content on this Route will be attached as downloads - rather than rendered.

.PARAMETER Browse
Open the web server's default endpoint in your default browser.

.EXAMPLE
Start-PodeStaticServer

.EXAMPLE
Start-PodeStaticServer -Address '127.0.0.3' -Port 8000

.EXAMPLE
Start-PodeStaticServer -Path '/installers' -DownloadOnly
#>
function Start-PodeStaticServer
{
    [CmdletBinding()]
    param(
        [Parameter()]
        [int]
        $Threads = 3,

        [Parameter()]
        [string]
        $RootPath = $PWD,

        [Parameter()]
        [string]
        $Address = 'localhost',

        [Parameter()]
        [int]
        $Port = 0,

        [Parameter(ParameterSetName='Https')]
        [switch]
        $Https,

        [Parameter(ParameterSetName='Https')]
        [string]
        $Certificate = $null,

        [Parameter(ParameterSetName='Https')]
        [string]
        $CertificatePassword = $null,

        [Parameter(ParameterSetName='Https')]
        [Parameter()]
        [X509Certificate]
        $X509Certificate = $null,

        [Parameter()]
        [string]
        $Path = '/',

        [Parameter()]
        [string[]]
        $Defaults,

        [switch]
        $DownloadOnly,

        [switch]
        $Browse
    )

    Start-PodeServer -RootPath $RootPath -Threads $Threads -Browse:$Browse -ScriptBlock {
        # add either an http or https endpoint
        if ($Https) {
            if ($null -eq $X509Certificate) {
                Add-PodeEndpoint -Address $Address -Port $Port -Protocol Https -Certificate $Certificate -CertificatePassword $CertificatePassword
            }
            else {
                Add-PodeEndpoint -Address $Address -Port $Port -Protocol Https -X509Certificate $X509Certificate
            }
        }
        else {
            Add-PodeEndpoint -Address $Address -Port $Port -Protocol Http
        }

        # add the static route
        Add-PodeStaticRoute -Path $Path -Source (Get-PodeServerPath) -Defaults $Defaults -DownloadOnly:$DownloadOnly
    }
}

<#
.SYNOPSIS
The CLI for Pode, to initialise, build and start your Server.

.DESCRIPTION
The CLI for Pode, to initialise, build and start your Server.

.PARAMETER Action
The action to invoke on your Server.

.PARAMETER Dev
Supply when running "pode install", this will install any dev packages defined in your package.json.

.EXAMPLE
pode install -dev

.EXAMPLE
pode build

.EXAMPLE
pode start
#>
function Pode
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet('init', 'test', 'start', 'install', 'build')]
        [Alias('a')]
        [string]
        $Action,

        [switch]
        [Alias('d')]
        $Dev
    )

    # default config file name and content
    $file = './package.json'
    $name = Split-Path -Leaf -Path $pwd
    $data = $null

    # default config data that's used to populate on init
    $map = @{
        'name' = $name;
        'version' = '1.0.0';
        'description' = '';
        'main' = './server.ps1';
        'scripts' = @{
            'start' = './server.ps1';
            'install' = 'yarn install --force --ignore-scripts --modules-folder pode_modules';
            "build" = 'psake';
            'test' = 'invoke-pester ./tests/*.ps1'
        };
        'author' = '';
        'license' = 'MIT';
    }

    # check and load config if already exists
    if (Test-Path $file) {
        $data = (Get-Content $file | ConvertFrom-Json)
    }

    # quick check to see if the data is required
    if ($Action -ine 'init') {
        if ($null -eq $data) {
            Write-Host 'package.json file not found' -ForegroundColor Red
            return
        }
        else {
            $actionScript = $data.scripts.$Action

            if ([string]::IsNullOrWhiteSpace($actionScript) -and $Action -ieq 'start') {
                $actionScript = $data.main
            }

            if ([string]::IsNullOrWhiteSpace($actionScript) -and $Action -ine 'install') {
                Write-Host "package.json does not contain a script for the $($Action) action" -ForegroundColor Yellow
                return
            }
        }
    }
    else {
        if ($null -ne $data) {
            Write-Host 'package.json already exists' -ForegroundColor Yellow
            return
        }
    }

    switch ($Action.ToLowerInvariant())
    {
        'init' {
            $v = Read-Host -Prompt "name ($($map.name))"
            if (![string]::IsNullOrWhiteSpace($v)) { $map.name = $v }

            $v = Read-Host -Prompt "version ($($map.version))"
            if (![string]::IsNullOrWhiteSpace($v)) { $map.version = $v }

            $map.description = Read-Host -Prompt "description"

            $v = Read-Host -Prompt "entry point ($($map.main))"
            if (![string]::IsNullOrWhiteSpace($v)) { $map.main = $v; $map.scripts.start = $v }

            $map.author = Read-Host -Prompt "author"

            $v = Read-Host -Prompt "license ($($map.license))"
            if (![string]::IsNullOrWhiteSpace($v)) { $map.license = $v }

            $map | ConvertTo-Json -Depth 10 | Out-File -FilePath $file -Encoding utf8 -Force
            Write-Host 'Success, saved package.json' -ForegroundColor Green
        }

        'test' {
            Invoke-PodePackageScript -ActionScript $actionScript
        }

        'start' {
            Invoke-PodePackageScript -ActionScript $actionScript
        }

        'install' {
            if ($Dev) {
                Install-PodeLocalModules -Modules $data.devModules
            }

            Install-PodeLocalModules -Modules $data.modules
            Invoke-PodePackageScript -ActionScript $actionScript
        }

        'build' {
            Invoke-PodePackageScript -ActionScript $actionScript
        }
    }
}

<#
.SYNOPSIS
Opens a Web Server up as a Desktop Application.

.DESCRIPTION
Opens a Web Server up as a Desktop Application.

.PARAMETER Title
The title of the Application's window.

.PARAMETER Icon
A path to an icon image for the Application.

.PARAMETER WindowState
The state the Application's window starts, such as Minimized.

.PARAMETER WindowStyle
The border style of the Application's window.

.PARAMETER ResizeMode
Specifies if the Application's window is resizable.

.PARAMETER Height
The height of the window.

.PARAMETER Width
The width of the window.

.PARAMETER EndpointName
The specific endpoint name to use, if you are listening on multiple endpoints.

.PARAMETER HideFromTaskbar
Stops the Application from appearing on the taskbar.

.EXAMPLE
Show-PodeGui -Title 'MyApplication' -WindowState 'Maximized'
#>
function Show-PodeGui
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [string]
        $Title,

        [Parameter()]
        [string]
        $Icon,

        [Parameter()]
        [ValidateSet('Normal', 'Maximized', 'Minimized')]
        [string]
        $WindowState = 'Normal',

        [Parameter()]
        [ValidateSet('None', 'SingleBorderWindow', 'ThreeDBorderWindow', 'ToolWindow')]
        [string]
        $WindowStyle = 'SingleBorderWindow',

        [Parameter()]
        [ValidateSet('CanResize', 'CanMinimize', 'NoResize')]
        [string]
        $ResizeMode = 'CanResize',

        [Parameter()]
        [int]
        $Height = 0,

        [Parameter()]
        [int]
        $Width = 0,

        [Parameter()]
        [string]
        $EndpointName,

        [switch]
        $HideFromTaskbar
    )

    # error if serverless
    Test-PodeIsServerless -FunctionName 'Show-PodeGui' -ThrowError

    # only valid for Windows PowerShell
    if ((Test-IsPSCore) -and ($PSVersionTable.PSVersion.Major -eq 6)) {
        throw 'Show-PodeGui is currently only available for Windows PowerShell, and PowerShell 7 on Windows'
    }

    # enable the gui and set general settings
    $PodeContext.Server.Gui.Enabled = $true
    $PodeContext.Server.Gui.Title = $Title
    $PodeContext.Server.Gui.ShowInTaskbar = !$HideFromTaskbar
    $PodeContext.Server.Gui.WindowState = $WindowState
    $PodeContext.Server.Gui.WindowStyle = $WindowStyle
    $PodeContext.Server.Gui.ResizeMode = $ResizeMode

    # set the window's icon path
    if (![string]::IsNullOrWhiteSpace($Icon)) {
        $PodeContext.Server.Gui.Icon = (Resolve-Path $Icon).Path
        if (!(Test-Path $PodeContext.Server.Gui.Icon)) {
            throw "Path to icon for GUI does not exist: $($PodeContext.Server.Gui.Icon)"
        }
    }

    # set the height of the window
    $PodeContext.Server.Gui.Height = $Height
    if ($PodeContext.Server.Gui.Height -le 0) {
        $PodeContext.Server.Gui.Height = 'auto'
    }

    # set the width of the window
    $PodeContext.Server.Gui.Width = $Width
    if ($PodeContext.Server.Gui.Width -le 0) {
        $PodeContext.Server.Gui.Width = 'auto'
    }

    # set the gui to use a specific listener
    $PodeContext.Server.Gui.EndpointName = $EndpointName

    if (![string]::IsNullOrWhiteSpace($PodeContext.Server.Gui.EndpointName)) {
        $found = ($PodeContext.Server.Endpoints | Where-Object {
            $_.Name -eq $PodeContext.Server.Gui.EndpointName
        } | Select-Object -First 1)

        if ($null -eq $found) {
            throw "Endpoint with name '$($EndpointName)' does not exist"
        }

        $PodeContext.Server.Gui.Endpoint = $found
    }
}

<#
.SYNOPSIS
Bind an endpoint to listen for incoming Requests.

.DESCRIPTION
Bind an endpoint to listen for incoming Requests. The endpoints can be HTTP, HTTPS, TCP or SMTP, with the option to bind certificates.

.PARAMETER Address
The IP/Hostname of the endpoint.

.PARAMETER Port
The Port number of the endpoint.

.PARAMETER Protocol
The protocol of the supplied endpoint.

.PARAMETER Certificate
The path to a certificate that can be use to enable HTTPS

.PARAMETER CertificatePassword
The password for the certificate file referenced in Certificate

.PARAMETER CertificateThumbprint
A certificate thumbprint to bind onto HTTPS endpoints (Windows).

.PARAMETER CertificateName
A certificate subject name to bind onto HTTPS endpoints (Windows).

.PARAMETER X509Certificate
The raw X509 certificate that can be use to enable HTTPS

.PARAMETER Name
An optional name for the endpoint, that can be used with other functions.

.PARAMETER RedirectTo
The Name of another Endpoint to automatically generate a redirect route for all traffic.

.PARAMETER Description
A quick description of the Endpoint - normally used in OpenAPI.

.PARAMETER Force
Ignore Adminstrator checks for non-localhost endpoints.

.PARAMETER SelfSigned
Create and bind a self-signed certifcate for HTTPS endpoints.

.EXAMPLE
Add-PodeEndpoint -Address localhost -Port 8090 -Protocol Http

.EXAMPLE
Add-PodeEndpoint -Address localhost -Protocol Smtp

.EXAMPLE
Add-PodeEndpoint -Address dev.pode.com -Port 8443 -Protocol Https -SelfSigned

.EXAMPLE
Add-PodeEndpoint -Address live.pode.com -Protocol Https -CertificateThumbprint '2A9467F7D3940243D6C07DE61E7FCCE292'
#>
function Add-PodeEndpoint
{
    [CmdletBinding(DefaultParameterSetName='Default')]
    param (
        [Parameter()]
        [string]
        $Address = 'localhost',

        [Parameter()]
        [int]
        $Port = 0,

        [Parameter()]
        [ValidateSet('Http', 'Https', 'Smtp', 'Tcp', 'Ws', 'Wss')]
        [string]
        $Protocol,

        [Parameter(Mandatory=$true, ParameterSetName='CertFile')]
        [string]
        $Certificate = $null,

        [Parameter(ParameterSetName='CertFile')]
        [string]
        $CertificatePassword = $null,

        [Parameter(Mandatory=$true, ParameterSetName='CertThumb')]
        [string]
        $CertificateThumbprint,

        [Parameter(Mandatory=$true, ParameterSetName='CertName')]
        [string]
        $CertificateName,

        [Parameter(Mandatory=$true, ParameterSetName='CertRaw')]
        [Parameter()]
        [X509Certificate]
        $X509Certificate = $null,

        [Parameter()]
        [string]
        $Name = $null,

        [Parameter()]
        [string]
        $RedirectTo = $null,

        [Parameter()]
        [string]
        $Description,

        [switch]
        $Force,

        [Parameter(ParameterSetName='CertSelf')]
        [switch]
        $SelfSigned
    )

    # error if serverless
    Test-PodeIsServerless -FunctionName 'Add-PodeEndpoint' -ThrowError

    # if RedirectTo is supplied, then a Name is mandatory
    if (![string]::IsNullOrWhiteSpace($RedirectTo) -and [string]::IsNullOrWhiteSpace($Name)) {
        throw "A Name is required for the endpoint if the RedirectTo parameter is supplied"
    }

    # are we running as IIS for HTTP/HTTPS? (if yes, force the port, address and protocol)
    $isIIS = ($PodeContext.Server.IsIIS -and (@('Http', 'Https') -icontains $Protocol))
    if ($isIIS) {
        $Port = [int]$env:ASPNETCORE_PORT
        $Address = '127.0.0.1'
        $Protocol = 'Http'
    }

    # are we running as Heroku for HTTP/HTTPS? (if yes, force the port, address and protocol)
    $isHeroku = ($PodeContext.Server.IsHeroku -and (@('Http', 'Https') -icontains $Protocol))
    if ($isHeroku) {
        $Port = [int]$env:PORT
        $Address = '0.0.0.0'
        $Protocol = 'Http'
    }

    # parse the endpoint for host/port info
    $FullAddress = "$($Address):$($Port)"
    $_endpoint = Get-PodeEndpointInfo -Address $FullAddress

    # if a name was supplied, check it is unique
    if (!(Test-IsEmpty $Name) -and
        (Get-PodeCount ($PodeContext.Server.Endpoints | Where-Object { $_.Name -eq $Name })) -ne 0)
    {
        throw "An endpoint with the name '$($Name)' has already been defined"
    }

    # new endpoint object
    $obj = @{
        Name = $Name
        Description = $Description
        Address = $null
        RawAddress = $FullAddress
        Port = $null
        IsIPAddress = $true
        HostName = 'localhost'
        Url = $null
        Ssl = (@('https', 'wss') -icontains $Protocol)
        Protocol = $Protocol.ToLowerInvariant()
        Certificate = @{
            Raw = $X509Certificate
            SelfSigned = $SelfSigned
        }
    }

    # set the ip for the context (force to localhost for IIS)
    $obj.Address = (Get-PodeIPAddress $_endpoint.Host)
    if (!(Test-PodeIPAddressLocalOrAny -IP $obj.Address)) {
        $obj.HostName = "$($obj.Address)"
    }

    $obj.IsIPAddress = (Test-PodeIPAddress -IP $obj.Address -IPOnly)

    # set the port for the context, if 0 use a default port for protocol
    $obj.Port = $_endpoint.Port
    if (([int]$obj.Port) -eq 0) {
        $obj.Port = Get-PodeDefaultPort -Protocol $Protocol
    }

    # set the url of this endpoint
    $obj.Url = "$($obj.Protocol)://$($obj.HostName):$($obj.Port)/"

    # if the address is non-local, then check admin privileges
    if (!$Force -and !(Test-PodeIPAddressLocal -IP $obj.Address) -and !(Test-IsAdminUser)) {
        throw 'Must be running with administrator priviledges to listen on non-localhost addresses'
    }

    # has this endpoint been added before? (for http/https we can just not add it again)
    $exists = ($PodeContext.Server.Endpoints | Where-Object {
        ($_.Address -eq $obj.Address) -and ($_.Port -eq $obj.Port) -and ($_.Ssl -eq $obj.Ssl)
    } | Measure-Object).Count

    # if we're dealing with a certificate, attempt to import it
    if (!$isIIS -and !$isHeroku -and ($PSCmdlet.ParameterSetName -ilike 'cert*')) {
        # fail if protocol is not https
        if (@('https', 'wss') -inotcontains $Protocol) {
            throw "Certificate supplied for non-HTTPS/WSS endpoint"
        }

        switch ($PSCmdlet.ParameterSetName.ToLowerInvariant())
        {
            'certfile' {
                $obj.Certificate.Raw = Get-PodeCertificateByFile -Certificate $Certificate -Password $CertificatePassword
            }

            'certthumb' {
                $obj.Certificate.Raw = Get-PodeCertificateByThumbprint -Thumbprint $CertificateThumbprint
            }

            'certname' {
                $obj.Certificate.Raw = Get-PodeCertificateByName -Name $CertificateName
            }

            'certself' {
                $obj.Certificate.Raw = New-PodeSelfSignedCertificate
            }
        }

        # fail if the cert is expired
        if ($obj.Certificate.Raw.NotAfter -lt [datetime]::Now) {
            throw "The certificate '$($obj.Certificate.Raw.Subject)' has expired: $($obj.Certificate.Raw.NotAfter)"
        }
    }

    if (!$exists) {
        # has an endpoint already been defined for smtp/tcp?
        if ((@('smtp', 'tcp') -icontains $Protocol) -and ($Protocol -ieq $PodeContext.Server.Type)) {
            throw "An endpoint for $($Protocol.ToUpperInvariant()) has already been defined"
        }

        # set server type, ensure we aren't trying to change the server's type
        if (@('ws', 'wss') -icontains $Protocol) {
            $PodeContext.Server.WebSockets.Enabled = $true
        }
        else {
            $_type = (Resolve-PodeValue -Check ($Protocol -ieq 'https') -TrueValue 'http' -FalseValue $Protocol)

            if ([string]::IsNullOrWhiteSpace($PodeContext.Server.Type)) {
                $PodeContext.Server.Type = $_type
            }
            elseif ($PodeContext.Server.Type -ine $_type) {
                throw "Cannot add $($Protocol.ToUpperInvariant()) endpoint when already listening to $($PodeContext.Server.Type.ToUpperInvariant()) endpoints"
            }
        }

        # add the new endpoint
        $PodeContext.Server.Endpoints += $obj
    }

    # if RedirectTo is set, attempt to build a redirecting route
    if (!$isIIS -and !$isHeroku -and ![string]::IsNullOrWhiteSpace($RedirectTo)) {
        $redir_endpoint = ($PodeContext.Server.Endpoints | Where-Object { $_.Name -eq $RedirectTo } | Select-Object -First 1)

        # ensure the name exists
        if (Test-IsEmpty $redir_endpoint) {
            throw "An endpoint with the name '$($RedirectTo)' has not been defined for redirecting"
        }

        # build the redirect route
        Add-PodeRoute -Method * -Path * -EndpointName $obj.Name -ArgumentList $redir_endpoint -ScriptBlock {
            param($e, $endpoint)
            Move-PodeResponseUrl -EndpointName $endpoint.Name
        }
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
function Get-PodeEndpoint
{
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Address,

        [Parameter()]
        [int]
        $Port = 0,

        [Parameter()]
        [ValidateSet('', 'Http', 'Https', 'Smtp', 'Tcp', 'Ws', 'Wss')]
        [string]
        $Protocol,

        [Parameter()]
        [string[]]
        $Name
    )

    $endpoints = $PodeContext.Server.Endpoints

    # if we have an address, filter
    if (![string]::IsNullOrWhiteSpace($Address)) {
        if (($Address -eq '*') -or $PodeContext.Server.IsHeroku) {
            $Address = '0.0.0.0'
        }

        if ($PodeContext.Server.IsIIS) {
            $Address = '127.0.0.1'
        }

        $endpoints = @(foreach ($endpoint in $endpoints) {
            if ($endpoint.Address.ToString() -ine $Address) {
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

<#
.SYNOPSIS
Adds a new Timer with logic to periodically invoke.

.DESCRIPTION
Adds a new Timer with logic to periodically invoke, with options to only run a specific number of times.

.PARAMETER Name
The Name of the Timer.

.PARAMETER Interval
The number of seconds to periodically invoke the Timer's ScriptBlock.

.PARAMETER ScriptBlock
The script for the Timer.

.PARAMETER Limit
The number of times the Timer should be invoked before being removed. (If 0, it will run indefinitely)

.PARAMETER Skip
The number of "invokes" to skip before the Timer actually runs.

.PARAMETER ArgumentList
An array of arguments to supply to the Timer's ScriptBlock.

.PARAMETER FilePath
A literal, or relative, path to a file containing a ScriptBlock for the Timer's logic.

.PARAMETER OnStart
If supplied, the timer will trigger when the server starts.

.EXAMPLE
Add-PodeTimer -Name 'Hello' -Interval 10 -ScriptBlock { 'Hello, world!' | Out-Default }

.EXAMPLE
Add-PodeTimer -Name 'RunOnce' -Interval 1 -Limit 1 -ScriptBlock { /* logic */ }

.EXAMPLE
Add-PodeTimer -Name 'RunAfter60secs' -Interval 10 -Skip 6 -ScriptBlock { /* logic */ }

.EXAMPLE
Add-PodeTimer -Name 'Args' -Interval 2 -ScriptBlock { /* logic */ } -ArgumentList 'arg1', 'arg2'
#>
function Add-PodeTimer
{
    [CmdletBinding(DefaultParameterSetName='Script')]
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Name,

        [Parameter(Mandatory=$true)]
        [int]
        $Interval,

        [Parameter(Mandatory=$true, ParameterSetName='Script')]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [int]
        $Limit = 0,

        [Parameter()]
        [int]
        $Skip = 0,

        [Parameter(Mandatory=$true, ParameterSetName='File')]
        [string]
        $FilePath,

        [Parameter()]
        [object[]]
        $ArgumentList,

        [switch]
        $OnStart
    )

    # error if serverless
    Test-PodeIsServerless -FunctionName 'Add-PodeTimer' -ThrowError

    # ensure the timer doesn't already exist
    if ($PodeContext.Timers.ContainsKey($Name)) {
        throw "[Timer] $($Name): Timer already defined"
    }

    # is the interval valid?
    if ($Interval -le 0) {
        throw "[Timer] $($Name): Interval must be greater than 0"
    }

    # is the limit valid?
    if ($Limit -lt 0) {
        throw "[Timer] $($Name): Cannot have a negative limit"
    }

    # is the skip valid?
    if ($Skip -lt 0) {
        throw "[Timer] $($Name): Cannot have a negative skip value"
    }

    # if we have a file path supplied, load that path as a scriptblock
    if ($PSCmdlet.ParameterSetName -ieq 'file') {
        $ScriptBlock = Convert-PodeFileToScriptBlock -FilePath $FilePath
    }

    # check if the scriptblock has any using vars
    $ScriptBlock, $usingVars = Invoke-PodeUsingScriptConversion -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState

    # calculate the next tick time (based on Skip)
    $NextTriggerTime = [DateTime]::Now.AddSeconds($Interval)
    if ($Skip -gt 1) {
        $NextTriggerTime = $NextTriggerTime.AddSeconds($Interval * $Skip)
    }

    # add the timer
    $PodeContext.Timers[$Name] = @{
        Name = $Name
        Interval = $Interval
        Limit = $Limit
        Count = 0
        Skip = $Skip
        NextTriggerTime = $NextTriggerTime
        Script = $ScriptBlock
        UsingVariables = $usingVars
        Arguments = $ArgumentList
        OnStart = $OnStart
        Completed = $false
    }
}

<#
.SYNOPSIS
Adhoc invoke a Timer's logic.

.DESCRIPTION
Adhoc invoke a Timer's logic outside of its defined interval. This invocation doesn't count towards the Timer's limit.

.PARAMETER Name
The Name of the Timer.

.EXAMPLE
Invoke-PodeTimer -Name 'timer-name'
#>
function Invoke-PodeTimer
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [string]
        $Name
    )

    # ensure the timer exists
    if (!$PodeContext.Timers.ContainsKey($Name)) {
        throw "Timer '$($Name)' does not exist"
    }

    # run timer logic
    Invoke-PodeInternalTimer -Timer ($PodeContext.Timers[$Name])
}

<#
.SYNOPSIS
Removes a specific Timer.

.DESCRIPTION
Removes a specific Timer.

.PARAMETER Name
The Name of Timer to be removed.

.EXAMPLE
Remove-PodeTimer -Name 'SaveState'
#>
function Remove-PodeTimer
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [string]
        $Name
    )

    $PodeContext.Timers.Remove($Name) | Out-Null
}

<#
.SYNOPSIS
Removes all Timers.

.DESCRIPTION
Removes all Timers.

.EXAMPLE
Clear-PodeTimers
#>
function Clear-PodeTimers
{
    [CmdletBinding()]
    param()

    $PodeContext.Timers.Clear()
}

<#
.SYNOPSIS
Edits an existing Timer.

.DESCRIPTION
Edits an existing Timer's properties, such as interval or scriptblock.

.PARAMETER Name
The Name of the Timer.

.PARAMETER Interval
The new Interval for the Timer in seconds.

.PARAMETER ScriptBlock
The new ScriptBlock for the Timer.

.PARAMETER ArgumentList
Any new Arguments for the Timer.

.EXAMPLE
Edit-PodeTimer -Name 'Hello' -Interval 10
#>
function Edit-PodeTimer
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [string]
        $Name,

        [Parameter()]
        [int]
        $Interval = 0,

        [Parameter()]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [object[]]
        $ArgumentList
    )

    # ensure the timer exists
    if (!$PodeContext.Timers.ContainsKey($Name)) {
        throw "Timer '$($Name)' does not exist"
    }

    # edit interval if supplied
    if ($Interval -gt 0) {
        $PodeContext.Timers[$Name].Interval = $Interval
    }

    # edit scriptblock if supplied
    if (!(Test-IsEmpty $ScriptBlock)) {
        $PodeContext.Timers[$Name].Script = $ScriptBlock
    }

    # edit arguments if supplied
    if (!(Test-IsEmpty $ArgumentList)) {
        $PodeContext.Timers[$Name].Arguments = $ArgumentList
    }
}

<#
.SYNOPSIS
Returns any defined timers.

.DESCRIPTION
Returns any defined timers, with support for filtering.

.PARAMETER Name
Any timer Names to filter the timers.

.EXAMPLE
Get-PodeTimer

.EXAMPLE
Get-PodeTimer -Name Name1, Name2
#>
function Get-PodeTimer
{
    [CmdletBinding()]
    param(
        [Parameter()]
        [string[]]
        $Name
    )

    $timers = $PodeContext.Timers.Values

    # further filter by timer names
    if (($null -ne $Name) -and ($Name.Length -gt 0)) {
        $timers = @(foreach ($_name in $Name) {
            foreach ($timer in $timers) {
                if ($timer.Name -ine $_name) {
                    continue
                }

                $timer
            }
        })
    }

    # return
    return $timers
}

<#
.SYNOPSIS
Adds a new Schedule with logic to periodically invoke, defined using Cron Expressions.

.DESCRIPTION
Adds a new Schedule with logic to periodically invoke, defined using Cron Expressions.

.PARAMETER Name
The Name of the Schedule.

.PARAMETER Cron
One, or an Array, of Cron Expressions to define when the Schedule should trigger.

.PARAMETER ScriptBlock
The script defining the Schedule's logic.

.PARAMETER Limit
The number of times the Schedule should trigger before being removed.

.PARAMETER StartTime
A DateTime for when the Schedule should start triggering.

.PARAMETER EndTime
A DateTime for when the Schedule should stop triggering, and be removed.

.PARAMETER ArgumentList
A hashtable of arguments to supply to the Schedule's ScriptBlock.

.PARAMETER FilePath
A literal, or relative, path to a file containing a ScriptBlock for the Schedule's logic.

.PARAMETER OnStart
If supplied, the schedule will trigger when the server starts, regardless if the cron-expression matches the current time.

.EXAMPLE
Add-PodeSchedule -Name 'RunEveryMinute' -Cron '@minutely' -ScriptBlock { /* logic */ }

.EXAMPLE
Add-PodeSchedule -Name 'RunEveryTuesday' -Cron '0 0 * * TUE' -ScriptBlock { /* logic */ }

.EXAMPLE
Add-PodeSchedule -Name 'StartAfter2days' -Cron '@hourly' -StartTime [DateTime]::Now.AddDays(2) -ScriptBlock { /* logic */ }

.EXAMPLE
Add-PodeSchedule -Name 'Args' -Cron '@minutely' -ScriptBlock { /* logic */ } -ArgumentList @{ Arg1 = 'value' }
#>
function Add-PodeSchedule
{
    [CmdletBinding(DefaultParameterSetName='Script')]
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Name,

        [Parameter(Mandatory=$true)]
        [string[]]
        $Cron,

        [Parameter(Mandatory=$true, ParameterSetName='Script')]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [int]
        $Limit = 0,

        [Parameter()]
        [DateTime]
        $StartTime,

        [Parameter()]
        [DateTime]
        $EndTime,

        [Parameter(Mandatory=$true, ParameterSetName='File')]
        [string]
        $FilePath,

        [Parameter()]
        [hashtable]
        $ArgumentList,

        [switch]
        $OnStart
    )

    # error if serverless
    Test-PodeIsServerless -FunctionName 'Add-PodeSchedule' -ThrowError

    # ensure the schedule doesn't already exist
    if ($PodeContext.Schedules.ContainsKey($Name)) {
        throw "[Schedule] $($Name): Schedule already defined"
    }

    # ensure the limit is valid
    if ($Limit -lt 0) {
        throw "[Schedule] $($Name): Cannot have a negative limit"
    }

    # ensure the start/end dates are valid
    if (($null -ne $EndTime) -and ($EndTime -lt [DateTime]::Now)) {
        throw "[Schedule] $($Name): The EndTime value must be in the future"
    }

    if (($null -ne $StartTime) -and ($null -ne $EndTime) -and ($EndTime -le $StartTime)) {
        throw "[Schedule] $($Name): Cannot have a StartTime after the EndTime"
    }

    # if we have a file path supplied, load that path as a scriptblock
    if ($PSCmdlet.ParameterSetName -ieq 'file') {
        $ScriptBlock = Convert-PodeFileToScriptBlock -FilePath $FilePath
    }

    # check if the scriptblock has any using vars
    $ScriptBlock, $usingVars = Invoke-PodeUsingScriptConversion -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState

    # add the schedule
    $parsedCrons = ConvertFrom-PodeCronExpressions -Expressions @($Cron)
    $nextTrigger = Get-PodeCronNextEarliestTrigger -Expressions $parsedCrons -StartTime $StartTime -EndTime $EndTime

    $PodeContext.Schedules[$Name] = @{
        Name = $Name
        StartTime = $StartTime
        EndTime = $EndTime
        Crons = $parsedCrons
        CronsRaw = @($Cron)
        Limit = $Limit
        Count = 0
        NextTriggerTime = $nextTrigger
        Script = $ScriptBlock
        UsingVariables = $usingVars
        Arguments = (Protect-PodeValue -Value $ArgumentList -Default @{})
        OnStart = $OnStart
        Completed = ($null -eq $nextTrigger)
    }
}

<#
.SYNOPSIS
Set the maximum number of concurrent schedules.

.DESCRIPTION
Set the maximum number of concurrent schedules.

.PARAMETER Maximum
The Maximum number of schdules to run.

.EXAMPLE
Set-PodeScheduleConcurrency -Maximum 25
#>
function Set-PodeScheduleConcurrency
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [int]
        $Maximum
    )

    # error if <=0
    if ($Maximum -le 0) {
        throw "Maximum concurrent schedules must be >=1 but got: $($Maximum)"
    }

    # ensure max > min
    $_min = 1
    if ($null -ne $PodeContext.RunspacePools.Schedules) {
        $_min = $PodeContext.RunspacePools.Schedules.GetMinRunspaces()
    }

    if ($_min -gt $Maximum) {
        throw "Maximum concurrent schedules cannot be less than the minimum of $($_min) but got: $($Maximum)"
    }

    # set the max schedules
    $PodeContext.Threads.Schedules = $Maximum
    if ($null -ne $PodeContext.RunspacePools.Schedules) {
        $PodeContext.RunspacePools.Schedules.SetMaxRunspaces($Maximum)
    }
}

<#
.SYNOPSIS
Adhoc invoke a Schedule's logic.

.DESCRIPTION
Adhoc invoke a Schedule's logic outside of its defined cron-expression. This invocation doesn't count towards the Schedule's limit.

.PARAMETER Name
The Name of the Schedule.

.EXAMPLE
Invoke-PodeSchedule -Name 'schedule-name'
#>
function Invoke-PodeSchedule
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [string]
        $Name
    )

    # ensure the schedule exists
    if (!$PodeContext.Schedules.ContainsKey($Name)) {
        throw "Schedule '$($Name)' does not exist"
    }

    # run schedule logic
    Invoke-PodeInternalScheduleLogic -Schedule ($PodeContext.Schedules[$Name])
}

<#
.SYNOPSIS
Removes a specific Schedule.

.DESCRIPTION
Removes a specific Schedule.

.PARAMETER Name
The Name of the Schedule to be removed.

.EXAMPLE
Remove-PodeSchedule -Name 'RenewToken'
#>
function Remove-PodeSchedule
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [string]
        $Name
    )

    $PodeContext.Schedules.Remove($Name) | Out-Null
}

<#
.SYNOPSIS
Removes all Schedules.

.DESCRIPTION
Removes all Schedules.

.EXAMPLE
Clear-PodeSchedules
#>
function Clear-PodeSchedules
{
    [CmdletBinding()]
    param()

    $PodeContext.Schedules.Clear()
}

<#
.SYNOPSIS
Edits an existing Schedule.

.DESCRIPTION
Edits an existing Schedule's properties, such an cron expressions or scriptblock.

.PARAMETER Name
The Name of the Schedule.

.PARAMETER Cron
Any new Cron Expressions for the Schedule.

.PARAMETER ScriptBlock
The new ScriptBlock for the Schedule.

.PARAMETER ArgumentList
Any new Arguments for the Schedule.

.EXAMPLE
Edit-PodeSchedule -Name 'Hello' -Cron '@minutely'

.EXAMPLE
Edit-PodeSchedule -Name 'Hello' -Cron @('@hourly', '0 0 * * TUE')
#>
function Edit-PodeSchedule
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [string]
        $Name,

        [Parameter()]
        [string[]]
        $Cron,

        [Parameter()]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [hashtable]
        $ArgumentList
    )

    # ensure the schedule exists
    if (!$PodeContext.Schedules.ContainsKey($Name)) {
        throw "Schedule '$($Name)' does not exist"
    }

    $_schedule = $PodeContext.Schedules[$Name]

    # edit cron if supplied
    if (!(Test-IsEmpty $Cron)) {
        $_schedule.Crons = (ConvertFrom-PodeCronExpressions -Expressions @($Cron))
        $_schedule.CronsRaw = $Cron
        $_schedule.NextTriggerTime = Get-PodeCronNextEarliestTrigger -Expressions $_schedule.Crons -StartTime $_schedule.StartTime -EndTime $_schedule.EndTime
    }

    # edit scriptblock if supplied
    if (!(Test-IsEmpty $ScriptBlock)) {
        $_schedule.Script = $ScriptBlock
    }

    # edit arguments if supplied
    if (!(Test-IsEmpty $ArgumentList)) {
        $_schedule.Arguments = $ArgumentList
    }
}

<#
.SYNOPSIS
Returns any defined schedules.

.DESCRIPTION
Returns any defined schedules, with support for filtering.

.PARAMETER Name
Any schedule Names to filter the schedules.

.PARAMETER StartTime
An optional StartTime to only return Schedules that will trigger after this date.

.PARAMETER EndTime
An optional EndTime to only return Schedules that will trigger before this date.

.EXAMPLE
Get-PodeSchedule

.EXAMPLE
Get-PodeSchedule -Name Name1, Name2

.EXAMPLE
Get-PodeSchedule -Name Name1, Name2 -StartTime [datetime]::new(2020, 3, 1) -EndTime [datetime]::new(2020, 3, 31)
#>
function Get-PodeSchedule
{
    [CmdletBinding()]
    param(
        [Parameter()]
        [string[]]
        $Name,

        [Parameter()]
        $StartTime = $null,

        [Parameter()]
        $EndTime = $null
    )

    $schedules = $PodeContext.Schedules.Values

    # further filter by schedule names
    if (($null -ne $Name) -and ($Name.Length -gt 0)) {
        $schedules = @(foreach ($_name in $Name) {
            foreach ($schedule in $schedules) {
                if ($schedule.Name -ine $_name) {
                    continue
                }

                $schedule
            }
        })
    }

    # filter by some start time
    if ($null -ne $StartTime) {
        $schedules = @(foreach ($schedule in $schedules) {
            if (($null -ne $schedule.StartTime) -and ($StartTime -lt $schedule.StartTime)) {
                continue
            }

            $_end = $EndTime
            if ($null -eq $_end) {
                $_end = $schedule.EndTime
            }

            if (($null -ne $schedule.EndTime) -and
                (($StartTime -gt $schedule.EndTime) -or
                    ((Get-PodeScheduleNextTrigger -Name $schedule.Name -DateTime $StartTime) -gt $_end))) {
                continue
            }

            $schedule
        })
    }

    # filter by some end time
    if ($null -ne $EndTime) {
        $schedules = @(foreach ($schedule in $schedules) {
            if (($null -ne $schedule.EndTime) -and ($EndTime -gt $schedule.EndTime)) {
                continue
            }

            $_start = $StartTime
            if ($null -eq $_start) {
                $_start = $schedule.StartTime
            }

            if (($null -ne $schedule.StartTime) -and
                (($EndTime -lt $schedule.StartTime) -or
                    ((Get-PodeScheduleNextTrigger -Name $schedule.Name -DateTime $_start) -gt $EndTime))) {
                continue
            }

            $schedule
        })
    }

    # return
    return $schedules
}

<#
.SYNOPSIS
Get the next trigger time for a Schedule.

.DESCRIPTION
Get the next trigger time for a Schedule, either from the Schedule's StartTime or from a defined DateTime.

.PARAMETER Name
The Name of the Schedule.

.PARAMETER DateTime
An optional specific DateTime to get the next trigger time after. This DateTime must be between the Schedule's StartTime and EndTime.

.EXAMPLE
Get-PodeScheduleNextTrigger -Name Schedule1

.EXAMPLE
Get-PodeScheduleNextTrigger -Name Schedule1 -DateTime [datetime]::new(2020, 3, 10)
#>
function Get-PodeScheduleNextTrigger
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [string]
        $Name,

        [Parameter()]
        $DateTime = $null
    )

    # ensure the schedule exists
    if (!$PodeContext.Schedules.ContainsKey($Name)) {
        throw "Schedule '$($Name)' does not exist"
    }

    $_schedule = $PodeContext.Schedules[$Name]

    # ensure date is after start/before end
    if (($null -ne $DateTime) -and ($null -ne $_schedule.StartTime) -and ($DateTime -lt $_schedule.StartTime)) {
        throw "Supplied date is before the start time of the schedule at $($_schedule.StartTime)"
    }

    if (($null -ne $DateTime) -and ($null -ne $_schedule.EndTime) -and ($DateTime -gt $_schedule.EndTime)) {
        throw "Supplied date is after the end time of the schedule at $($_schedule.EndTime)"
    }

    # get the next trigger
    if ($null -eq $DateTime) {
        $DateTime = $_schedule.StartTime
    }

    return (Get-PodeCronNextEarliestTrigger -Expressions $_schedule.Crons -StartTime $DateTime -EndTime $_schedule.EndTime)
}

<#
.SYNOPSIS
Adds a new Middleware to be invoked before every Route, or certain Routes.

.DESCRIPTION
Adds a new Middleware to be invoked before every Route, or certain Routes.

.PARAMETER Name
The Name of the Middleware.

.PARAMETER ScriptBlock
The Script defining the logic of the Middleware.

.PARAMETER InputObject
A Middleware HashTable from New-PodeMiddleware, or from certain other functions that return Middleware as a HashTable.

.PARAMETER Route
A Route path for which Routes this Middleware should only be invoked against.

.PARAMETER ArgumentList
An array of arguments to supply to the Middleware's ScriptBlock.

.EXAMPLE
Add-PodeMiddleware -Name 'BlockAgents' -ScriptBlock { /* logic */ }

.EXAMPLE
Add-PodeMiddleware -Name 'CheckEmailOnApi' -Route '/api/*' -ScriptBlock { /* logic */ }
#>
function Add-PodeMiddleware
{
    [CmdletBinding(DefaultParameterSetName='Script')]
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Name,

        [Parameter(Mandatory=$true, ParameterSetName='Script')]
        [scriptblock]
        $ScriptBlock,

        [Parameter(Mandatory=$true, ParameterSetName='Input', ValueFromPipeline=$true)]
        [hashtable]
        $InputObject,

        [Parameter()]
        [string]
        $Route,

        [Parameter()]
        [object[]]
        $ArgumentList
    )

    # ensure name doesn't already exist
    if (($PodeContext.Server.Middleware | Where-Object { $_.Name -ieq $Name } | Measure-Object).Count -gt 0) {
        throw "[Middleware] $($Name): Middleware already defined"
    }

    # if it's a script - call New-PodeMiddleware
    if ($PSCmdlet.ParameterSetName -ieq 'script') {
        $InputObject = New-PodeMiddleware -ScriptBlock $ScriptBlock -Route $Route -ArgumentList $ArgumentList
    }
    else {
        if (![string]::IsNullOrWhiteSpace($Route)) {
            $Route = ConvertTo-PodeRouteRegex -Path $Route
        }

        $InputObject.Route = Protect-PodeValue -Value $Route -Default $InputObject.Route
        $InputObject.Options = Protect-PodeValue -Value $Options -Default $InputObject.Options
    }

    # ensure we have a script to run
    if (Test-IsEmpty $InputObject.Logic) {
        throw "[Middleware]: No logic supplied in ScriptBlock"
    }

    # set name, and override route/args
    $InputObject.Name = $Name

    # add the logic to array of middleware that needs to be run
    $PodeContext.Server.Middleware += $InputObject
}

<#
.SYNOPSIS
Creates a new Middleware HashTable object, that can be piped/used in Add-PodeMiddleware or in Routes.

.DESCRIPTION
Creates a new Middleware HashTable object, that can be piped/used in Add-PodeMiddleware or in Routes.

.PARAMETER ScriptBlock
The Script that defines the logic of the Middleware.

.PARAMETER Route
A Route path for which Routes this Middleware should only be invoked against.

.PARAMETER ArgumentList
An array of arguments to supply to the Middleware's ScriptBlock.

.EXAMPLE
New-PodeMiddleware -ScriptBlock { /* logic */ } -ArgumentList 'Email' | Add-PodeMiddleware -Name 'CheckEmail'
#>
function New-PodeMiddleware
{
    [CmdletBinding()]
    [OutputType([hashtable])]
    param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [string]
        $Route,

        [Parameter()]
        [object[]]
        $ArgumentList
    )

    # if route is empty, set it to root
    $Route = ConvertTo-PodeRouteRegex -Path $Route

    # create the middleware hashtable from a scriptblock
    $HashTable = @{
        Route = $Route
        Logic = $ScriptBlock
        Arguments = $ArgumentList
    }

    if (Test-IsEmpty $HashTable.Logic) {
        throw "[Middleware]: No logic supplied in ScriptBlock"
    }

    # return the middleware, so it can be cached/added at a later date
    return $HashTable
}

<#
.SYNOPSIS
Removes a specific user defined Middleware.

.DESCRIPTION
Removes a specific user defined Middleware.

.PARAMETER Name
The Name of the Middleware to be removed.

.EXAMPLE
Remove-PodeMiddleware -Name 'Sessions'
#>
function Remove-PodeMiddleware
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Name
    )

    $PodeContext.Server.Middleware = @($PodeContext.Server.Middleware | Where-Object { $_.Name -ine $Name })
}

<#
.SYNOPSIS
Removes all user defined Middleware.

.DESCRIPTION
Removes all user defined Middleware.

.EXAMPLE
Clear-PodeMiddleware
#>
function Clear-PodeMiddleware
{
    [CmdletBinding()]
    param()

    $PodeContext.Server.Middleware = @()
}