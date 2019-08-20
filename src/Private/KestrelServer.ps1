using namespace System.Threading
using namespace System.Threading.Tasks
using namespace System.Collections.Concurrent
using namespace Microsoft.AspNetCore
using namespace Microsoft.AspNetCore.Hosting
using namespace Microsoft.AspNetCore.Builder
using namespace Microsoft.AspNetCore.Http
using namespace Microsoft.AspNetCore.Server.Kestrel.Core
using namespace Microsoft.AspNetCore.Routing
using namespace Microsoft.Extensions.DependencyInjection

class PodeKestrelListener
{
    static [PodeKestrelListener] $instance = $null

    static [PodeKestrelListener] GetInstance() {
        if ($null -eq [PodeKestrelListener]::instance) {
            [PodeKestrelListener]::instance = [PodeKestrelListener]::new()
        }

        return [PodeKestrelListener]::instance
    }

    [ConcurrentQueue[object]] $Contexts = [ConcurrentQueue[object]]::new()

    [Task] AddContext($context) {
        $token = [System.Threading.CancellationTokenSource]::new()
        $h = @{
            Context = $context
            Token = $token
        }

        $task = [PodeTask]::CreateDelayTask($token)
        $task.Start()

        $this.Contexts.Enqueue($h)
        return $task
    }

    [Task] GetContextAsync() {
        $task = [PodeTask]::CreateContextTask($this.Contexts)
        $task.Start()
        return $task
    }
}

class PodeKestrelStartup
{
    [void] Configure([IApplicationBuilder]$app, [IHostingEnvironment]$env) {
        $listener = [PodeKestrelListener]::GetInstance()

        $r = [RouteHandler]::new([RequestDelegate][PSDelegate]{
            param([DefaultHttpContext]$context)

            $task = $listener.AddContext($context)
            $task.GetAwaiter()
            return $task
        })

        $rb = [RouteBuilder]::new($app, $r)
        [MapRouteRouteBuilderExtensions]::MapRoute($rb, "Pode Sub-Routes", "{*url}") | Out-Null

        $routes = $rb.Build()
        [RoutingBuilderExtensions]::UseRouter($app, $routes) | Out-Null
    }

    [void] ConfigureServices([IServiceCollection]$svc) {
        [RoutingServiceCollectionExtensions]::AddRouting($svc) | Out-Null
    }
}

