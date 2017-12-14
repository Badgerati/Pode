
# write data to main http response
function Write-ToResponse
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        $Value,

        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        $Response
    )

    $writer = New-Object -TypeName System.IO.StreamWriter -ArgumentList $Response.OutputStream
    $writer.WriteLine([string]$Value)
    $writer.Close()
}


function Write-ToResponseFromFile
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        $Path,

        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        $Response
    )

    if (!(Test-Path $Path))
    {
        $Response.StatusCode = 404
    }
    else
    {
        $content = Get-Content -Path $Path
        Write-ToResponse -Value $content -Response $Response
    }
}

function Write-JsonResponse
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        $Value,

        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        $Response,

        [switch]
        $NoConvert
    )

    if (!$NoConvert)
    {
        $Value = ($Value | ConvertTo-Json)
    }

    $Response.ContentType = 'application/json; charset=utf-8'
    Write-ToResponse -Value $Value -Response $Response
}

function Write-XmlResponse
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        $Value,

        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        $Response,

        [switch]
        $NoConvert
    )

    if (!$NoConvert)
    {
        $Value = ($Value | ConvertTo-Xml)
    }

    $Response.ContentType = 'application/xml; charset=utf-8'
    Write-ToResponse -Value $Value -Response $Response
}

function Write-XmlResponseFromFile
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        $Path,

        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        $Response
    )

    $Path = (Join-Path 'views' $Path)

    if (!(Test-Path $Path))
    {
        $Response.StatusCode = 404
    }
    else
    {
        $content = Get-Content -Path $Path
        Write-XmlResponse -Value $content -Response $Response -NoConvert
    }
}

function Write-HtmlResponse
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        $Value,

        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        $Response,

        [switch]
        $NoConvert
    )

    if (!$NoConvert)
    {
        $Value = ($Value | ConvertTo-Html)
    }

    $Response.ContentType = 'text/html; charset=utf-8'
    Write-ToResponse -Value $Value -Response $Response
}

function Write-HtmlResponseFromFile
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        $Path,

        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        $Response
    )

    $Path = (Join-Path 'views' $Path)

    if (!(Test-Path $Path))
    {
        $Response.StatusCode = 404
    }
    else
    {
        $content = Get-Content -Path $Path
        Write-HtmlResponse -Value $content -Response $Response -NoConvert
    }
}


# write data to tcp stream
function Write-ToTcpStream
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        $Client,

        [Parameter()]
        [ValidateNotNull()]
        [string]
        $Message
    )

    $stream = $Client.GetStream()
    $encoder = New-Object System.Text.ASCIIEncoding
    $buffer = $encoder.GetBytes("$($Message)`r`n")
    $stream.Write($buffer, 0, $buffer.Length)
    $stream.Flush()
}

function Read-FromTcpStream
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        $Client
    )

    $bytes = New-Object byte[] 8192
    $stream = $client.GetStream()
    $encoder = New-Object System.Text.ASCIIEncoding
    $bytesRead = $stream.Read($bytes, 0, 8192)
    $message = $encoder.GetString($bytes, 0, $bytesRead)
    return $message
}