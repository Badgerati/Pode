
function Write-ToResponse
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        $Content,

        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        $Response
    )

    $writer = New-Object -TypeName System.IO.StreamWriter -ArgumentList $Response.OutputStream
    $writer.WriteLine([string]$Content)
    $writer.Close()
}

function Write-JsonResponse
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        $Content,

        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        $Response
    )

    $Content = ($Content | ConvertTo-JSON)
    $Response.ContentType = 'application/json'
    Write-ToResponse -Content $Content -Response $Response
}

function Write-XmlResponse
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        $Content,

        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        $Response
    )

    $Content = ($Content | ConvertTo-Xml)
    $Response.ContentType = 'application/xml'
    Write-ToResponse -Content $Content -Response $Response
}