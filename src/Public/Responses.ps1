<#
.SYNOPSIS
Attaches a file onto the Response for downloading.

.DESCRIPTION
Attaches a file from the "/public", and static Routes, onto the Response for downloading.
If the supplied path is not in the Static Routes but is a literal/relative path, then this file is used instead.

.PARAMETER Path
The Path to a static file relative to the "/public" directory, or a static Route.
If the supplied Path doesn't match any custom static Route, then Pode will look in the "/public" directory.
Failing this, if the file path exists as a literal/relative file, then this file is used as a fall back.

.PARAMETER ContentType
Manually specify the content type of the response rather than infering it from the attachment's file extension.
The supplied value must match the valid ContentType format, e.g. application/json

.PARAMETER EndpointName
Optional EndpointName that the static route was creating under.

.PARAMETER FileBrowser
If the path is a folder, instead of returning 404, will return A browsable content of the directory.

.EXAMPLE
Set-PodeResponseAttachment -Path 'downloads/installer.exe'

.EXAMPLE
Set-PodeResponseAttachment -Path './image.png'

.EXAMPLE
Set-PodeResponseAttachment -Path 'c:/content/accounts.xlsx'

.EXAMPLE
Set-PodeResponseAttachment -Path './data.txt' -ContentType 'application/json'

.EXAMPLE
Set-PodeResponseAttachment -Path '/assets/data.txt' -EndpointName 'Example'
#>

function Set-PodeResponseAttachment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]
        $Path,

        [ValidatePattern('^\w+\/[\w\.\+-]+$')]
        [string]
        $ContentType,

        [Parameter()]
        [string]
        $EndpointName,

        [switch]
        $FileBrowser

    )

    # already sent? skip
    if ($WebEvent.Response.Sent) {
        return
    }

    # only attach files from public/static-route directories when path is relative
    $route = (Find-PodeStaticRoute -Path $Path -CheckPublic -EndpointName $EndpointName)
    if ($route) {
        $_path = $route.Content.Source

    }
    else {
        $_path = Get-PodeRelativePath -Path $Path -JoinRoot
    }
    #call internal Attachment function
    Write-PodeAttachmentResponseInternal -Path $_path -ContentType $ContentType -FileBrowser:$fileBrowser
}


<#
.SYNOPSIS
Writes a String or a Byte[] to the Response.

.DESCRIPTION
Writes a String or a Byte[] to the Response, as some specified content type. This value can also be cached.

.PARAMETER Value
A String value to write.

.PARAMETER Bytes
An array of Bytes to write.

.PARAMETER ContentType
The content type of the data being written.

.PARAMETER MaxAge
The maximum age to cache the value on the browser, in seconds.

.PARAMETER StatusCode
The status code to set against the response.

.PARAMETER Cache
Should the value be cached by browsers, or not?

.EXAMPLE
Write-PodeTextResponse -Value 'Leeeeeerrrooooy Jeeeenkiiins!'

.EXAMPLE
Write-PodeTextResponse -Value '{"name": "Rick"}' -ContentType 'application/json'

.EXAMPLE
Write-PodeTextResponse -Bytes (Get-Content -Path ./some/image.png -Raw -AsByteStream) -Cache -MaxAge 1800

