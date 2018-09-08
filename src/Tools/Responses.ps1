# write data to main http response
function Write-ToResponse
{
    param (
        [Parameter()]
        $Value,

        [Parameter()]
        [string]
        $ContentType = $null
    )

    if (Test-Empty $Value) {
        return
    }

    $res = $WebSession.Response
    if ($null -eq $res -or $null -eq $res.OutputStream -or !$res.OutputStream.CanWrite) {
        return
    }

    if (!(Test-Empty $ContentType)) {
        $res.ContentType = $ContentType
    }

    if ((Get-Type $Value).Name -ieq 'string') {
        $Value = [System.Text.Encoding]::UTF8.GetBytes($Value)
    }

    $res.ContentLength64 = $Value.Length

    try {
        $memory = New-Object -TypeName System.IO.MemoryStream
        $memory.Write($Value, 0, $Value.Length)
        $memory.WriteTo($res.OutputStream)
        $memory.Close()
    }
    catch {
        if (Test-ValidNetworkFailure $_.Exception) {
            return
        }

        $Error[0] | Out-Default
        throw $_.Exception
    }
}

function Write-ToResponseFromFile
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        $Path
    )

    # if the file doesnt exist then just fail on 404
    if (!(Test-Path $Path)) {
        status 404
        return
    }

    # are we dealing with a dynamic file for the view engine?
    $ext = Get-FileExtension -Path $Path -TrimPeriod

    if ((Test-Empty $ext) -or $ext -ine $PodeSession.Server.ViewEngine.Extension) {
        if (Test-IsPSCore) {
            $content = Get-Content -Path $Path -Raw -AsByteStream
        }
        else {
            $content = Get-Content -Path $Path -Raw -Encoding byte
        }

        Write-ToResponse -Value $content -ContentType (Get-PodeContentType -Extension $ext)
        return
    }

    # generate dynamic content
    $content = [string]::Empty

    switch ($ext.ToLowerInvariant())
    {
        'pode' {
            $content = Get-Content -Path $Path -Raw -Encoding utf8
            $content = ConvertFrom-PodeFile -Content $content
        }

        default {
            if ($null -ne $PodeSession.Server.ViewEngine.Script) {
                $content = (Invoke-ScriptBlock -ScriptBlock $PodeSession.Server.ViewEngine.Script -Arguments $Path -Return)
            }
        }
    }

    $ext = Get-FileExtension -Path (Get-FileName -Path $Path -WithoutExtension) -TrimPeriod
    Write-ToResponse -Value $content -ContentType (Get-PodeContentType -Extension $ext)
}

function Attach
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        $Path
    )

    # only download files from the public/ dir
    $Path = Join-ServerRoot 'public' $Path

    # if the file doesnt exist then just fail on 404
    if (!(Test-Path $Path)) {
        status 404
        return
    }

    $filename = Get-FileName -Path $Path
    $ext = Get-FileExtension -Path $Path -TrimPeriod

    # open up the file as a stream
    $fs = [System.IO.File]::OpenRead($Path)

    # setup the response details and headers
    $WebSession.Response.ContentLength64 = $fs.Length
    $WebSession.Response.SendChunked = $false
    $WebSession.Response.ContentType = (Get-PodeContentType -Extension $ext)
    $WebSession.Response.AddHeader('Content-Disposition', "attachment; filename=$($filename)")

    # set file as an attachment on the response
    $buffer = [byte[]]::new(64 * 1024)
    $read = 0

    while (($read = $fs.Read($buffer, 0, $buffer.Length)) -gt 0) {
        $WebSession.Response.OutputStream.Write($buffer, 0, $read)
    }

    dispose $fs
}

function Status
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [int]
        $Code,

        [Parameter()]
        [string]
        $Description
    )

    $WebSession.Response.StatusCode = $Code

    if (!(Test-Empty $Description)) {
        $WebSession.Response.StatusDescription = $Description
    }
}

function Redirect
{
    param (
        [Parameter()]
        [string]
        $Url,

        [Parameter()]
        [int]
        $Port = 0,

        [Parameter()]
        [ValidateSet('', 'HTTP', 'HTTPS')]
        [string]
        $Protocol,

        [switch]
        $Moved
    )

    if (Test-Empty $Url) {
        $uri = $WebSession.Request.Url

        $Protocol = $Protocol.ToLowerInvariant()
        if (Test-Empty $Protocol) {
            $Protocol = $uri.Scheme
        }

        if ($Port -le 0) {
            $Port = $uri.Port
        }

        $PortStr = [string]::Empty
        if ($Port -ne 80 -and $Port -ne 443) {
            $PortStr = ":$($Port)"
        }

        $Url = "$($Protocol)://$($uri.Host)$($PortStr)$($uri.PathAndQuery)"
    }

    $WebSession.Response.RedirectLocation = $Url

    if ($Moved) {
        status 301 'Moved'
    }
    else {
        status 302 'Redirect'
    }
}

function Json
{
    param (
        [Parameter()]
        $Value,

        [switch]
        $File
    )

    if ($File) {
        if ($null -eq $Value -or !(Test-Path $Value)) {
            status 404
            return
        }
        else {
            $Value = Get-Content -Path $Value -Encoding utf8
        }
    }
    elseif (Test-Empty $value) {
        $Value = '{}'
    }
    elseif ((Get-Type $Value).Name -ine 'string') {
        $Value = ($Value | ConvertTo-Json -Depth 10 -Compress)
    }

    Write-ToResponse -Value $Value -ContentType 'application/json; charset=utf-8'
}

