# write data to http response stream, using a specific content-type
function Text
{
    param (
        [Parameter()]
        [Alias('v')]
        $Value,

        [Parameter()]
        [Alias('ctype', 'ct')]
        [string]
        $ContentType = $null,

        [Parameter()]
        [int]
        $MaxAge = 3600,

        [switch]
        [Alias('c')]
        $Cache
    )

    # if there's nothing to write, return
    if (Test-Empty $Value) {
        return
    }

    # if the value isn't a string/byte[] then error
    $valueType = $Value.GetType().Name
    if (@('string', 'byte[]') -inotcontains $valueType) {
        throw "Value to write to stream must be a String or Byte[], but got: $($valueType)"
    }

    # if the response stream isn't writable, return
    $res = $WebEvent.Response
    if (($null -eq $res) -or ($null -eq $res.OutputStream) -or !$res.OutputStream.CanWrite) {
        return
    }

    # set a cache value
    if ($Cache) {
        $res.AddHeader('Cache-Control', "max-age=$($MaxAge), must-revalidate")
        $res.AddHeader('Expires', [datetime]::UtcNow.AddSeconds($MaxAge).ToString("ddd, dd MMM yyyy HH:mm:ss 'GMT'"))
    }

    # specify the content-type if supplied (adding utf-8 if missing)
    if (!(Test-Empty $ContentType)) {
        $charset = 'charset=utf-8'
        if ($ContentType -inotcontains $charset) {
            $ContentType = "$($ContentType); $($charset)"
        }

        $res.ContentType = $ContentType
    }

    # convert string to bytes
    if ($valueType -ieq 'string') {
        $Value = ConvertFrom-PodeValueToBytes -Value $Value
    }

    # write the content to the response stream
    $res.ContentLength64 = $Value.Length

    try {
        $ms = New-Object -TypeName System.IO.MemoryStream
        $ms.Write($Value, 0, $Value.Length)
        $ms.WriteTo($res.OutputStream)
        $ms.Close()
    }
    catch {
        if ((Test-PodeValidNetworkFailure $_.Exception)) {
            return
        }

        $_.Exception | Out-Default
        throw
    }
}

function File
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [Alias('p')]
        [string]
        $Path,

        [Parameter()]
        [Alias('d')]
        $Data = @{},

        [Parameter()]
        [Alias('ctype', 'ct')]
        [string]
        $ContentType = $null,

        [Parameter()]
        [int]
        $MaxAge = 3600,

        [switch]
        [Alias('c')]
        $Cache
    )

    # test the file path, and set status accordingly
    if (!(Test-PodePath $Path -FailOnDirectory)) {
        return
    }

    # are we dealing with a dynamic file for the view engine? (ignore html)
    $mainExt = Get-PodeFileExtension -Path $Path -TrimPeriod

    # generate dynamic content
    if (!(Test-Empty $mainExt) -and (($mainExt -ieq 'pode') -or ($mainExt -ieq $PodeContext.Server.ViewEngine.Extension))) {
        $content = Get-PodeFileContentUsingViewEngine -Path $Path -Data $Data

        # get the sub-file extension, if empty, use original
        $subExt = Get-PodeFileExtension -Path (Get-PodeFileName -Path $Path -WithoutExtension) -TrimPeriod
        $subExt = (coalesce $subExt $mainExt)

        $ContentType = (coalesce $ContentType (Get-PodeContentType -Extension $subExt))
        Text -Value $content -ContentType $ContentType
    }

    # this is a static file
    else {
        if (Test-IsPSCore) {
            $content = (Get-Content -Path $Path -Raw -AsByteStream)
        }
        else {
            $content = (Get-Content -Path $Path -Raw -Encoding byte)
        }

        $ContentType = (coalesce $ContentType (Get-PodeContentType -Extension $mainExt))
        Text -Value $content -ContentType $ContentType -MaxAge $MaxAge -Cache:$Cache
    }
}

function Attach
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [Alias('p')]
        [string]
        $Path
    )

    # only attach files from public/static-route directories
    $Path = Get-PodeStaticRoutePath -Route $Path

    # test the file path, and set status accordingly
    if (!(Test-PodePath $Path)) {
        return
    }

    $filename = Get-PodeFileName -Path $Path
    $ext = Get-PodeFileExtension -Path $Path -TrimPeriod

    # open up the file as a stream
    $fs = (Get-Item $Path).OpenRead()

    # setup the response details and headers
    $WebEvent.Response.ContentLength64 = $fs.Length
    $WebEvent.Response.SendChunked = $false
    $WebEvent.Response.ContentType = (Get-PodeContentType -Extension $ext)
    $WebEvent.Response.AddHeader('Content-Disposition', "attachment; filename=$($filename)")

    # set file as an attachment on the response
    $buffer = [byte[]]::new(64 * 1024)
    $read = 0

    while (($read = $fs.Read($buffer, 0, $buffer.Length)) -gt 0) {
        $WebEvent.Response.OutputStream.Write($buffer, 0, $read)
    }

    dispose $fs
}