.EXAMPLE
Write-PodeTextResponse -Value 'Untitled Text Response' -StatusCode 418
#>
function Write-PodeTextResponse {
    [CmdletBinding(DefaultParameterSetName = 'String')]
    param (
        [Parameter(ParameterSetName = 'String', ValueFromPipeline = $true, Position = 0)]
        [string]
        $Value,

        [Parameter(ParameterSetName = 'Bytes')]
        [byte[]]
        $Bytes,

        [Parameter()]
        [string]
        $ContentType = 'text/plain',

        [Parameter()]
        [int]
        $MaxAge = 3600,

        [Parameter()]
        [int]
        $StatusCode = 200,

        [switch]
        $Cache
    )

    $isStringValue = ($PSCmdlet.ParameterSetName -ieq 'string')
    $isByteValue = ($PSCmdlet.ParameterSetName -ieq 'bytes')

    # set the status code of the response, but only if it's not 200 (to prevent overriding)
    if ($StatusCode -ne 200) {
        Set-PodeResponseStatus -Code $StatusCode -NoErrorPage
    }

    # if there's nothing to write, return
    if ($isStringValue -and [string]::IsNullOrWhiteSpace($Value)) {
        return
    }

    if ($isByteValue -and (($null -eq $Bytes) -or ($Bytes.Length -eq 0))) {
        return
    }

    # if the response stream isn't writable or already sent, return
    $res = $WebEvent.Response
    if (($null -eq $res) -or ($WebEvent.Streamed -and (($null -eq $res.OutputStream) -or !$res.OutputStream.CanWrite -or $res.Sent))) {
        return
    }

    # set a cache value
    if ($Cache) {
        Set-PodeHeader -Name 'Cache-Control' -Value "max-age=$($MaxAge), must-revalidate"
        Set-PodeHeader -Name 'Expires' -Value ([datetime]::UtcNow.AddSeconds($MaxAge).ToString('r', [CultureInfo]::InvariantCulture))
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
    if (!$WebEvent.Streamed) {
        if ($isStringValue) {
            $res.Body = $Value
        }
        else {
            $res.Body = $Bytes
        }
    }

    else {
        # convert string to bytes
        if ($isStringValue) {
            $Bytes = ConvertFrom-PodeValueToBytes -Value $Value
        }

        # check if we only need a range of the bytes
        if (($null -ne $WebEvent.Ranges) -and ($WebEvent.Response.StatusCode -eq 200) -and ($StatusCode -eq 200)) {
            $lengths = @()
            $size = $Bytes.Length

            $Bytes = @(foreach ($range in $WebEvent.Ranges) {
                    # ensure range not invalid
                    if (([int]$range.Start -lt 0) -or ([int]$range.Start -ge $size) -or ([int]$range.End -lt 0)) {
                        Set-PodeResponseStatus -Code 416 -NoErrorPage
                        return
                    }

                    # skip start bytes only
                    if ([string]::IsNullOrWhiteSpace($range.End)) {
                        $Bytes[$range.Start..($size - 1)]
                        $lengths += "$($range.Start)-$($size - 1)/$($size)"
                    }

                    # end bytes only
                    elseif ([string]::IsNullOrWhiteSpace($range.Start)) {
                        if ([int]$range.End -gt $size) {
                            $range.End = $size
                        }

                        if ([int]$range.End -gt 0) {
                            $Bytes[$($size - $range.End)..($size - 1)]
                            $lengths += "$($size - $range.End)-$($size - 1)/$($size)"
                        }
                        else {
                            $lengths += "0-0/$($size)"
                        }
                    }

                    # normal range
                    else {
                        if ([int]$range.End -ge $size) {
                            Set-PodeResponseStatus -Code 416 -NoErrorPage
                            return
                        }

                        $Bytes[$range.Start..$range.End]
                        $lengths += "$($range.Start)-$($range.End)/$($size)"
                    }
                })

            Set-PodeHeader -Name 'Content-Range' -Value "bytes $($lengths -join ', ')"
            if ($StatusCode -eq 200) {
                Set-PodeResponseStatus -Code 206 -NoErrorPage
            }
        }

        # check if we need to compress the response
        if ($PodeContext.Server.Web.Compression.Enabled -and ![string]::IsNullOrWhiteSpace($WebEvent.AcceptEncoding)) {
            try {
                $ms = New-Object -TypeName System.IO.MemoryStream
                $stream = New-Object "System.IO.Compression.$($WebEvent.AcceptEncoding)Stream"($ms, [System.IO.Compression.CompressionMode]::Compress, $true)
                $stream.Write($Bytes, 0, $Bytes.Length)
                $stream.Close()
                $ms.Position = 0
                $Bytes = $ms.ToArray()
            }
            finally {
                if ($null -ne $stream) {
                    $stream.Close()
                }

                if ($null -ne $ms) {
                    $ms.Close()
                }
            }

            # set content encoding header
            Set-PodeHeader -Name 'Content-Encoding' -Value $WebEvent.AcceptEncoding
        }

        # write the content to the response stream
        $res.ContentLength64 = $Bytes.Length

        try {
            $ms = New-Object -TypeName System.IO.MemoryStream
            $ms.Write($Bytes, 0, $Bytes.Length)
            $ms.WriteTo($res.OutputStream)
        }
        catch {
            if ((Test-PodeValidNetworkFailure $_.Exception)) {
                return
            }

            $_ | Write-PodeErrorLog
            throw
        }
        finally {
            if ($null -ne $ms) {
                $ms.Close()
            }
        }
    }
}

<#
.SYNOPSIS
Renders the content of a static, or dynamic, file on the Response.

.DESCRIPTION
Renders the content of a static, or dynamic, file on the Response.
You can set browser's to cache the content, and also override the file's content type.

.PARAMETER Path
The path to a file.

.PARAMETER Data
A HashTable of dynamic data to supply to a dynamic file.

.PARAMETER ContentType
The content type of the file's contents - this overrides the file's extension.

.PARAMETER MaxAge
The maximum age to cache the file's content on the browser, in seconds.

.PARAMETER StatusCode
The status code to set against the response.

.PARAMETER Cache
Should the file's content be cached by browsers, or not?

.PARAMETER FileBrowser
If the path is a folder, instead of returning 404, will return A browsable content of the directory.

.EXAMPLE
Write-PodeFileResponse -Path 'C:/Files/Stuff.txt'

.EXAMPLE
Write-PodeFileResponse -Path 'C:/Files/Stuff.txt' -Cache -MaxAge 1800

.EXAMPLE
Write-PodeFileResponse -Path 'C:/Files/Stuff.txt' -ContentType 'application/json'

.EXAMPLE
Write-PodeFileResponse -Path 'C:/Views/Index.pode' -Data @{ Counter = 2 }

.EXAMPLE
Write-PodeFileResponse -Path 'C:/Files/Stuff.txt' -StatusCode 201

.EXAMPLE
Write-PodeFileResponse -Path 'C:/Files/' -FileBrowser
#>
function Write-PodeFileResponse {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNull()]
        [string]
        $Path,

        [Parameter()]
        $Data = @{},

        [Parameter()]
        [string]
        $ContentType = $null,

        [Parameter()]
        [int]
        $MaxAge = 3600,

        [Parameter()]
        [int]
        $StatusCode = 200,

        [switch]
        $Cache,

        [switch]
        $FileBrowser
    )

    # resolve for relative path
    $RelativePath = Get-PodeRelativePath -Path $Path -JoinRoot

    Write-PodeFileResponseInternal -Path $RelativePath -Data $Data -ContentType $ContentType -MaxAge $MaxAge `
        -StatusCode $StatusCode -Cache:$Cache -FileBrowser:$FileBrowser
}

<#
.SYNOPSIS
Serves a directory listing as a web page.

.DESCRIPTION
The Write-PodeDirectoryResponse function generates an HTML response that lists the contents of a specified directory,
allowing for browsing of files and directories. It supports both Windows and Unix-like environments by adjusting the
display of file attributes accordingly. If the path is a directory, it generates a browsable HTML view; otherwise, it
serves the file directly.

.PARAMETER Path
The path to the directory that should be displayed. This path is resolved and used to generate a list of contents.

.EXAMPLE
Write-PodeDirectoryResponse -Path './static'

Generates and serves an HTML page that lists the contents of the './static' directory, allowing users to click through files and directories.
#>
function Write-PodeDirectoryResponse {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNull()]
        [string]
        $Path
    )

    # resolve for relative path
    $RelativePath = Get-PodeRelativePath -Path $Path -JoinRoot

    if (Test-Path -Path $RelativePath -PathType Container) {
        Write-PodeDirectoryResponseInternal -Path $RelativePath
    }
    else {
        Set-PodeResponseStatus -Code 404
    }
}
<#
.SYNOPSIS
Writes CSV data to the Response.

.DESCRIPTION
Writes CSV data to the Response, setting the content type accordingly.

.PARAMETER Value
A String, PSObject, or HashTable value.

.PARAMETER Path
The path to a CSV file.

.PARAMETER StatusCode
The status code to set against the response.

.EXAMPLE
Write-PodeCsvResponse -Value "Name`nRick"

