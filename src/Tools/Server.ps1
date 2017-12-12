
function Server
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [scriptblock]
        $ScriptBlock,
        
        [Parameter()]
        [int]
        $Port = 0,

        [switch]
        $Mail
    )

    # create session object
    $PodeSession = New-Object -TypeName psobject |
        Add-Member -MemberType NoteProperty -Name Routes -Value $null -PassThru |
        Add-Member -MemberType NoteProperty -Name SmtpHandlers -Value $null -PassThru |
        Add-Member -MemberType NoteProperty -Name Port -Value $Port -PassThru

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

    # setup for initial smtp handlers
    $PodeSession.SmtpHandlers = @()

    # if mail is passed, and no port - force port to 25
    if ($Port -eq 0 -and $Mail)
    {
        $Port = 25
        $PodeSession.Port = $Port
    }
    
    # validate port passed
    if ($Port -le 0)
    {
        throw "Port cannot be negative: $($Port)"
    }

    # run logic for a mail server
    if ($Mail)
    {
        & $ScriptBlock
        Start-PodeMailServer
    }

    # if there's a port, run a web server
    elseif ($Port -ne $null)
    {
        & $ScriptBlock
        Start-PodeWebServer
    }

    # otherwise, run logic
    else
    {
        & $ScriptBlock
    }
}