function Save
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [Alias('n')]
        [string]
        $Name,

        [Parameter()]
        [Alias('p')]
        [string]
        $Path = '.'
    )

    # if path is '.', replace with server root
    if ($Path -match '^\.[\\/]{0,1}') {
        $Path = $Path -replace '^\.[\\/]{0,1}', ''
        $Path = Join-Path $PodeContext.Server.Root $Path
    }

    # ensure the parameter name exists in data
    $fileName = $WebEvent.Data[$Name]
    if (Test-Empty $fileName) {
        throw "A parameter called '$($Name)' was not supplied in the request"
    }

    # ensure the file data exists
    if (!$WebEvent.Files.ContainsKey($fileName)) {
        throw "No data for file '$($fileName)' was uploaded in the request"
    }

    # if the path is a directory, add the filename
    if (Test-PodePathIsDirectory -Path $Path) {
        $Path = Join-Path $Path $fileName
    }

    # save the file
    [System.IO.File]::WriteAllBytes($Path, $WebEvent.Files[$fileName].Bytes)
}

function Status
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [Alias('c')]
        [int]
        $Code,

        [Parameter()]
        [Alias('d')]
        [string]
        $Description,

        [Parameter()]
        [Alias('e')]
        $Exception,

        [Parameter()]
        [Alias('ctype', 'ct')]
        [string]
        $ContentType = $null,

        [switch]
        [Alias('nopage')]
        $NoErrorPage
    )

    # set the code
    $WebEvent.Response.StatusCode = $Code

    # set an appropriate description (mapping if supplied is blank)
    if (Test-Empty $Description) {
        $Description = (Get-PodeStatusDescription -StatusCode $Code)
    }

    if (!(Test-Empty $Description)) {
        $WebEvent.Response.StatusDescription = $Description
    }

    # if the status code is >=400 then attempt to load error page
    if (!$NoErrorPage -and ($Code -ge 400)) {
        Show-PodeErrorPage -Code $Code -Description $Description -Exception $Exception -ContentType $ContentType
    }
}

function Redirect
{
    param (
        [Parameter()]
        [Alias('u')]
        [string]
        $Url,

        [Parameter()]
        [Alias('p')]
        [int]
        $Port = 0,

        [Parameter()]
        [ValidateSet('', 'HTTP', 'HTTPS')]
        [Alias('pr')]
        [string]
        $Protocol,

        [Parameter()]
        [Alias('e')]
        [string]
        $Endpoint,

        [switch]
        [Alias('m')]
        $Moved
    )

    if (Test-Empty $Url) {
        $uri = $WebEvent.Request.Url

        # set the protocol
        $Protocol = $Protocol.ToLowerInvariant()
        if (Test-Empty $Protocol) {
            $Protocol = $uri.Scheme
        }

        # set the endpoint
        if (Test-Empty $Endpoint) {
            $Endpoint = $uri.Host
        }

        # set the port
        if ($Port -le 0) {
            $Port = $uri.Port
        }

        $PortStr = [string]::Empty
        if ($Port -ne 80 -and $Port -ne 443) {
            $PortStr = ":$($Port)"
        }

        # combine to form the url
        $Url = "$($Protocol)://$($Endpoint)$($PortStr)$($uri.PathAndQuery)"
    }

    $WebEvent.Response.RedirectLocation = $Url

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
        [Alias('v')]
        $Value,

        [switch]
        $File
    )

    if ($File) {
        # test the file path, and set status accordingly
        if (!(Test-PodePath $Value)) {
            return
        }
        else {
            $Value = Get-PodeFileContent -Path $Value
        }
    }
    elseif (Test-Empty $Value) {
        $Value = '{}'
    }
    elseif ((Get-PodeType $Value).Name -ine 'string') {
        $Value = ($Value | ConvertTo-Json -Depth 10 -Compress)
    }

    Text -Value $Value -ContentType 'application/json'
}

function Csv
{
    param (
        [Parameter(Mandatory=$true)]
        [Alias('v')]
        $Value,

        [switch]
        $File
    )

    if ($File) {
        # test the file path, and set status accordingly
        if (!(Test-PodePath $Value)) {
            return
        }
        else {
            $Value = Get-PodeFileContent -Path $Value
        }
    }
    elseif (Test-Empty $Value) {
        $Value = [string]::Empty
    }
    elseif ((Get-PodeType $Value).Name -ine 'string') {
        $Value = ($Value | ForEach-Object {
            New-Object psobject -Property $_
        })

        if (Test-IsPSCore) {
            $Value = ($Value | ConvertTo-Csv -Delimiter ',' -IncludeTypeInformation:$false)
        }
        else {
            $Value = ($Value | ConvertTo-Csv -Delimiter ',' -NoTypeInformation)
        }
    }

    Text -Value $Value -ContentType 'text/csv'
}