.EXAMPLE
Write-PodeCsvResponse -Value @{ Name = 'Rick' }

.EXAMPLE
Write-PodeCsvResponse -Path 'E:/Files/Names.csv'
#>
function Write-PodeCsvResponse {
    [CmdletBinding(DefaultParameterSetName = 'Value')]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'Value', ValueFromPipeline = $true, Position = 0)]
        $Value,

        [Parameter(Mandatory = $true, ParameterSetName = 'File')]
        [string]
        $Path,

        [Parameter()]
        [int]
        $StatusCode = 200
    )
    begin {
        $pipelineValue = @()
    }
    process {
        if ($PSCmdlet.ParameterSetName -eq 'Value') {
            $pipelineValue += $_
        }
    }    end {
        switch ($PSCmdlet.ParameterSetName.ToLowerInvariant()) {
            'file' {
                if (Test-PodePath $Path) {
                    $Value = Get-PodeFileContent -Path $Path
                }
            }

            'value' {
                if ($pipelineValue) {
                    $Value = $pipelineValue
                }
                if ($Value -isnot [string]) {
                    if (Test-PodeIsPSCore) {
                        $Value = ($Value | ConvertTo-Csv -Delimiter ',' -IncludeTypeInformation:$false)
                    }
                    else {
                        $Value = ($Value | ConvertTo-Csv -Delimiter ',' -NoTypeInformation)
                    }

                    $Value = ($Value -join ([environment]::NewLine))
                }
            }
        }

        if ([string]::IsNullOrWhiteSpace($Value)) {
            $Value = [string]::Empty
        }

        Write-PodeTextResponse -Value $Value -ContentType 'text/csv' -StatusCode $StatusCode
    }
}

<#
.SYNOPSIS
Writes HTML data to the Response.

.DESCRIPTION
Writes HTML data to the Response, setting the content type accordingly.

.PARAMETER Value
A String, PSObject, or HashTable value.

.PARAMETER Path
The path to a HTML file.

.PARAMETER StatusCode
The status code to set against the response.

.EXAMPLE
Write-PodeHtmlResponse -Value "Raw HTML can be placed here"

.EXAMPLE
Write-PodeHtmlResponse -Value @{ Message = 'Hello, all!' }

.EXAMPLE
Write-PodeHtmlResponse -Path 'E:/Site/About.html'
#>
function Write-PodeHtmlResponse {
    [CmdletBinding(DefaultParameterSetName = 'Value')]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'Value', ValueFromPipeline = $true, Position = 0)]
        $Value,

        [Parameter(Mandatory = $true, ParameterSetName = 'File')]
        [string]
        $Path,

        [Parameter()]
        [int]
        $StatusCode = 200
    )

    begin {
        $pipelineValue = @()
    }

    process {
        if ($PSCmdlet.ParameterSetName -eq 'Value') {
            $pipelineValue += $_
        }
    }

    end {
        switch ($PSCmdlet.ParameterSetName.ToLowerInvariant()) {
            'file' {
                if (Test-PodePath $Path) {
                    $Value = Get-PodeFileContent -Path $Path
                }
            }

            'value' {
                if ($pipelineValue) {
                    $Value = $pipelineValue
                }
                if ($Value -isnot [string]) {
                    $Value = ($Value | ConvertTo-Html)
                    $Value = ($Value -join ([environment]::NewLine))
                }
            }
        }

        if ([string]::IsNullOrWhiteSpace($Value)) {
            $Value = [string]::Empty
        }

        Write-PodeTextResponse -Value $Value -ContentType 'text/html' -StatusCode $StatusCode
    }
}


<#
.SYNOPSIS
Writes Markdown data to the Response.

.DESCRIPTION
Writes Markdown data to the Response, with the option to render it as HTML.

.PARAMETER Value
A String, PSObject, or HashTable value.

.PARAMETER Path
The path to a Markdown file.

.PARAMETER StatusCode
The status code to set against the response.

.PARAMETER AsHtml
If supplied, the Markdown will be converted to HTML. (This is only supported in PS7+)

.EXAMPLE
Write-PodeMarkdownResponse -Value '# Hello, world!' -AsHtml

