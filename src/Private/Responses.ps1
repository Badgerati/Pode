function Show-PodeErrorPage {
    param(
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
            Message    = [System.Web.HttpUtility]::HtmlEncode($Exception.Exception.Message)
            StackTrace = [System.Web.HttpUtility]::HtmlEncode($Exception.ScriptStackTrace)
            Line       = [System.Web.HttpUtility]::HtmlEncode($Exception.InvocationInfo.PositionMessage)
            Category   = [System.Web.HttpUtility]::HtmlEncode($Exception.CategoryInfo.ToString())
        }
    }

    # setup the data object for dynamic pages
    $data = @{
        Url         = [System.Web.HttpUtility]::HtmlEncode((Get-PodeUrl))
        Status      = @{
            Code        = $Code
            Description = $Description
        }
        Exception   = $ex
        ContentType = $errorPage.ContentType
    }

    # write the error page to the stream
    Write-PodeFileResponse -Path $errorPage.Path -Data $data -ContentType $errorPage.ContentType
}



<#
.SYNOPSIS
Serves files as HTTP responses in a Pode web server, handling both dynamic and static content.

.DESCRIPTION
This function serves files from the server to the client, supporting both static files and files that are dynamically processed by a view engine.
For dynamic content, it uses the server's configured view engine to process the file and returns the rendered content.
For static content, it simply returns the file's content. The function allows for specifying content type, cache control, and HTTP status code.

.PARAMETER RelativePath
The relative path to the file to be served. This path is resolved against the server's root directory.

.PARAMETER Data
A hashtable of data that can be passed to the view engine for dynamic files.

.PARAMETER ContentType
The MIME type of the response. If not provided, it is inferred from the file extension.

.PARAMETER MaxAge
The maximum age (in seconds) for which the response can be cached by the client. Applies only to static content.

.PARAMETER StatusCode
The HTTP status code to accompany the response. Defaults to 200 (OK).

.PARAMETER Cache
A switch to indicate whether the response should include HTTP caching headers. Applies only to static content.

.EXAMPLE
Write-PodeFileResponseInternal -RelativePath 'index.pode' -Data @{ Title = 'Home Page' } -ContentType 'text/html'

Serves the 'index.pode' file as an HTTP response, processing it with the view engine and passing in a title for dynamic content rendering.

.EXAMPLE
Write-PodeFileResponseInternal -RelativePath 'logo.png' -ContentType 'image/png' -Cache

Serves the 'logo.png' file as a static file with the specified content type and caching enabled.

.OUTPUTS
None. The function writes directly to the HTTP response stream.
#>

function Write-PodeFileResponseInternal {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNull()]
        [string]
        $RelativePath,

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
        $Cache
    )

    # are we dealing with a dynamic file for the view engine? (ignore html)
    # Determine if the file is dynamic and should be processed by the view engine
    $mainExt = Get-PodeFileExtension -Path $RelativePath -TrimPeriod

    # generate dynamic content
    if (![string]::IsNullOrWhiteSpace($mainExt) -and (
        ($mainExt -ieq 'pode') -or
        ($mainExt -ieq $PodeContext.Server.ViewEngine.Extension -and $PodeContext.Server.ViewEngine.IsDynamic)
        )
    ) {
        # Process dynamic content with the view engine
        $content = Get-PodeFileContentUsingViewEngine -Path $RelativePath -Data $Data

        # Determine the correct content type for the response
        # get the sub-file extension, if empty, use original
        $subExt = Get-PodeFileExtension -Path (Get-PodeFileName -Path $RelativePath -WithoutExtension) -TrimPeriod
        $subExt = (Protect-PodeValue -Value $subExt -Default $mainExt)

        $ContentType = (Protect-PodeValue -Value $ContentType -Default (Get-PodeContentType -Extension $subExt))
        # Write the processed content as the HTTP response
        Write-PodeTextResponse -Value $content -ContentType $ContentType -StatusCode $StatusCode
    }
    # this is a static file
    else {
        if (Test-PodeIsPSCore) {
            $content = (Get-Content -Path $RelativePath -Raw -AsByteStream)
        }
        else {
            $content = (Get-Content -Path $RelativePath -Raw -Encoding byte)
        }
        if ($null -ne $content) {
            # Determine and set the content type for static files
            $ContentType = Protect-PodeValue -Value $ContentType -Default (Get-PodeContentType -Extension $mainExt)
            # Write the file content as the HTTP response
            Write-PodeTextResponse -Bytes $content -ContentType $ContentType -MaxAge $MaxAge -StatusCode $StatusCode -Cache:$Cache
        }
        else {
            # If the file does not exist, set the HTTP response status to 404 Not Found
            Set-PodeResponseStatus -Code 404
        }
    }
}

<#
.SYNOPSIS
Serves a directory listing as a web page.