function Start-PodeKestrelServer
{
    param (
        [switch]
        $Browse
    )

    # fail if not running on ps-core
    if (!(Test-IsPSCore)) {
        throw 'Hosting a Kestrel server only works with PowerShell Core 6.0+'
    }

    # fail if pslambda not present
    if ($null -eq (Get-Module -Name PSLambda)) {
        throw 'The PSLambda module is required for hosting a Kestrel server'
    }

    # work out which endpoints to listen on
    $endpoints = Get-PodeListenEndpoints

    # build kestrel, and listen
    $builder = [WebHostBuilder]::new()
    $builder = [WebHostBuilderExtensions]::UseStartup($builder, [PodeKestrelStartup])
    $builder = [WebHostBuilderKestrelExtensions]::UseKestrel($builder, [Action[KestrelServerOptions]] {
        param($options)

        foreach ($endpoint in $endpoints) {
            $options.Listen([IPAddress]$endpoint.IP, $endpoint.Port) | Out-Null
        }

        #TODO: Listen on the endpoints supplied - and get certs working
        # $options.Listen([IPAddress]::Any, 8081,
        # { param($listenOptions)
        #     $listenOptions.UseHttps("testCert.pfx", "testPassword");
        # });
    })

    $webhost = $builder.build()
    [WebHostExtensions]::RunAsync($webhost, $PodeContext.Tokens.Cancellation.Token) | Out-Null

    # setup any inbuilt middleware
    $inbuilt_middleware = @(
        (Get-PodeAccessMiddleware),
        (Get-PodeLimitMiddleware),
        (Get-PodePublicMiddleware),
        (Get-PodeRouteValidateMiddleware),
        (Get-PodeBodyMiddleware)
    )

    $PodeContext.Server.Middleware = ($inbuilt_middleware + $PodeContext.Server.Middleware)

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
            while (!$PodeContext.Tokens.Cancellation.IsCancellationRequested)
            {
                # get request and response
                $container = (Wait-PodeTask -Task $Listener.GetContextAsync())
                if ($container.Token.IsCancellationRequested) {
                    continue
                }

                try
                {
                    $context = $container.Context
                    $request = $context.Request
                    $response = $context.Response

                    # reset event data
                    $WebEvent = @{
                        OnEnd = @()
                        Auth = @{}
                        Response = $response
                        Request = $request
                        Lockable = $PodeContext.Lockable
                        Path = $request.Path.Value
                        Method = $request.Method.ToLowerInvariant()
                        Query = $request.Query
                        Protocol = @{
                            Scheme = $request.Scheme
                            Version = ($request.Protocol -split '/')[1]
                        }
                        Endpoint = $request.Host.Host
                        ContentType = $request.ContentType
                        RemoteIpAddress = $context.Connection.RemoteIpAddress
                        ErrorType = $null
                        Cookies = $request.Cookies
                        PendingCookies = @{}
                    }

                    # set pode in server response header
                    Set-PodeServerHeader -Type 'Kestrel'

                    # add logging endware for post-request
                    Add-PodeRequestLogEndware -WebEvent $WebEvent

                    # invoke middleware
                    if ((Invoke-PodeMiddleware -WebEvent $WebEvent -Middleware $PodeContext.Server.Middleware -Route $WebEvent.Path)) {
                        # get the route logic
                        $route = Get-PodeRoute -Method $WebEvent.Method -Route $WebEvent.Path -Protocol $WebEvent.Protocol.Scheme `
                            -Endpoint $WebEvent.Endpoint -CheckWildMethod

                        # invoke route and custom middleware
                        if ((Invoke-PodeMiddleware -WebEvent $WebEvent -Middleware $route.Middleware)) {
                            if ($null -ne $route.Logic) {
                                Invoke-PodeScriptBlock -ScriptBlock $route.Logic -Arguments (@($WebEvent) + @($route.Arguments)) -Scoped -Splat
                            }
                        }
                    }
                }
                catch {
                    Set-PodeResponseStatus -Code 500 -Exception $_
                    $_ | Write-PodeErrorLog
                }

                # invoke endware specifc to the current web event
                $_endware = ($WebEvent.OnEnd + @($PodeContext.Server.Endware))
                Invoke-PodeEndware -WebEvent $WebEvent -Endware $_endware

                # close response stream (check if exists, as closing the writer closes this stream on unix)
                if ($response.Body) {
                    Close-PodeDisposable -Disposable $response.Body -Close -CheckNetwork
                }

                $container.Token.Cancel()
            }
        }
        catch [System.OperationCanceledException] {}
        catch {
            $_ | Write-PodeErrorLog
            throw $_.Exception
        }
    }

    # start the runspace for listening on x-number of threads
    1..$PodeContext.Threads | ForEach-Object {
        Add-PodeRunspace -Type 'Main' -ScriptBlock $listenScript `
            -Parameters @{ 'Listener' = [PodeKestrelListener]::GetInstance(); 'ThreadId' = $_ }
    }

    # state where we're running
    Write-Host "Listening on the following $($endpoints.Length) endpoint(s) [$($PodeContext.Threads) thread(s)]:" -ForegroundColor Yellow

    $endpoints | ForEach-Object {
        Write-Host "`t- $($_.HostName)" -ForegroundColor Yellow
    }

    # browse to the first endpoint, if flagged
    if ($Browse) {
        Start-Process $endpoints[0].HostName
    }
}