.EXAMPLE
Write-PodeMarkdownResponse -Path 'E:/Site/About.md'
#>
function Write-PodeMarkdownResponse {
    [CmdletBinding(DefaultParameterSetName = 'Value')]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'Value', ValueFromPipeline = $true, Position = 0)]
        $Value,

        [Parameter(Mandatory = $true, ParameterSetName = 'File')]
        [string]
        $Path,

        [Parameter()]
        [int]
        $StatusCode = 200,

        [switch]
        $AsHtml
    )

    switch ($PSCmdlet.ParameterSetName.ToLowerInvariant()) {
        'file' {
            if (Test-PodePath $Path) {
                $Value = Get-PodeFileContent -Path $Path
            }
        }
    }

    if ([string]::IsNullOrWhiteSpace($Value)) {
        $Value = [string]::Empty
    }

    $mimeType = 'text/markdown'

    if ($AsHtml) {
        if ($PSVersionTable.PSVersion.Major -ge 7) {
            $mimeType = 'text/html'
            $Value = ($Value | ConvertFrom-Markdown).Html
        }
    }

    Write-PodeTextResponse -Value $Value -ContentType $mimeType -StatusCode $StatusCode
}

<#
.SYNOPSIS
Writes JSON data to the Response.

.DESCRIPTION
Writes JSON data to the Response, setting the content type accordingly.

.PARAMETER Value
A String, PSObject, or HashTable value. For non-string values, they will be converted to JSON.

.PARAMETER Path
The path to a JSON file.

.PARAMETER Depth
The Depth to generate the JSON document - the larger this value the worse performance gets.

.PARAMETER StatusCode
The status code to set against the response.

.PARAMETER NoCompress
The JSON document is not compressed (Human readable form)

.EXAMPLE
Write-PodeJsonResponse -Value '{"name": "Rick"}'

.EXAMPLE
Write-PodeJsonResponse -Value @{ Name = 'Rick' } -StatusCode 201

.EXAMPLE
Write-PodeJsonResponse -Path 'E:/Files/Names.json'
#>
function Write-PodeJsonResponse {
    [CmdletBinding(DefaultParameterSetName = 'Value')]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'Value', ValueFromPipeline = $true, Position = 0)]
        [AllowNull()]
        $Value,

        [Parameter(Mandatory = $true, ParameterSetName = 'File')]
        [string]
        $Path,

        [Parameter(ParameterSetName = 'Value')]
        [ValidateRange(0, 100)]
        [int]
        $Depth = 10,

        [Parameter()]
        [int]
        $StatusCode = 200,

        [Parameter(ParameterSetName = 'Value')]
        [switch]
        $NoCompress

    )
    begin {
        $pipelineValue = @()
    }

    process {
        if ($PSCmdlet.ParameterSetName -eq 'Value') {
            $pipelineValue += $_
        }
    }

    end {
        switch ($PSCmdlet.ParameterSetName.ToLowerInvariant()) {
            'file' {
                if (Test-PodePath $Path) {
                    $Value = Get-PodeFileContent -Path $Path
                }
                if ([string]::IsNullOrWhiteSpace($Value)) {
                    $Value = '{}'
                }
            }

            'value' {
                if ($pipelineValue) {
                    $Value = $pipelineValue
                }
                if ($Value -isnot [string]) {
                    $Value = (ConvertTo-Json -InputObject $Value -Depth $Depth -Compress:(!$NoCompress))
                }
            }
        }

        if ([string]::IsNullOrWhiteSpace($Value)) {
            $Value = '{}'
        }

        Write-PodeTextResponse -Value $Value -ContentType 'application/json' -StatusCode $StatusCode
    }
}


<#
.SYNOPSIS
Writes XML data to the Response.

.DESCRIPTION
Writes XML data to the Response, setting the content type accordingly.

.PARAMETER Value
A String, PSObject, or HashTable value.

.PARAMETER Path
The path to an XML file.

.PARAMETER Depth
The Depth to generate the XML document - the larger this value the worse performance gets.

.PARAMETER StatusCode
The status code to set against the response.

.EXAMPLE
Write-PodeXmlResponse -Value '<root><name>Rick</name></root>'

.EXAMPLE
Write-PodeXmlResponse -Value @{ Name = 'Rick' } -StatusCode 201

.EXAMPLE
Write-PodeXmlResponse -Path 'E:/Files/Names.xml'
#>
function Write-PodeXmlResponse {
    [CmdletBinding(DefaultParameterSetName = 'Value')]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'Value', ValueFromPipeline = $true, Position = 0)]
        [AllowNull()]
        $Value,

        [Parameter(Mandatory = $true, ParameterSetName = 'File')]
        [string]
        $Path,

        [Parameter(ParameterSetName = 'Value')]
        [ValidateRange(0, 100)]
        [int]
        $Depth = 10,

        [Parameter()]
        [int]
        $StatusCode = 200
    )
    begin {
        $pipelineValue = @()
    }

    process {
        if ($PSCmdlet.ParameterSetName -eq 'Value') {
            $pipelineValue += $_
        }
    }

    end {

        switch ($PSCmdlet.ParameterSetName.ToLowerInvariant()) {
            'file' {
                if (Test-PodePath $Path) {
                    $Value = Get-PodeFileContent -Path $Path
                }
            }

            'value' {
                if ($pipelineValue) {
                    $Value = $pipelineValue
                }
                if ($Value -isnot [string]) {
                    $Value = ($Value | ConvertTo-Xml -Depth $Depth -As String -NoTypeInformation)
                }
            }
        }

        if ([string]::IsNullOrWhiteSpace($Value)) {
            $Value = [string]::Empty
        }

        Write-PodeTextResponse -Value $Value -ContentType 'text/xml' -StatusCode $StatusCode
    }
}

<#
.SYNOPSIS
Writes YAML data to the Response.