function Xml
{
    param (
        [Parameter(Mandatory=$true)]
        [Alias('v')]
        $Value,

        [switch]
        $File
    )

    if ($File) {
        # test the file path, and set status accordingly
        if (!(Test-PodePath $Value)) {
            return
        }
        else {
            $Value = Get-PodeFileContent -Path $Value
        }
    }
    elseif (Test-Empty $value) {
        $Value = [string]::Empty
    }
    elseif ((Get-PodeType $Value).Name -ine 'string') {
        $Value = ($value | ForEach-Object {
            New-Object psobject -Property $_
        })

        $Value = ($Value | ConvertTo-Xml -Depth 10 -As String -NoTypeInformation)
    }

    Text -Value $Value -ContentType 'text/xml'
}

function Html
{
    param (
        [Parameter(Mandatory=$true)]
        [Alias('v')]
        $Value,

        [switch]
        $File
    )

    if ($File) {
        # test the file path, and set status accordingly
        if (!(Test-PodePath $Value)) {
            return
        }
        else {
            $Value = Get-PodeFileContent -Path $Value
        }
    }
    elseif (Test-Empty $value) {
        $Value = [string]::Empty
    }
    elseif ((Get-PodeType $Value).Name -ine 'string') {
        $Value = ($Value | ConvertTo-Html)
    }

    Text -Value $Value -ContentType 'text/html'
}

# include helper to import the content of a view into another view
function Include
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [Alias('p')]
        [string]
        $Path,

        [Parameter()]
        [Alias('d')]
        $Data = @{}
    )

    # default data if null
    if ($null -eq $Data) {
        $Data = @{}
    }

    # add view engine extension
    $ext = Get-PodeFileExtension -Path $Path
    if (Test-Empty $ext) {
        $Path += ".$($PodeContext.Server.ViewEngine.Extension)"
    }

    # only look in the view directory
    $Path = (Join-Path $PodeContext.Server.InbuiltDrives['views'] $Path)

    # test the file path, and set status accordingly
    if (!(Test-PodePath $Path -NoStatus)) {
        throw "File not found at path: $($Path)"
    }

    # run any engine logic
    return (Get-PodeFileContentUsingViewEngine -Path $Path -Data $Data)
}

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
    if (Test-Empty $errorPage) {
        return
    }

    # if exception trace showing enabled then build the exception details object
    $ex = $null
    if (!(Test-Empty $Exception) -and $PodeContext.Server.Web.ErrorPages.ShowExceptions) {
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
    File -Path $errorPage.Path -Data $data -ContentType $errorPage.ContentType
}

function View
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [Alias('p')]
        $Path,

        [Parameter()]
        [Alias('d')]
        $Data = @{},

        [switch]
        [Alias('fm')]
        $FlashMessages
    )

    # default data if null
    if ($null -eq $Data) {
        $Data = @{}
    }

    # add path to data as "pagename" - unless key already exists
    if (!$Data.ContainsKey('pagename')) {
        $Data['pagename'] = $Path
    }

    # load all flash messages if needed
    if ($FlashMessages -and !(Test-Empty $WebEvent.Session.Data.Flash)) {
        $Data['flash'] = @{}

        foreach ($key in (flash keys)) {
            $Data.flash[$key] = (flash get $key)
        }
    }
    elseif (Test-Empty $Data['flash']) {
        $Data['flash'] = @{}
    }

    # add view engine extension
    $ext = Get-PodeFileExtension -Path $Path
    if (Test-Empty $ext) {
        $Path += ".$($PodeContext.Server.ViewEngine.Extension)"
    }

    # only look in the view directory
    $Path = (Join-Path $PodeContext.Server.InbuiltDrives['views'] $Path)

    # test the file path, and set status accordingly
    if (!(Test-PodePath $Path)) {
        return
    }

    # run any engine logic and render it
    html -Value (Get-PodeFileContentUsingViewEngine -Path $Path -Data $Data)
}

function Close-PodeTcpConnection
{
    param (
        [Parameter()]
        $Client,

        [switch]
        $Quit
    )

    if ($null -eq $Client) {
        $Client = $TcpEvent.Client
    }

    if ($null -ne $Client) {
        if ($Quit -and $Client.Connected) {
            tcp write '221 Bye'
        }

        dispose $Client -Close
    }
}

function Tcp
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet('write', 'read')]
        [Alias('a')]
        [string]
        $Action,

        [Parameter()]
        [Alias('m')]
        [string]
        $Message,

        [Parameter()]
        [Alias('c')]
        $Client
    )

    if ($null -eq $Client) {
        $Client = $TcpEvent.Client
    }

    switch ($Action.ToLowerInvariant())
    {
        'write' {
            $encoder = New-Object System.Text.ASCIIEncoding
            $buffer = $encoder.GetBytes("$($Message)`r`n")
            $stream = $Client.GetStream()
            await $stream.WriteAsync($buffer, 0, $buffer.Length)
            $stream.Flush()
        }

        'read' {
            $bytes = New-Object byte[] 8192
            $encoder = New-Object System.Text.ASCIIEncoding
            $stream = $Client.GetStream()
            $bytesRead = (await $stream.ReadAsync($bytes, 0, 8192))
            return $encoder.GetString($bytes, 0, $bytesRead)
        }
    }
}