function Csv
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        $Value,

        [switch]
        $File
    )

    if ($File) {
        if (!(Test-Path $Value)) {
            status 404
            return
        }
        else {
            $Value = Get-Content -Path $Value -Encoding utf8
        }
    }
    elseif ((Get-Type $Value).Name -ine 'string') {
        $Value = ($Value | ConvertTo-Csv -Delimiter ',')
    }

    Write-ToResponse -Value $Value -ContentType 'text/csv; charset=utf-8'
}

function Xml
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        $Value,

        [switch]
        $File
    )

    if ($File) {
        if (!(Test-Path $Value)) {
            status 404
            return
        }
        else {
            $Value = Get-Content -Path $Value -Encoding utf8
        }
    }
    elseif ((Get-Type $Value).Name -ine 'string') {
        $Value = ($Value | ConvertTo-Xml -Depth 10)
    }

    Write-ToResponse -Value $Value -ContentType 'application/xml; charset=utf-8'
}

function Html
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        $Value,

        [switch]
        $File
    )

    if ($File) {
        if (!(Test-Path $Value)) {
            status 404
            return
        }
        else {
            $Value = Get-Content -Path $Value -Encoding utf8
        }
    }
    elseif ((Get-Type $Value).Name -ine 'string') {
        $Value = ($Value | ConvertTo-Html)
    }

    Write-ToResponse -Value $Value -ContentType 'text/html; charset=utf-8'
}

# include helper to import the content of a view into another view
function Include
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Path,

        [Parameter()]
        $Data = @{}
    )

    # add view engine extension
    $ext = Get-FileExtension -Path $Path
    $hasExt = ![string]::IsNullOrWhiteSpace($ext)
    if (!$hasExt) {
        $Path += ".$($PodeSession.Server.ViewEngine.Extension)"
    }

    # only look in the view directory
    $Path = Join-ServerRoot 'views' $Path
    if (!(Test-Path $Path)) {
        throw "File not found at path: $($Path)"
    }

    # run any engine logic
    $engine = $PodeSession.Server.ViewEngine.Extension
    if ($hasExt) {
        $engine = $ext.Trim('.')
    }

    $content = [string]::Empty

    switch ($engine.ToLowerInvariant())
    {
        'html' {
            $content = Get-Content -Path $Path -Raw -Encoding utf8
        }

        'pode' {
            $content = Get-Content -Path $Path -Raw -Encoding utf8
            $content = ConvertFrom-PodeFile -Content $content -Data $Data
        }

        default {
            if ($null -ne $PodeSession.Server.ViewEngine.Script) {
                $content = (. $PodeSession.Server.ViewEngine.Script $Path, $Data)
            }
        }
    }

    return $content
}

function View
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        $Path,

        [Parameter()]
        $Data = @{}
    )

    # default data if null
    if ($null -eq $Data) {
        $Data = @{}
    }

    # add path to data as "pagename" - unless key already exists
    if (!$Data.ContainsKey('pagename')) {
        $Data['pagename'] = $Path
    }

    # add view engine extension
    $ext = Get-FileExtension -Path $Path
    $hasExt = ![string]::IsNullOrWhiteSpace($ext)
    if (!$hasExt) {
        $Path += ".$($PodeSession.Server.ViewEngine.Extension)"
    }

    # only look in the view directory
    $Path = Join-ServerRoot 'views' $Path
    if (!(Test-Path $Path)) {
        status 404
        return
    }

    # run any engine logic
    $engine = $PodeSession.Server.ViewEngine.Extension
    if ($hasExt) {
        $engine = $ext.Trim('.')
    }

    $content = [string]::Empty

    switch ($engine.ToLowerInvariant())
    {
        'html' {
            $content = Get-Content -Path $Path -Raw -Encoding utf8
        }

        'pode' {
            $content = Get-Content -Path $Path -Raw -Encoding utf8
            $content = ConvertFrom-PodeFile -Content $content -Data $Data
        }

        default {
            if ($null -ne $PodeSession.Server.ViewEngine.Script) {
                $content = (. $PodeSession.Server.ViewEngine.Script $Path, $Data)
            }
        }
    }

    html -Value $content
}

function Tcp
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet('write', 'read')]
        [string]
        $Action,

        [Parameter()]
        [string]
        $Message,

        [Parameter()]
        $Client
    )

    if ($null -eq $Client) {
        $Client = $TcpSession.Client
    }

    switch ($Action.ToLowerInvariant())
    {
        'write' {
            $stream = $Client.GetStream()
            $encoder = New-Object System.Text.ASCIIEncoding
            $buffer = $encoder.GetBytes("$($Message)`r`n")
            $stream.Write($buffer, 0, $buffer.Length)
            $stream.Flush()
        }

        'read' {
            $bytes = New-Object byte[] 8192
            $stream = $Client.GetStream()
            $encoder = New-Object System.Text.ASCIIEncoding
            $bytesRead = $stream.Read($bytes, 0, 8192)
            $message = $encoder.GetString($bytes, 0, $bytesRead)
            return $message
        }
    }
}