.DESCRIPTION
Writes YAML data to the Response, setting the content type accordingly.

.PARAMETER Value
A String, PSObject, or HashTable value. For non-string values, they will be converted to YAML.

.PARAMETER Path
The path to a YAML file.

.PARAMETER ContentType
Because JSON content has not yet an official content type. one custom can be specified here (Default: 'application/x-yaml' )

.PARAMETER Depth
The Depth to generate the YAML document - the larger this value the worse performance gets.

.PARAMETER StatusCode
The status code to set against the response.

.EXAMPLE
Write-PodeYamlResponse -Value '{"name": "Rick"}'

.EXAMPLE
Write-PodeYamlResponse -Value @{ Name = 'Rick' } -StatusCode 201

.EXAMPLE
Write-PodeYamlResponse -Path 'E:/Files/Names.json'
#>
function Write-PodeYamlResponse {
    [CmdletBinding(DefaultParameterSetName = 'Value')]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'Value', ValueFromPipeline = $true, Position = 0)]
        [AllowNull()]
        $Value,

        [Parameter(Mandatory = $true, ParameterSetName = 'File')]
        [string]
        $Path,

        [Parameter()]
        [ValidatePattern('^\w+\/[\w\.\+-]+$')]
        [ValidateNotNullOrEmpty()]
        [string]
        $ContentType = 'application/x-yaml',


        [Parameter(ParameterSetName = 'Value')]
        [ValidateRange(0, 100)]
        [int]
        $Depth = 10,

        [Parameter()]
        [int]
        $StatusCode = 200
    )

    begin {
        $pipelineValue = @()
    }

    process {
        if ($PSCmdlet.ParameterSetName -eq 'Value') {
            $pipelineValue += $_
        }
    }

    end {

        switch ($PSCmdlet.ParameterSetName.ToLowerInvariant()) {
            'file' {
                if (Test-PodePath $Path) {
                    $Value = Get-PodeFileContent -Path $Path
                }
            }

            'value' {
                if ($pipelineValue) {
                    $Value = $pipelineValue
                }
                if ($Value -isnot [string]) {
                    $Value = ConvertTo-PodeYaml -InputObject $Value -Depth $Depth

                }
            }
        }
        if ([string]::IsNullOrWhiteSpace($Value)) {
            $Value = '[]'
        }

        Write-PodeTextResponse -Value $Value -ContentType $ContentType -StatusCode $StatusCode
    }
}



<#
.SYNOPSIS
Renders a dynamic, or static, View on the Response.

.DESCRIPTION
Renders a dynamic, or static, View on the Response; allowing for dynamic data to be supplied.

.PARAMETER Path
The path to a View, relative to the "/views" directory. (Extension is optional).

.PARAMETER Data
Any dynamic data to supply to a dynamic View.

.PARAMETER StatusCode
The status code to set against the response.

.PARAMETER Folder
If supplied, a custom views folder will be used.

.PARAMETER FlashMessages
Automatically supply all Flash messages in the current session to the View.

.EXAMPLE
Write-PodeViewResponse -Path 'index'

.EXAMPLE
Write-PodeViewResponse -Path 'accounts/profile_page' -Data @{ Username = 'Morty' }

.EXAMPLE
Write-PodeViewResponse -Path 'login' -FlashMessages
#>
function Write-PodeViewResponse {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]
        $Path,

        [Parameter()]
        [hashtable]
        $Data = @{},

        [Parameter()]
        [int]
        $StatusCode = 200,

        [Parameter()]
        [string]
        $Folder,

        [switch]
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
    if ($FlashMessages -and ($null -ne $WebEvent.Session.Data.Flash)) {
        $Data['flash'] = @{}

        foreach ($name in (Get-PodeFlashMessageNames)) {
            $Data.flash[$name] = (Get-PodeFlashMessage -Name $name)
        }
    }
    elseif ($null -eq $Data['flash']) {
        $Data['flash'] = @{}
    }

    # add view engine extension
    $ext = Get-PodeFileExtension -Path $Path
    if ([string]::IsNullOrWhiteSpace($ext)) {
        $Path += ".$($PodeContext.Server.ViewEngine.Extension)"
    }

    # only look in the view directories
    $viewFolder = $PodeContext.Server.InbuiltDrives['views']
    if (![string]::IsNullOrWhiteSpace($Folder)) {
        $viewFolder = $PodeContext.Server.Views[$Folder]
    }

    $Path = [System.IO.Path]::Combine($viewFolder, $Path)

    # test the file path, and set status accordingly
    if (!(Test-PodePath $Path)) {
        return
    }

    # run any engine logic and render it
    $engine = (Get-PodeViewEngineType -Path $Path)
    $value = (Get-PodeFileContentUsingViewEngine -Path $Path -Data $Data)

    switch ($engine.ToLowerInvariant()) {
        'md' {
            Write-PodeMarkdownResponse -Value $value -StatusCode $StatusCode -AsHtml
        }

        default {
            Write-PodeHtmlResponse -Value $value -StatusCode $StatusCode
        }
    }
}


<#
.SYNOPSIS
Sets the Status Code of the Response, and controls rendering error pages.

.DESCRIPTION
Sets the Status Code of the Response, and controls rendering error pages.

.PARAMETER Code
The Status Code to set on the Response.

.PARAMETER Description
An optional Status Description.

.PARAMETER Exception
An exception to use when detailing error information on error pages.

.PARAMETER ContentType
The content type of the error page to use.

.PARAMETER NoErrorPage
Don't render an error page when the Status Code is 400+.

.EXAMPLE
Set-PodeResponseStatus -Code 404

