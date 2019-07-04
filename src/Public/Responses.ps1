function Attach
{
    param (
        [Parameter(Mandatory=$true)]
        [Alias('p')]
        [string]
        $Path
    )

    # only attach files from public/static-route directories when path is relative
    $Path = (Get-PodeStaticRoutePath -Route $Path).Path

    # test the file path, and set status accordingly
    if (!(Test-PodePath $Path)) {
        return
    }

    $filename = Get-PodeFileName -Path $Path
    $ext = Get-PodeFileExtension -Path $Path -TrimPeriod

    try {
        # setup the content type and disposition
        $WebEvent.Response.ContentType = (Get-PodeContentType -Extension $ext)
        Set-PodeHeader -Name 'Content-Disposition' -Value "attachment; filename=$($filename)"

        # if serverless, get the content raw and return
        if ($PodeContext.Server.IsServerless) {
            if (Test-IsPSCore) {
                $content = (Get-Content -Path $Path -Raw -AsByteStream)
            }
            else {
                $content = (Get-Content -Path $Path -Raw -Encoding byte)
            }

            $WebEvent.Response.Body = $content
        }

        # else if normal, stream the content back
        else {
            # setup the response details and headers
            $WebEvent.Response.ContentLength64 = $fs.Length
            $WebEvent.Response.SendChunked = $false

            # set file as an attachment on the response
            $buffer = [byte[]]::new(64 * 1024)
            $read = 0

            # open up the file as a stream
            $fs = (Get-Item $Path).OpenRead()

            while (($read = $fs.Read($buffer, 0, $buffer.Length)) -gt 0) {
                $WebEvent.Response.OutputStream.Write($buffer, 0, $read)
            }
        }
    }
    finally {
        dispose $fs
    }
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
    elseif ($Value -isnot 'string') {
        $Value = @(foreach ($v in $Value) {
            New-Object psobject -Property $v
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
        [Alias('a')]
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
    if (![string]::IsNullOrWhiteSpace($mainExt) -and (($mainExt -ieq 'pode') -or ($mainExt -ieq $PodeContext.Server.ViewEngine.Extension))) {
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

function Header
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet('Add', 'Exists', 'Get', 'Set')]
        [Alias('a')]
        [string]
        $Action,

        [Parameter(Mandatory=$true)]
        [Alias('n')]
        [string]
        $Name,

        [Parameter()]
        [Alias('v')]
        [string]
        $Value
    )

    # run logic for the action
    switch ($Action.ToLowerInvariant())
    {
        # set a headers against the response (overwriting all with same name)
        'set' {
            return (Set-PodeHeader -Name $Name -Value $Value)
        }

        # appends a header against the response
        'add' {
            return (Add-PodeHeader -Name $Name -Value $Value)
        }

        # get a header from the request
        'get' {
            return (Get-PodeHeader -Name $Name)
        }

        # checks whether a given header exists on the request
        'exists' {
            return (Test-PodeHeaderExists -Name $Name)
        }
    }
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
    elseif ($Value -isnot 'string') {
        $Value = ($Value | ConvertTo-Html)
    }

    Text -Value $Value -ContentType 'text/html'
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
    elseif ($Value -isnot 'string') {
        $Value = ($Value | ConvertTo-Json -Depth 10 -Compress)
    }

    Text -Value $Value -ContentType 'application/json'
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

    Set-PodeHeader -Name 'Location' -Value $Url

    if ($Moved) {
        status 301 'Moved'
    }
    else {
        status 302 'Redirect'
    }
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
    if ([string]::IsNullOrWhiteSpace($Description)) {
        $Description = (Get-PodeStatusDescription -StatusCode $Code)
    }

    if (!$PodeContext.Server.IsServerless -and ![string]::IsNullOrWhiteSpace($Description)) {
        $WebEvent.Response.StatusDescription = $Description
    }

    # if the status code is >=400 then attempt to load error page
    if (!$NoErrorPage -and ($Code -ge 400)) {
        Show-PodeErrorPage -Code $Code -Description $Description -Exception $Exception -ContentType $ContentType
    }
}

function Text
{
    param (
        [Parameter()]
        [Alias('v')]
        $Value,

        [Parameter()]
        [Alias('ctype', 'ct')]
        [string]
        $ContentType = 'text/plain',

        [Parameter()]
        [Alias('a')]
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
    if (($null -eq $res) -or (!$PodeContext.Server.IsServerless -and (($null -eq $res.OutputStream) -or !$res.OutputStream.CanWrite))) {
        return
    }

    # set a cache value
    if ($Cache) {
        Set-PodeHeader -Name 'Cache-Control' -Value "max-age=$($MaxAge), must-revalidate"
        Set-PodeHeader -Name 'Expires' -Value ([datetime]::UtcNow.AddSeconds($MaxAge).ToString("ddd, dd MMM yyyy HH:mm:ss 'GMT'"))
    }

    # specify the content-type if supplied (adding utf-8 if missing)
    if (![string]::IsNullOrWhiteSpace($ContentType)) {
        $charset = 'charset=utf-8'
        if ($ContentType -inotcontains $charset) {
            $ContentType = "$($ContentType); $($charset)"
        }

        $res.ContentType = $ContentType
    }

    # if we're serverless, set the string as the body
    if ($PodeContext.Server.IsServerless) {
        $res.Body = $Value
    }

    else {
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

        foreach ($name in (Get-PodeFlashMessageNames)) {
            $Data.flash[$name] = (Get-PodeFlashMessage -Name $name)
        }
    }
    elseif (Test-Empty $Data['flash']) {
        $Data['flash'] = @{}
    }

    # add view engine extension
    $ext = Get-PodeFileExtension -Path $Path
    if ([string]::IsNullOrWhiteSpace($ext)) {
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
    elseif ($Value -isnot 'string') {
        $Value = @(foreach ($v in $Value) {
            New-Object psobject -Property $v
        })

        $Value = ($Value | ConvertTo-Xml -Depth 10 -As String -NoTypeInformation)
    }

    Text -Value $Value -ContentType 'text/xml'
}