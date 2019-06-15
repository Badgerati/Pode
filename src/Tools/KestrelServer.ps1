#using namespace System
#using namespace System.Collections.Generic
#using namespace System.IO
#using namespace System.Linq
#using namespace System.Reflection
using namespace System.Threading
using namespace System.Threading.Tasks
#using namespace System.Management.Automation
using namespace Microsoft.AspNetCore
using namespace Microsoft.AspNetCore.Hosting
#using namespace Microsoft.AspNetCore.Hosting.Internal
#using namespace Microsoft.Extensions.Logging.Console
using namespace Microsoft.AspNetCore.Builder
using namespace Microsoft.AspNetCore.Http
using namespace Microsoft.AspNetCore.Server.Kestrel.Core
#using namespace Microsoft.Extensions.FileProviders
using namespace Microsoft.AspNetCore.Routing
using namespace Microsoft.Extensions.DependencyInjection
#using namespace Microsoft.AspNetCore.Routing.Internal
#using namespace Microsoft.AspNetCore.Routing.Patterns
#using namespace Microsoft.AspNetCore.Routing.Constraints

Import-Module PSLambda -Force

function Write-Things($m) {
    # this fails
    #if (Test-Empty $m) {
    #    Write-Host 'eek'
    #}
    #else {
        Write-Host $m
    #}
}

class Something
{
    [void] static TestLoop($a) {
        write-host 'starting'
        start-sleep -seconds 2
        write-host 'ending'
        #foreach ($i in $a) { Write-Things $i }
    }
}

class PodeStartup
{
    [void] Configure([IApplicationBuilder]$app, [IHostingEnvironment]$env) {
        Write-Host "Configuring Pode"
        #if($Script:UseFileServer) {
        #    [FileServerExtensions]::UseFileServer($app, $true)
        #}

        #$rb = [RouteBuilder]::new($app);
        #$app.Use([Func[RequestDelegate,RequestDelegate]]{
        #    param($a, $b)
        #})

        $r = [RouteHandler]::new([RequestDelegate][PSDelegate]{
            param([DefaultHttpContext]$context)
            $req = $context.Request
            [Console]::WriteLine($req.Path.Value)
            [Something]::TestLoop(1..100)
            [Task] $task = [HttpResponseWritingExtensions]::WriteAsync($context.Response, 'Hello!', [CancellationToken]::None)
            $task.GetAwaiter()
            return $task
            #return $context.Response.WriteAsync("Hello!")
        })

        $rb = [RouteBuilder]::new($app, $r)

        #[Microsoft.AspNetCore.BuilderMapRouteRouteBuilderExtensions]::MapRoute($rb,
        [MapRouteRouteBuilderExtensions]::MapRoute($rb,
            "Track Package Route",
            "/{operation:regex(.*)}")

        $routes = $rb.Build()
        #[Microsoft.AspNetCore.Builder.RoutingBuilderExtensions]::UseRouter($app, $routes)
        [RoutingBuilderExtensions]::UseRouter($app, $routes)

        #[Microsoft.AspNetCore.Builder.StatusCodePagesExtensions]::UseStatusCodePages($app)
        #[Microsoft.AspNetCore.Builder.ExceptionHandlerExtensions]::UseExceptionHandler($app, {
        #    param($handler)
        #    $handler | Out-Default
        #})

        #[Microsoft.AspNetCore.Builder.RunExtensions]::Run($app, {
        #    param($context)
        #    'hello' | Out-Default
        #    $context | Out-Default
        #})

        #[RequestDelegate][PSDelegate]{
        #    param([HttpContext] $httpContext)
        #    [Console]::WriteLine("DefaultEndpointDataSource One")
        #    [HttpResponse] $response = $httpContext.Response
        #    [Task] $task = [HttpResponseWritingExtensions]::WriteAsync($response, 'DefaultEndpointDataSource One', [CancellationToken]::None)
        #    $task.GetAwaiter()
        #    return $task
        #}
    }