.EXAMPLE
Set-PodeResponseStatus -Code 500 -Exception $_.Exception

.EXAMPLE
Set-PodeResponseStatus -Code 500 -Exception $_.Exception -ContentType 'application/json'
#>
function Set-PodeResponseStatus {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [int]
        $Code,

        [Parameter()]
        [string]
        $Description,

        [Parameter()]
        $Exception,

        [Parameter()]
        [string]
        $ContentType = $null,

        [switch]
        $NoErrorPage
    )

    # already sent? skip
    if ($WebEvent.Response.Sent) {
        return
    }

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

<#
.SYNOPSIS
Redirecting a user to a new URL.

.DESCRIPTION
Redirecting a user to a new URL, or the same URL as the Request but a different Protocol - or other components.

.PARAMETER Url
Redirect the user to a new URL, or a relative path.

.PARAMETER EndpointName
The Name of an Endpoint to redirect to.

.PARAMETER Port
Change the port of the current Request before redirecting.

.PARAMETER Protocol
Change the protocol of the current Request before redirecting.

.PARAMETER Address
Change the domain address of the current Request before redirecting.

.PARAMETER Moved
Set the Status Code as "301 Moved", rather than "302 Redirect".

.EXAMPLE
Move-PodeResponseUrl -Url 'https://google.com'

.EXAMPLE
Move-PodeResponseUrl -Url '/about'

.EXAMPLE
Move-PodeResponseUrl -Protocol HTTPS

.EXAMPLE
Move-PodeResponseUrl -Port 9000 -Moved
#>
function Move-PodeResponseUrl {
    [CmdletBinding(DefaultParameterSetName = 'Url')]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'Url')]
        [string]
        $Url,

        [Parameter(ParameterSetName = 'Endpoint')]
        [string]
        $EndpointName,

        [Parameter(ParameterSetName = 'Components')]
        [int]
        $Port = 0,

        [Parameter(ParameterSetName = 'Components')]
        [ValidateSet('', 'Http', 'Https')]
        [string]
        $Protocol,

        [Parameter(ParameterSetName = 'Components')]
        [string]
        $Address,

        [switch]
        $Moved
    )

    # build the url
    if ($PSCmdlet.ParameterSetName -ieq 'components') {
        $uri = $WebEvent.Request.Url

        # set the protocol
        $Protocol = $Protocol.ToLowerInvariant()
        if ([string]::IsNullOrWhiteSpace($Protocol)) {
            $Protocol = $uri.Scheme
        }

        # set the domain
        if ([string]::IsNullOrWhiteSpace($Address)) {
            $Address = $uri.Host
        }

        # set the port
        if ($Port -le 0) {
            $Port = $uri.Port
        }

        $PortStr = [string]::Empty
        if (@(80, 443) -notcontains $Port) {
            $PortStr = ":$($Port)"
        }

        # combine to form the url
        $Url = "$($Protocol)://$($Address)$($PortStr)$($uri.PathAndQuery)"
    }

    # build the url from an endpoint
    elseif ($PSCmdlet.ParameterSetName -ieq 'endpoint') {
        $endpoint = Get-PodeEndpointByName -Name $EndpointName -ThrowError

        # set the port
        $PortStr = [string]::Empty
        if (@(80, 443) -notcontains $endpoint.Port) {
            $PortStr = ":$($endpoint.Port)"
        }

        $Url = "$($endpoint.Protocol)://$($endpoint.FriendlyName)$($PortStr)$($WebEvent.Request.Url.PathAndQuery)"
    }

    Set-PodeHeader -Name 'Location' -Value $Url

    if ($Moved) {
        Set-PodeResponseStatus -Code 301 -Description 'Moved'
    }
    else {
        Set-PodeResponseStatus -Code 302 -Description 'Redirect'
    }
}

<#
.SYNOPSIS
Writes data to a TCP socket stream.

.DESCRIPTION
Writes data to a TCP socket stream.

.PARAMETER Message
The message to write

.EXAMPLE
Write-PodeTcpClient -Message '250 OK'
#>
function Write-PodeTcpClient {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true)]
        [string]
        $Message
    )

    $TcpEvent.Response.WriteLine($Message, $true)
}

<#
.SYNOPSIS
Reads data from a TCP socket stream.

.DESCRIPTION
Reads data from a TCP socket stream.

.PARAMETER Timeout
An optional Timeout in milliseconds.

.PARAMETER CheckBytes
An optional array of bytes to check at the end of a receievd data stream, to determine if the data is complete.

.PARAMETER CRLFMessageEnd
If supplied, the CheckBytes will be set to 13 and 10 to make sure a message ends with CR and LF.

.EXAMPLE
$data = Read-PodeTcpClient

.EXAMPLE
$data = Read-PodeTcpClient -CRLFMessageEnd
#>
function Read-PodeTcpClient {
    [CmdletBinding(DefaultParameterSetName = 'default')]
    [OutputType([string])]
    param(
        [Parameter()]
        [int]
        $Timeout = 0,

        [Parameter(ParameterSetName = 'CheckBytes')]
        [byte[]]
        $CheckBytes = $null,

        [Parameter(ParameterSetName = 'CRLF')]
        [switch]
        $CRLFMessageEnd
    )

    $cBytes = $CheckBytes
    if ($CRLFMessageEnd) {
        $cBytes = [byte[]]@(13, 10)
    }

    return (Wait-PodeTask -Task $TcpEvent.Request.Read($cBytes, $PodeContext.Tokens.Cancellation.Token) -Timeout $Timeout)
}

<#
.SYNOPSIS
Close an open TCP client connection

.DESCRIPTION
Close an open TCP client connection

