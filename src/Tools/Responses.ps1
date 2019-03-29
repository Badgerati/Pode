# write data to main http response
function Write-PodeValueToResponse
{
    param (
        [Parameter()]
        $Value,

        [Parameter()]
        [string]
        $ContentType = $null,

        [switch]
        $Cache
    )

    # if there's nothing to write, return
    if (Test-Empty $Value) {
        return
    }

    $res = $WebEvent.Response

    # if the response stream isn't writable, return
    if (($null -eq $res) -or ($null -eq $res.OutputStream) -or !$res.OutputStream.CanWrite) {
        return
    }

    # set a cache value
    if ($Cache) {
        $age = $PodeContext.Server.Web.Static.Cache.MaxAge
        $res.AddHeader('Cache-Control', "max-age=$($age), must-revalidate")
        $res.AddHeader('Expires', [datetime]::UtcNow.AddSeconds($age).ToString("ddd, dd MMM yyyy HH:mm:ss 'GMT'"))
    }

    # specify the content-type if supplied
    if (!(Test-Empty $ContentType)) {
        $res.ContentType = $ContentType
    }

    # write the content to the response
    if ($Value.GetType().Name -ieq 'string') {
        $Value = ConvertFrom-PodeValueToBytes -Value $Value
    }

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

function Write-PodeValueToResponseFromFile
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        $Path,

        [switch]
        $Cache
    )

    # test the file path, and set status accordingly
    if (!(Test-PodePath $Path -FailOnDirectory)) {
        return
    }

    # are we dealing with a dynamic file for the view engine? (ignore html)
    $mainExt = Get-PodeFileExtension -Path $Path -TrimPeriod

    # this is a static file
    if ((Test-Empty $mainExt) -or ($mainExt -ieq 'html') -or ($mainExt -ine $PodeContext.Server.ViewEngine.Extension)) {
        if (Test-IsPSCore) {
            $content = (Get-Content -Path $Path -Raw -AsByteStream)
        }
        else {
            $content = (Get-Content -Path $Path -Raw -Encoding byte)
        }

        Write-PodeValueToResponse -Value $content -ContentType (Get-PodeContentType -Extension $mainExt) -Cache:$Cache
        return
    }

    # generate dynamic content
    $content = Get-PodeFileContentUsingViewEngine -Path $Path

    # get the sub-file extension, if empty, use original
    $subExt = Get-PodeFileExtension -Path (Get-PodeFileName -Path $Path -WithoutExtension) -TrimPeriod
    $subExt = (coalesce $subExt $mainExt)

    Write-PodeValueToResponse -Value $content -ContentType (Get-PodeContentType -Extension $subExt)
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
        $Exception
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
    if ($Code -ge 400) {
        Show-PodeErrorPage -Code $Code -Description $Description -Exception $Exception
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

    Write-PodeValueToResponse -Value $Value -ContentType 'application/json; charset=utf-8'
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

    Write-PodeValueToResponse -Value $Value -ContentType 'text/csv; charset=utf-8'
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

    Write-PodeValueToResponse -Value $Value -ContentType 'application/xml; charset=utf-8'
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

    Write-PodeValueToResponse -Value $Value -ContentType 'text/html; charset=utf-8'
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
        $Exception
    )

    # get the custom errors path
    $customErrPath = $PodeContext.Server.InbuiltDrives['errors']

    # the actual error page path
    $errPagePath = [string]::Empty

    # if their is a custom error page, use it
    if (!(Test-Empty $customErrPath)) {
        $statusPage = (Join-Path $customErrPath "$($Code).*" -Resolve -ErrorAction Ignore)
        $defaultPage = (Join-Path $customErrPath "default.*" -Resolve -ErrorAction Ignore)

        # use the status page or the default page?
        if ((Test-PodePath -Path $statusPage -NoStatus)) {
            $errPagePath = $statusPage
        }
        elseif ((Test-PodePath -Path $defaultPage -NoStatus)) {
            $errPagePath = $defaultPage
        }
    }

    # if we haven't found a custom page, use the inbuilt pode one
    if (Test-Empty $errPagePath) {
        $errPagePath = Join-PodePaths @((Get-PodeModuleRootPath), 'Misc', 'default-error-page.pode')
    }

    # if there's still no error path, return
    if (!(Test-PodePath $errPagePath -NoStatus)) {
        return
    }

    # is exception trace showing enabled?
    $ex = $null
    if (($null -ne $Exception) -and ([bool](config).web.errorPages.showExceptions)) {
        $ex = @{
            'Message' = [System.Web.HttpUtility]::HtmlEncode($Exception.Exception.Message);
            'StackTrace' = [System.Web.HttpUtility]::HtmlEncode($Exception.ScriptStackTrace);
            'Line' = [System.Web.HttpUtility]::HtmlEncode($Exception.InvocationInfo.PositionMessage);
            'Category' = [System.Web.HttpUtility]::HtmlEncode($Exception.CategoryInfo.ToString());
        }
    }

    # run any engine logic and render it
    $content = Get-PodeFileContentUsingViewEngine -Path $errPagePath -Data @{
        'Url' = ($WebEvent.Protocol + '://' + $WebEvent.Endpoint + $WebEvent.Path);
        'Status' = @{
            'Code' = $Code;
            'Description' = $Description;
        };
        'Exception' = $ex;
    }

    html -Value $content
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

        (flash keys) | Foreach-Object {
            $Data.flash[$_] = (flash get $_)
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