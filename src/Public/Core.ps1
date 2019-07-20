<#
.SYNOPSIS
Starts a Pode Server with the supplied ScriptBlock.

.DESCRIPTION
Starts a Pode Server with the supplied ScriptBlock.

.PARAMETER ScriptBlock
The main logic for the Server.

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

.PARAMETER DisableTermination
Disables the ability to terminate the Server.

.PARAMETER DisableLogging
Disables all logging functionality of the Server.

.PARAMETER Browse
Open the web Server's default endpoint in your defualt browser.

.EXAMPLE
Start-PodeServer {
    # logic
}

.EXAMPLE
Start-PodeServer -Interval 10 {
    # loop this logic every 10secs
}

.EXAMPLE
Start-PodeServer -Request $LambdaInput -Type 'AwsLambda' {
    # run this logic using the inbuilt AWS Lambda routing engine
}
#>
function Start-PodeServer
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [scriptblock]
        $ScriptBlock,

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
        $Type,

        [switch]
        $DisableTermination,

        [switch]
        $DisableLogging,

        [switch]
        $Browse
    )

    # ensure the session is clean
    $PodeContext = $null

    try {
        # configure the server's root path
        if (!(Test-IsEmpty $RootPath)) {
            $RootPath = Get-PodeRelativePath -Path $RootPath -RootPath $MyInvocation.PSScriptRoot -JoinRoot -Resolve -TestPath
        }

        # create main context object
        $PodeContext = New-PodeContext -ScriptBlock $ScriptBlock `
            -Threads $Threads `
            -Interval $Interval `
            -ServerRoot (Protect-PodeValue -Value $RootPath -Default $MyInvocation.PSScriptRoot) `
            -ServerType $Type `
            -DisableLogging:$DisableLogging

        # set it so ctrl-c can terminate, unless serverless
        if (!$PodeContext.Server.IsServerless) {
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
        }

        Write-Host 'Terminating...' -NoNewline -ForegroundColor Yellow
        $PodeContext.Tokens.Cancellation.Cancel()
    }
    finally {
        # clean the runspaces and tokens
        Close-PodeServer -Exit

        # clean the session
        $PodeContext = $null
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
Enable-PodeGui -Title 'MyApplication' -WindowState 'Maximized'
#>
function Enable-PodeGui
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
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
    Test-PodeIsServerless -FunctionName 'Enable-PodeGui' -ThrowError

    # only valid for Windows PowerShell
    if (Test-IsPSCore) {
        throw 'The gui function is currently unavailable for PS Core, and only works for Windows PowerShell'
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
The IP:Port or Hostname:Port endpoint address.

.PARAMETER Protocol
The protocol of the supplied endpoint.

.PARAMETER Certificate
A certificate name to find and bind onto HTTPS endpoints (Windows only).

.PARAMETER CertificateThumbprint
A certificate thumbprint to bind onto HTTPS endpoints (Windows only).

.PARAMETER Name
An optional name for the endpoint, that can be used with other functions.

.PARAMETER Force
Ignore Adminstrator checks for non-localhost endpoints.

.PARAMETER SelfSigned
Create and bind a self-signed certifcate onto HTTPS endpoints (Windows only).

.EXAMPLE
Add-PodeEndpoint -Address localhost:8090 -Protocol Http

.EXAMPLE
Add-PodeEndpoint -Address localhost -Protocol Smtp

.EXAMPLE
Add-PodeEndpoint -Address dev.pode.com:8443 -Protocol Https -SelfSigned

.EXAMPLE
Add-PodeEndpoint -Address live.pode.com -Protocol Https -CertificateThumbprint '2A9467F7D3940243D6C07DE61E7FCCE292'
#>
function Add-PodeEndpoint
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Address,

        [Parameter()]
        [ValidateSet('Http', 'Https', 'Smtp', 'Tcp')]
        [string]
        $Protocol,

        [Parameter()]
        [string]
        $Certificate = $null,

        [Parameter()]
        [string]
        $CertificateThumbprint = $null,

        [Parameter()]
        [string]
        $Name = $null,

        [switch]
        $Force,

        [switch]
        $SelfSigned
    )

    # error if serverless
    Test-PodeIsServerless -FunctionName 'Add-PodeEndpoint' -ThrowError

    # parse the endpoint for host/port info
    $_endpoint = Get-PodeEndpointInfo -Endpoint $Address

    # if a name was supplied, check it is unique
    if (!(Test-IsEmpty $Name) -and
        (Get-PodeCount ($PodeContext.Server.Endpoints | Where-Object { $_.Name -eq $Name })) -ne 0)
    {
        throw "An endpoint with the name '$($Name)' has already been defined"
    }

    # new endpoint object
    $obj = @{
        Name = $Name
        Address = $null
        RawAddress = $Address
        Port = $null
        IsIPAddress = $true
        HostName = 'localhost'
        Ssl = ($Protocol -ieq 'https')
        Protocol = $Protocol
        Certificate = @{
            Name = $Certificate
            Thumbprint = $CertificateThumbprint
            SelfSigned = $SelfSigned
        }
    }

    # set the ip for the context
    $obj.Address = (Get-PodeIPAddress $_endpoint.Host)
    if (!(Test-PodeIPAddressLocalOrAny -IP $obj.Address)) {
        $obj.HostName = "$($obj.Address)"
    }

    $obj.IsIPAddress = (Test-PodeIPAddress -IP $obj.Address -IPOnly)

    # set the port for the context
    $obj.Port = $_endpoint.Port

    # if the address is non-local, then check admin privileges
    if (!$Force -and !(Test-PodeIPAddressLocal -IP $obj.Address) -and !(Test-IsAdminUser)) {
        throw 'Must be running with administrator priviledges to listen on non-localhost addresses'
    }

    # has this endpoint been added before? (for http/https we can just not add it again)
    $exists = ($PodeContext.Server.Endpoints | Where-Object {
        ($_.Address -eq $obj.Address) -and ($_.Port -eq $obj.Port) -and ($_.Ssl -eq $obj.Ssl)
    } | Measure-Object).Count

    if (!$exists) {
        # has an endpoint already been defined for smtp/tcp?
        if (@('smtp', 'tcp') -icontains $Protocol -and $Protocol -ieq $PodeContext.Server.Type) {
            throw "An endpoint for $($Protocol.ToUpperInvariant()) has already been defined"
        }

        # set server type, ensure we aren't trying to change the server's type
        $_type = (Resolve-PodeValue -Check ($Protocol -ieq 'https') -TrueValue 'http' -FalseValue $Protocol)
        if ([string]::IsNullOrWhiteSpace($PodeContext.Server.Type)) {
            $PodeContext.Server.Type = $_type
        }
        elseif ($PodeContext.Server.Type -ine $_type) {
            throw "Cannot add $($Protocol.ToUpperInvariant()) endpoint when already listening to $($PodeContext.Server.Type.ToUpperInvariant()) endpoints"
        }

        # add the new endpoint
        $PodeContext.Server.Endpoints += $obj
    }
}

function Add-PodeTimer
{
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Name,

        [Parameter(Mandatory=$true)]
        [int]
        $Interval,

        [Parameter(Mandatory=$true)]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [int]
        $Limit = 0,

        [Parameter()]
        [int]
        $Skip = 0
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

    if ($Limit -ne 0) {
        $Limit += $Skip
    }

    # is the skip valid?
    if ($Skip -lt 0) {
        throw "[Timer] $($Name): Cannot have a negative skip value"
    }

    # add the timer
    $PodeContext.Timers[$Name] = @{
        Name = $Name
        Interval = $Interval
        Limit = $Limit
        Count = 0
        Skip = $Skip
        Countable = ($Skip -gt 0 -or $Limit -gt 0)
        NextTick = [DateTime]::Now.AddSeconds($Interval)
        Script = $ScriptBlock
    }
}

function Remove-PodeTimer
{
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Name
    )

    $PodeContext.Timers.Remove($Name) | Out-Null
}

function Clear-PodeTimers
{
    $PodeContext.Timers.Clear()
}

function Add-PodeSchedule
{
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Name,

        [Parameter(Mandatory=$true)]
        [string[]]
        $Cron,

        [Parameter(Mandatory=$true)]
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
        $EndTime
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

    if (($null -ne $StartTime) -and ($null -ne $EndTime) -and ($EndTime -lt $StartTime)) {
        throw "[Schedule] $($Name): Cannot have a StartTime after the EndTime"
    }

    # add the schedule
    $PodeContext.Schedules[$Name] = @{
        Name = $Name
        StartTime = $StartTime
        EndTime = $EndTime
        Crons = (ConvertFrom-PodeCronExpressions -Expressions @($Cron))
        Limit = $Limit
        Count = 0
        Countable = ($Limit -gt 0)
        Script = $ScriptBlock
    }
}

function Remove-PodeSchedule
{
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Name
    )

    $PodeContext.Schedules.Remove($Name) | Out-Null
}

function Clear-PodeSchedules
{
    $PodeContext.Schedules.Clear()
}