.EXAMPLE
Close-PodeTcpClient
#>
function Close-PodeTcpClient {
    [CmdletBinding()]
    param()

    $TcpEvent.Request.Close()
}

<#
.SYNOPSIS
Saves any uploaded files on the Request to the File System.

.DESCRIPTION
Saves any uploaded files on the Request to the File System.

.PARAMETER Key
The name of the key within the $WebEvent's Data HashTable that stores the file names.

.PARAMETER Path
The path to save files. If this is a directory then the file name of the uploaded file will be used, but if this is a file path then that name is used instead.
If the Request has multiple files in, and you specify a file path, then all files will be saved to that one file path - overwriting each other.

.PARAMETER FileName
An optional FileName to save a specific files if multiple files were supplied in the Request. By default, every file is saved.

.EXAMPLE
Save-PodeRequestFile -Key 'avatar'

.EXAMPLE
Save-PodeRequestFile -Key 'avatar' -Path 'F:/Images'

.EXAMPLE
Save-PodeRequestFile -Key 'avatar' -Path 'F:/Images' -FileName 'icon.png'
#>
function Save-PodeRequestFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Key,

        [Parameter()]
        [string]
        $Path = '.',

        [Parameter()]
        [string[]]
        $FileName
    )

    # if path is '.', replace with server root
    $Path = Get-PodeRelativePath -Path $Path -JoinRoot

    # ensure the parameter name exists in data
    if (!(Test-PodeRequestFile -Key $Key)) {
        throw "A parameter called '$($Key)' was not supplied in the request, or has no data available"
    }

    # get the file names
    $files = @($WebEvent.Data[$Key])
    if (($null -ne $FileName) -and ($FileName.Length -gt 0)) {
        $files = @(foreach ($file in $files) {
                if ($FileName -icontains $file) {
                    $file
                }
            })
    }

    # ensure the file data exists
    foreach ($file in $files) {
        if (!$WebEvent.Files.ContainsKey($file)) {
            throw "No data for file '$($file)' was uploaded in the request"
        }
    }

    # save the files
    foreach ($file in $files) {
        # if the path is a directory, add the filename
        $filePath = $Path
        if (Test-Path -Path $filePath -PathType Container) {
            $filePath = [System.IO.Path]::Combine($filePath, $file)
        }

        # save the file
        $WebEvent.Files[$file].Save($filePath)
    }
}

<#
.SYNOPSIS
Test to see if the Request contains the key for any uploaded files.

.DESCRIPTION
Test to see if the Request contains the key for any uploaded files.

.PARAMETER Key
The name of the key within the $WebEvent's Data HashTable that stores the file names.

.PARAMETER FileName
An optional FileName to test for a specific file within the list of uploaded files.

.EXAMPLE
Test-PodeRequestFile -Key 'avatar'

.EXAMPLE
Test-PodeRequestFile -Key 'avatar' -FileName 'icon.png'
#>
function Test-PodeRequestFile {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Key,

        [Parameter()]
        [string]
        $FileName
    )

    # ensure the parameter name exists in data
    if (!$WebEvent.Data.ContainsKey($Key)) {
        return $false
    }

    # ensure it has filenames
    if ([string]::IsNullOrEmpty($WebEvent.Data[$Key])) {
        return $false
    }

    # do we have any specific files?
    if (![string]::IsNullOrEmpty($FileName)) {
        return (@($WebEvent.Data[$Key]) -icontains $FileName)
    }

    # we have files
    return $true
}

<#
.SYNOPSIS
Short description

.DESCRIPTION
Long description

.PARAMETER Type
The type name of the view engine (inbuilt types are: Pode and HTML).

.PARAMETER ScriptBlock
A ScriptBlock for specifying custom view engine rendering rules.

.PARAMETER Extension
A custom extension for the engine's files.

.EXAMPLE
Set-PodeViewEngine -Type HTML

.EXAMPLE
Set-PodeViewEngine -Type Markdown

.EXAMPLE
Set-PodeViewEngine -Type PSHTML -Extension PS1 -ScriptBlock { param($path, $data) /* logic */ }
#>
function Set-PodeViewEngine {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Type,

        [Parameter()]
        [scriptblock]
        $ScriptBlock = $null,

        [Parameter()]
        [string]
        $Extension
    )

    # truncate markdown
    if ($Type -ieq 'Markdown') {
        $Type = 'md'
    }

    # override extension with type
    if ([string]::IsNullOrWhiteSpace($Extension)) {
        $Extension = $Type
    }

    # check if the scriptblock has any using vars
    if ($null -ne $ScriptBlock) {
        $ScriptBlock, $usingVars = Convert-PodeScopedVariables -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState
    }

    # setup view engine config
    $PodeContext.Server.ViewEngine.Type = $Type.ToLowerInvariant()
    $PodeContext.Server.ViewEngine.Extension = $Extension.ToLowerInvariant()
    $PodeContext.Server.ViewEngine.ScriptBlock = $ScriptBlock
    $PodeContext.Server.ViewEngine.UsingVariables = $usingVars
    $PodeContext.Server.ViewEngine.IsDynamic = (@('html', 'md') -inotcontains $Type)
}

<#
.SYNOPSIS
Includes the contents of a partial View into another dynamic View.

.DESCRIPTION
Includes the contents of a partial View into another dynamic View. The partial View can be static or dynamic.

.PARAMETER Path
The path to a partial View, relative to the "/views" directory. (Extension is optional).

.PARAMETER Data
Any dynamic data to supply to a dynamic partial View.

.PARAMETER Folder
If supplied, a custom views folder will be used.

