function Show-PodeErrorPage
{
    param (
        [Parameter()]
        [int]
        $Code,

        [Parameter()]
        [string]
        $Description,

        [Parameter()]
        $Exception,

        [Parameter()]
        [string]
        $ContentType
    )

    # error page info
    $errorPage = Find-PodeErrorPage -Code $Code -ContentType $ContentType

    # if no page found, return
    if (Test-PodeIsEmpty $errorPage) {
        return
    }

    # if exception trace showing enabled then build the exception details object
    $ex = $null
    if (!(Test-PodeIsEmpty $Exception) -and $PodeContext.Server.Web.ErrorPages.ShowExceptions) {
        $ex = @{
            'Message' = [System.Web.HttpUtility]::HtmlEncode($Exception.Exception.Message);
            'StackTrace' = [System.Web.HttpUtility]::HtmlEncode($Exception.ScriptStackTrace);
            'Line' = [System.Web.HttpUtility]::HtmlEncode($Exception.InvocationInfo.PositionMessage);
            'Category' = [System.Web.HttpUtility]::HtmlEncode($Exception.CategoryInfo.ToString());
        }
    }

    # setup the data object for dynamic pages
    $data = @{
        'Url' = (Get-PodeUrl);
        'Status' = @{
            'Code' = $Code;
            'Description' = $Description;
        };
        'Exception' = $ex;
        'ContentType' = $errorPage.ContentType;
    }

    # write the error page to the stream
    Write-PodeFileResponse -Path $errorPage.Path -Data $data -ContentType $errorPage.ContentType
}

function Close-PodeTcpConnection
{
    param (
        [Parameter()]
        $Client,

        [Parameter(ParameterSetName='Quit')]
        [string]
        $Message,

        [Parameter(ParameterSetName='Quit')]
        [switch]
        $Quit
    )

    if ($null -eq $Client) {
        $Client = $TcpEvent.Client
    }

    if ($null -ne $Client) {
        if ($Quit -and $Client.Connected) {
            if ([string]::IsNullOrWhiteSpace($Message)) {
                $Message = '221 Bye'
            }

            Write-PodeTcpClient -Message $Message
        }

        Close-PodeDisposable -Disposable $Client -Close
    }
}