.DESCRIPTION
The Write-PodeDirectoryResponseInternal function generates an HTML response that lists the contents of a specified directory,
allowing for browsing of files and directories. It supports both Windows and Unix-like environments by adjusting the
display of file attributes accordingly. If the path is a directory, it generates a browsable HTML view; otherwise, it
serves the file directly.

.PARAMETER RelativePath
The relative path to the directory that should be displayed. This path is resolved and used to generate a list of contents.

.PARAMETER RootPath
The Root path that is the base for the relative path.

.EXAMPLE
# resolve for relative path
$RelativePath = Get-PodeRelativePath -Path './static' -JoinRoot
Write-PodeDirectoryResponseInternal -RelativePath './static'

Generates and serves an HTML page that lists the contents of the './static' directory, allowing users to click through files and directories.
#>
function Write-PodeDirectoryResponseInternal {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [string]
        $RelativePath,

        [Parameter()]
        [string]
        $RootPath
    )
    # Retrieve the child items of the specified directory
    $child = Get-ChildItem -Path $RelativePath
    $pathSplit = $RelativePath.Split(':')
    $leaf = $pathSplit[1]

    # Determine if the server is running in Windows mode or is running a varsion that support Linux
    # https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/get-childitem?view=powershell-7.4#example-10-output-for-non-windows-operating-systems
    $windowsMode = ((Test-PodeIsWindows) -or ($PSVersionTable.PSVersion -lt [version]'7.1.0') )

    # Construct the HTML content for the file browser view
    $htmlContent = [System.Text.StringBuilder]::new()

    # Handle navigation to the parent directory (..)
    if ($leaf -ne '\' -and $leaf -ne '/') {
        $pathSegments = $leaf -split '[\\/]+'
        $baseEncodedSegments = $pathSegments | ForEach-Object {
            # Use [Uri]::EscapeDataString for encoding to ensure spaces are encoded as %20 and other special characters are properly encoded
            [Uri]::EscapeDataString($_)
        }
        $baseLink = $baseEncodedSegments -join '/'
        $Item = Get-Item '..'
        if ($null -eq $RootPath -or $RootPath -eq '/') {
            $ParentLink = $baseLink.TrimEnd('/').Substring(0, $baseLink.TrimEnd('/').LastIndexOf('/') + 1)

        }
        else {
            $baseLink = $RootPath + $baseLink
            $ParentLink = $baseLink.TrimEnd('/').Substring(0, $baseLink.TrimEnd('/').LastIndexOf('/') + 1)

        }

        #  # Add the parent directory link
        if ($windowsMode) {
            $htmlContent.AppendLine("<tr> <td class='mode'>$($item.Mode)</td> <td class='dateTime'>$($item.CreationTime.ToString('yyyy-MM-dd HH:mm:ss'))</td> <td class='dateTime'>$($item.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))</td> <td class='size'></td> <td class='icon'><i class='bi bi-folder2-open'></td> <td class='name'><a href='$ParentLink'>..</a></td> </tr>")
        }
        else {
            $htmlContent.AppendLine("<tr> <td class='unixMode'>$($item.UnixMode)</td> <td class='user'>$($item.User)</td> <td class='group'>$($item.Group)</td> <td class='dateTime'>$($item.CreationTime.ToString('yyyy-MM-dd HH:mm:ss'))</td> <td class='dateTime'>$($item.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))</td> <td class='size'></td> <td class='icon'><i class='bi bi-folder'></td> <td class='name'><a href='$ParentLink'>..</a></td> </tr>")
        }
    }
    else {
        if ($null -eq $RootPath -or $RootPath -eq '/') {
            $baseLink = ''
        }
        else {
            $baseLink = $RootPath
        }
    }

    if (!$baselink.EndsWith('/')) {
        $baselink = "$baselink/"
    }

    foreach ($item in $child) {
        if ($item.PSIsContainer) {
            $size = ''
            $icon = 'bi bi-folder2'
            $link = "$baseLink$([uri]::EscapeDataString($item.Name))/"
        }
        else {
            $size = '{0:N2}KB' -f ($item.Length / 1KB)
            $icon = 'bi bi-file'
            $link = "$baseLink$([uri]::EscapeDataString($item.Name))"
        }

        # Format each item as an HTML row
        if ($windowsMode) {
            $htmlContent.AppendLine("<tr> <td class='mode'>$($item.Mode)</td> <td class='dateTime'>$($item.CreationTime.ToString('yyyy-MM-dd HH:mm:ss'))</td> <td class='dateTime'>$($item.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))</td> <td class='size'>$size</td> <td class='icon'><i class='$icon'></i></td> <td class='name'><a href='$link'>$($item.Name)</a></td> </tr>")
        }
        else {
            $htmlContent.AppendLine("<tr> <td class='unixMode'>$($item.UnixMode)</td> <td class='user'>$($item.User)</td> <td class='group'>$($item.Group)</td> <td class='dateTime'>$($item.CreationTime.ToString('yyyy-MM-dd HH:mm:ss'))</td> <td class='dateTime'>$($item.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))</td> <td class='size'>$size</td> <td class='icon'><i class='$icon'></i></td> <td class='name'><a href='$link'>$($item.Name)</a></td> </tr>")
        }
    }

    $Data = @{
        rootPath    = $RootPath
        path        = $leaf.Replace('\', '/')
        windowsMode = $windowsMode.ToString().ToLower()
        fileContent = $htmlContent.ToString()   # Convert the StringBuilder content to a string
    }

    $podeRoot = Get-PodeModuleMiscPath
    # Write the response
    Write-PodeFileResponse -Path ([System.IO.Path]::Combine($podeRoot, 'default-file-browsing.html.pode')) -Data $Data
}