.EXAMPLE
Use-PodePartialView -Path 'shared/footer'
#>
function Use-PodePartialView {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]
        $Path,

        [Parameter()]
        $Data = @{},

        [Parameter()]
        [string]
        $Folder
    )

    # default data if null
    if ($null -eq $Data) {
        $Data = @{}
    }
    # add view engine extension
    $ext = Get-PodeFileExtension -Path $Path
    if ([string]::IsNullOrWhiteSpace($ext)) {
        $Path += ".$($PodeContext.Server.ViewEngine.Extension)"
    }

    # only look in the view directory
    $viewFolder = $PodeContext.Server.InbuiltDrives['views']
    if (![string]::IsNullOrWhiteSpace($Folder)) {
        $viewFolder = $PodeContext.Server.Views[$Folder]
    }

    $Path = [System.IO.Path]::Combine($viewFolder, $Path)

    # test the file path, and set status accordingly
    if (!(Test-PodePath $Path -NoStatus)) {
        throw "File not found at path: $($Path)"
    }

    # run any engine logic
    return (Get-PodeFileContentUsingViewEngine -Path $Path -Data $Data)
}

<#
.SYNOPSIS
Broadcasts a message to connected WebSocket clients.

.DESCRIPTION
Broadcasts a message to all, or some, connected WebSocket clients. You can specify a path to send messages to, or a specific ClientId.

.PARAMETER Value
A String, PSObject, or HashTable value. For non-string values, they will be converted to JSON.

.PARAMETER Path
The Path of connected clients to send the message.

.PARAMETER ClientId
A specific ClientId of a connected client to send a message. Not currently used.

.PARAMETER Depth
The Depth to generate the JSON document - the larger this value the worse performance gets.

.PARAMETER Mode
The Mode to broadcast a message: Auto, Broadcast, Direct. (Default: Auto)

.PARAMETER IgnoreEvent
If supplied, if a SignalEvent is available it's data, such as path/clientId, will be ignored.

.EXAMPLE
Send-PodeSignal -Value @{ Message = 'Hello, world!' }

.EXAMPLE
Send-PodeSignal -Value @{ Data = @(123, 100, 101) } -Path '/response-charts'
#>
function Send-PodeSignal {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true)]
        $Value,

        [Parameter()]
        [string]
        $Path,

        [Parameter()]
        [string]
        $ClientId,

        [Parameter()]
        [int]
        $Depth = 10,

        [Parameter()]
        [ValidateSet('Auto', 'Broadcast', 'Direct')]
        [string]
        $Mode = 'Auto',

        [switch]
        $IgnoreEvent
    )
    # error if not configured
    if (!$PodeContext.Server.Signals.Enabled) {
        throw 'WebSockets have not been configured to send signal messages'
    }

    # do nothing if no value
    if (($null -eq $Value) -or ([string]::IsNullOrEmpty($Value))) {
        return
    }

    # jsonify the value
    if ($Value -isnot [string]) {
        if ($Depth -le 0) {
            $Value = (ConvertTo-Json -InputObject $Value -Compress)
        }
        else {
            $Value = (ConvertTo-Json -InputObject $Value -Depth $Depth -Compress)
        }
    }

    # check signal event
    if (!$IgnoreEvent -and ($null -ne $SignalEvent)) {
        if ([string]::IsNullOrWhiteSpace($Path)) {
            $Path = $SignalEvent.Data.Path
        }

        if ([string]::IsNullOrWhiteSpace($ClientId)) {
            $ClientId = $SignalEvent.Data.ClientId
        }

        if (($Mode -ieq 'Auto') -and ($SignalEvent.Data.Direct -or ($SignalEvent.ClientId -ieq $SignalEvent.Data.ClientId))) {
            $Mode = 'Direct'
        }
    }

    # broadcast or direct?
    if ($Mode -iin @('Auto', 'Broadcast')) {
        $PodeContext.Server.Signals.Listener.AddServerSignal($Value, $Path, $ClientId)
    }
    else {
        $SignalEvent.Response.Write($Value)
    }
}

<#
.SYNOPSIS
Add a custom path that contains additional views.

.DESCRIPTION
Add a custom path that contains additional views.

.PARAMETER Name
The Name of the views folder.

.PARAMETER Source
The literal, or relative, path to the directory that contains views.

.EXAMPLE
Add-PodeViewFolder -Name 'assets' -Source './assets'
#>
function Add-PodeViewFolder {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $true)]
        [string]
        $Source
    )

    # ensure the folder doesn't already exist
    if ($PodeContext.Server.Views.ContainsKey($Name)) {
        throw "The Views folder name already exists: $($Name)"
    }

    # ensure the path exists at server root
    $Source = Get-PodeRelativePath -Path $Source -JoinRoot
    if (!(Test-PodePath -Path $Source -NoStatus)) {
        throw "The Views path does not exist: $($Source)"
    }

    # setup a temp drive for the path
    $Source = New-PodePSDrive -Path $Source

    # add the route(s)
    Write-Verbose "Adding View Folder: [$($Name)] $($Source)"
    $PodeContext.Server.Views[$Name] = $Source
}

<#
.SYNOPSIS
Pre-emptively send an HTTP response back to the client. This can be dangerous, so only use this function if you know what you're doing.

.DESCRIPTION
Pre-emptively send an HTTP response back to the client. This can be dangerous, so only use this function if you know what you're doing.

.EXAMPLE
Send-PodeResponse
#>
function Send-PodeResponse {
    [CmdletBinding()]
    param()

    if ($null -ne $WebEvent.Response) {
        $WebEvent.Response.Send()
    }
}