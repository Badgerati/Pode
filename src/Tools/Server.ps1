function Server
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [scriptblock]
        $ScriptBlock,
        
        [Parameter()]
        [ValidateNotNull()]
        [int]
        $Port = 0,

        [Parameter()]
        [ValidateNotNull()]
        [int]
        $Interval = 0,

        [switch]
        $Smtp,

        [switch]
        $Tcp,

        [switch]
        $Https
    )

    # create session object
    $PodeSession = New-Object -TypeName psobject |
        Add-Member -MemberType NoteProperty -Name Routes -Value $null -PassThru |
        Add-Member -MemberType NoteProperty -Name TcpHandlers -Value $null -PassThru |
        Add-Member -MemberType NoteProperty -Name Port -Value $Port -PassThru | 
        Add-Member -MemberType NoteProperty -Name ViewEngine -Value $null -PassThru | 
        Add-Member -MemberType NoteProperty -Name Web -Value @{} -PassThru | 
        Add-Member -MemberType NoteProperty -Name Smtp -Value @{} -PassThru | 
        Add-Member -MemberType NoteProperty -Name Tcp -Value @{} -PassThru

    # setup initial view engine
    $PodeSession.ViewEngine = @{
        'Extension' = 'html';
        'Script' = $null;
    }

    # setup for initial routing
    $PodeSession.Routes = @{
        'delete' = @{};
        'get' = @{};
        'head' = @{};
        'merge' = @{};
        'options' = @{};
        'patch' = @{};
        'post' = @{};
        'put' = @{};
        'trace' = @{};
    }

    # setup for initial smtp/tcp handlers
    $PodeSession.TcpHandlers = @{
        'tcp' = $null;
        'smtp' = $null;
    }

    # if smtp is passed, and no port - force port to 25
    if ($Port -eq 0 -and $Smtp)
    {
        $Port = 25
        $PodeSession.Port = $Port
    }
    
    # validate port passed
    if ($Port -le 0)
    {
        throw "Port cannot be negative: $($Port)"
    }

    # run logic for a smtp server
    if ($Smtp)
    {
        & $ScriptBlock
        Start-SmtpServer
    }

    # run logic for a tcp server
    elseif ($Tcp)
    {
        & $ScriptBlock
        Start-TcpServer
    }

    # if there's a port, run a web server
    elseif ($Port -gt 0)
    {
        & $ScriptBlock
        Start-WebServer -Https:$Https
    }

    # otherwise, run logic
    else
    {
        # are we running this logic in an interval loop?
        if ($Interval -le 0)
        {
            & $ScriptBlock
        }
        else
        {
            Write-Host "Looping logic every $($Interval)secs" -ForegroundColor Yellow
            [Console]::TreatControlCAsInput = $true

            while ($true)
            {
                if (![Console]::IsInputRedirected -and [Console]::KeyAvailable)
                {
                    $key = [Console]::ReadKey($true)
                    if ($key.Key -ieq 'c' -and $key.Modifiers -band [ConsoleModifiers]::Control)
                    {
                        Write-Host 'Terminating...'
                        return
                    }
                }

                & $ScriptBlock
                Start-Sleep -Seconds $Interval
            }
        }
    }

    # clean up the session
    $PodeSession = $null
}