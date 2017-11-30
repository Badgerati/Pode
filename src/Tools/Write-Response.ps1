
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


function Write-FromFile
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

function Write-HtmlFromFile
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