<#
.SYNOPSIS
Sends a file as an attachment in the response, supporting both file streaming and directory browsing options.

.DESCRIPTION
The Write-PodeAttachmentResponseInternal function is designed to handle HTTP responses for file downloads or directory browsing within a Pode web server. It resolves the given file or directory path, sets the appropriate content type, and configures the response to either download the file as an attachment or list the directory contents if browsing is enabled. The function supports both PowerShell Core and Windows PowerShell environments for file content retrieval.

.PARAMETER Path
The path to the file or directory. This parameter is mandatory and accepts pipeline input. The function resolves relative paths based on the server's root directory.

.PARAMETER ContentType
The MIME type of the file being served. This is validated against a pattern to ensure it's in the format 'type/subtype'. If not specified, the function attempts to determine the content type based on the file extension.

.PARAMETER FileBrowser
A switch parameter that, when present, enables directory browsing. If the path points to a directory and this parameter is enabled, the function will list the directory's contents instead of returning a 404 error.

.PARAMETER RootPath
The root directory path used for resolving relative paths. Defaults to '/' if not specified.

.EXAMPLE
Write-PodeAttachmentResponseInternal -Path './files/document.pdf' -ContentType 'application/pdf'

Serves the 'document.pdf' file with the 'application/pdf' MIME type as a downloadable attachment.

.EXAMPLE
Write-PodeAttachmentResponseInternal -Path './files' -FileBrowser

Lists the contents of the './files' directory if the FileBrowser switch is enabled; otherwise, returns a 404 error.

.NOTES
This function integrates with Pode's internal handling of HTTP responses, leveraging other Pode-specific functions like Get-PodeContentType and Set-PodeResponseStatus. It differentiates between streamed and serverless environments to optimize file delivery.

#>
function Write-PodeAttachmentResponseInternal {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]
        $Path,

        [Parameter()]
        [string]
        $ContentType,

        [Parameter()]
        [switch]
        $FileBrowser,

        [Parameter()]
        [string]
        $RootPath = '/'

    )

    # resolve for relative path
    $Path = Get-PodeRelativePath -Path $Path -JoinRoot

    # Attempt to retrieve information about the path
    $pathInfo = Get-Item -Path $Path -ErrorAction Continue

    # Check if the path exists
    if ($null -eq $pathInfo) {
        #if not exist try with to find with public Route if exist
        $Path = Find-PodePublicRoute -Path $Path 
        if ($Path) {
            # only attach files from public/static-route directories when path is relative
            $Path = Get-PodeRelativePath -Path $Path -JoinRoot
            # Attempt to retrieve information about the path
            $pathInfo = Get-Item -Path $Path -ErrorAction Continue
        }
        if ($null -eq $pathInfo) {
            # If not, set the response status to 404 Not Found
            Set-PodeResponseStatus -Code 404
            return
        }
    }

    if ( $pathInfo.PSIsContainer) {
        # If directory browsing is enabled, use the directory response function
        if ($FileBrowser.isPresent) {
            Write-PodeDirectoryResponseInternal -RelativePath $Path -RootPath $RootPath
            return
        }
        else {
            # If browsing is not enabled, return a 404 error
            Set-PodeResponseStatus -Code 404
            return
        }
    }
    try {
        # setup the content type and disposition
        if (!$ContentType) {
            $WebEvent.Response.ContentType = (Get-PodeContentType -Extension $pathInfo.Extension)
        }
        else {
            $WebEvent.Response.ContentType = $ContentType
        }

        Set-PodeHeader -Name 'Content-Disposition' -Value "attachment; filename=$($pathInfo.Name)"

        # if serverless, get the content raw and return
        if (!$WebEvent.Streamed) {
            if (Test-PodeIsPSCore) {
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
            $WebEvent.Response.SendChunked = $false

            # set file as an attachment on the response
            $buffer = [byte[]]::new(64 * 1024)
            $read = 0

            # open up the file as a stream
            $fs = (Get-Item $Path).OpenRead()
            $WebEvent.Response.ContentLength64 = $fs.Length

            while (($read = $fs.Read($buffer, 0, $buffer.Length)) -gt 0) {
                $WebEvent.Response.OutputStream.Write($buffer, 0, $read)
            }
        }
    }
    finally {
        Close-PodeDisposable -Disposable $fs
    }

}