    [void] ConfigureServices([IServiceCollection]$svc) {
        Write-Host "Configuring Pode Services"
        #[Microsoft.Extensions.DependencyInjection.RoutingServiceCollectionExtensions]::AddRouting($svc)
        [RoutingServiceCollectionExtensions]::AddRouting($svc)
    }
}

function Start-PodeKestrelServer
{
    param (
        [switch]
        $Browse
    )

    if (!(Test-IsPSCore)) {
        throw 'Needs to be run from PowerShell Core'
    }

    Write-Host 'Create'

    $builder = [WebHostBuilder]::new()
    $builder = [WebHostBuilderExtensions]::UseStartup($builder, [PodeStartup])
    $builder = [WebHostBuilderKestrelExtensions]::UseKestrel($builder, [Action[KestrelServerOptions]] {
        param($options)

        $options.Listen([IPAddress]::Any, 8090)

        # $options.Listen([IPAddress]::Any, 8081,
        # { param($listenOptions)
        #     $listenOptions.UseHttps("testCert.pfx", "testPassword");
        # });
    })

    #$builder = $builder.ConfigureServices([Action[IServiceCollection]] {
    #    param($svc)
    #    $svc.AddRouting()
    #})

    $webhost = $builder.build()
    [WebHostExtensions]::RunAsync($webhost, $PodeContext.Tokens.Cancellation.Token)
    #$l = $webhost.Start()
    #$l.StartAsync($PodeContext.Tokens.Cancellation)

    Write-Host 'End'

    # setup any inbuilt middleware
    <#$inbuilt_middleware = @(
        (Get-PodeAccessMiddleware),
        (Get-PodeLimitMiddleware),
        (Get-PodePublicMiddleware),
        (Get-PodeRouteValidateMiddleware),
        (Get-PodeBodyMiddleware),
        (Get-PodeQueryMiddleware)
    )

    $PodeContext.Server.Middleware = ($inbuilt_middleware + $PodeContext.Server.Middleware)

    # work out which endpoints to listen on
    $endpoints = @()
    $PodeContext.Server.Endpoints | ForEach-Object {
        # get the protocol
        $_protocol = (iftet $_.Ssl 'https' 'http')

        # get the ip address
        $_ip = "$($_.Address)"
        if ($_ip -ieq '0.0.0.0') {
            $_ip = '*'
        }

        # get the port
        $_port = [int]($_.Port)
        if ($_port -eq 0) {
            $_port = (iftet $_.Ssl 8443 8080)
        }

        # if this endpoint is https, generate a self-signed cert or bind an existing one
        if ($_.Ssl) {
            $addr = (iftet $_.IsIPAddress $_.Address $_.HostName)
            Set-PodeCertificate -Address $addr -Port $_port -Certificate $_.Certificate.Name -Thumbprint $_.Certificate.Thumbprint
        }

        # add endpoint to list
        $endpoints += @{
            Prefix = "$($_protocol)://$($_ip):$($_port)/"
            HostName = "$($_protocol)://$($_.HostName):$($_port)/"
        }
    }

    # create the listener on http and/or https
    $listener = New-Object System.Net.HttpListener

    try
    {
        # start listening on defined endpoints
        $endpoints | ForEach-Object {
            $listener.Prefixes.Add($_.Prefix)
        }

        $listener.Start()
    }
    catch {
        $Error[0] | Out-Default

        if ($null -ne $Listener) {
            if ($Listener.IsListening) {
                $Listener.Stop()
            }

            dispose $Listener -Close
        }

        throw $_.Exception
    }

    # script for listening out for incoming requests
    $listenScript = {
        param (
            [Parameter(Mandatory=$true)]
            [ValidateNotNull()]
            $Listener,

            [Parameter(Mandatory=$true)]
            [int]
            $ThreadId
        )

        try
        {
            while ($Listener.IsListening -and !$PodeContext.Tokens.Cancellation.IsCancellationRequested)
            {
                # get request and response
                $context = (await $Listener.GetContextAsync())

                try
                {
                    $request = $context.Request
                    $response = $context.Response

                    # reset event data
                    $WebEvent = @{
                        OnEnd = @()
                        Auth = @{}
                        Response = $response
                        Request = $request
                        Lockable = $PodeContext.Lockable
                        Path = ($request.RawUrl -isplit "\?")[0]
                        Method = $request.HttpMethod.ToLowerInvariant()
                        Protocol = $request.Url.Scheme
                        Endpoint = $request.Url.Authority
                        ContentType = $request.ContentType
                        ErrorType = $null
                        Cookies = $request.Cookies
                        PendingCookies = @{}
                    }

                    # set pode in server response header
                    Set-PodeServerHeader

                    # add logging endware for post-request
                    Add-PodeLogEndware -WebEvent $WebEvent

                    # invoke middleware
                    if ((Invoke-PodeMiddleware -WebEvent $WebEvent -Middleware $PodeContext.Server.Middleware -Route $WebEvent.Path)) {
                        # get the route logic
                        $route = Get-PodeRoute -HttpMethod $WebEvent.Method -Route $WebEvent.Path -Protocol $WebEvent.Protocol `
                            -Endpoint $WebEvent.Endpoint -CheckWildMethod

                        # invoke route and custom middleware
                        if ((Invoke-PodeMiddleware -WebEvent $WebEvent -Middleware $route.Middleware)) {
                            Invoke-ScriptBlock -ScriptBlock $route.Logic -Arguments $WebEvent -Scoped
                        }
                    }
                }
                catch {
                    status 500 -e $_
                    $Error[0] | Out-Default
                }

                # invoke endware specifc to the current web event
                $_endware = ($WebEvent.OnEnd + @($PodeContext.Server.Endware))
                Invoke-PodeEndware -WebEvent $WebEvent -Endware $_endware

                # close response stream (check if exists, as closing the writer closes this stream on unix)
                if ($response.OutputStream) {
                    dispose $response.OutputStream -Close -CheckNetwork
                }
            }
        }
        catch [System.OperationCanceledException] {}
        catch {
            $Error[0] | Out-Default
            throw $_.Exception
        }
    }

    # start the runspace for listening on x-number of threads
    1..$PodeContext.Threads | ForEach-Object {
        Add-PodeRunspace -Type 'Main' -ScriptBlock $listenScript `
            -Parameters @{ 'Listener' = $listener; 'ThreadId' = $_ }
    }

    # script to keep web server listening until cancelled
    $waitScript = {
        param (
            [Parameter(Mandatory=$true)]
            [ValidateNotNull()]
            $Listener
        )

        try
        {
            while ($Listener.IsListening -and !$PodeContext.Tokens.Cancellation.IsCancellationRequested)
            {
                Start-Sleep -Seconds 1
            }
        }
        catch [System.OperationCanceledException] {}
        catch {
            $Error[0] | Out-Default
            throw $_.Exception
        }
        finally {
            if ($null -ne $Listener) {
                if ($Listener.IsListening) {
                    $Listener.Stop()
                }

                dispose $Listener -Close
            }
        }
    }

    Add-PodeRunspace -Type 'Main' -ScriptBlock $waitScript -Parameters @{ 'Listener' = $listener }

    # state where we're running
    Write-Host "Listening on the following $($endpoints.Length) endpoint(s) [$($PodeContext.Threads) thread(s)]:" -ForegroundColor Yellow

    $endpoints | ForEach-Object {
        Write-Host "`t- $($_.HostName)" -ForegroundColor Yellow
    }

    # browse to the first endpoint, if flagged
    if ($Browse) {
        Start-Process $endpoints[0].HostName
    }#>
}