<#
.SYNOPSIS
Displays a customized error page based on the provided error code and additional error details.

.DESCRIPTION
This function is responsible for displaying a custom error page when an error occurs within a Pode web application. It takes an error code, a description, an exception object, and a content type as input. The function then attempts to find a corresponding error page based on the error code and content type. If a custom error page is found, and if exception details are to be shown (as per server settings), it builds a detailed exception message. Finally, it writes the error page to the response stream, displaying the custom error page to the user.

.PARAMETER Code
The HTTP status code of the error. This code is used to find a matching custom error page.

.PARAMETER Description
A descriptive message about the error. This is displayed on the error page if available.

.PARAMETER Exception
The exception object that caused the error. If exception tracing is enabled, details from this object are displayed on the error page.

.PARAMETER ContentType
The content type of the error page to be displayed. This is used to select an appropriate error page format (e.g., HTML, JSON).

.EXAMPLE
Show-PodeErrorPage -Code 404 -Description "Not Found" -ContentType "text/html"

This example shows how to display a custom 404 Not Found error page in HTML format.

.OUTPUTS
None. This function writes the error page directly to the response stream.

.NOTES
- The function uses `Find-PodeErrorPage` to locate a custom error page based on the HTTP status code and content type.
- It checks for server configuration to determine whether to show detailed exception information on the error page.
- The function relies on the global `$PodeContext` variable for server settings and to encode exception and URL details safely.
- `Write-PodeFileResponse` is used to send the custom error page as the response, along with any dynamic data (e.g., exception details, URL).
- This is an internal function and may change in future releases of Pode.
#>
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

.PARAMETER Path
The relative path to the file to be served. This path is resolved against the server's root directory.

.PARAMETER FileInfo
A FileSystemInfo object to use instead of the path.

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

.PARAMETER NoEscape
If supplied, the path will not be escaped. This is useful for paths that contain expected wildcards, or are already escaped.

.EXAMPLE
Write-PodeFileResponseInternal -Path 'index.pode' -Data @{ Title = 'Home Page' } -ContentType 'text/html'

Serves the 'index.pode' file as an HTTP response, processing it with the view engine and passing in a title for dynamic content rendering.

.EXAMPLE
Write-PodeFileResponseInternal -Path 'logo.png' -ContentType 'image/png' -Cache

Serves the 'logo.png' file as a static file with the specified content type and caching enabled.

.OUTPUTS
None. The function writes directly to the HTTP response stream.

.NOTES
This is an internal function and may change in future releases of Pode.
#>
function Write-PodeFileResponseInternal {
    [CmdletBinding(DefaultParameterSetName = 'Path')]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'Path')]
        [string]
        $Path,

        [Parameter(Mandatory = $true, ParameterSetName = 'FileInfo')]
        [System.IO.FileSystemInfo]
        $FileInfo,

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
        $FileBrowser,

        [switch]
        $NoEscape
    )

    # if the file info isn't supplied, get it from the path
    if ($null -eq $FileInfo) {
        $Path = Protect-PodePath -Path $Path -NoEscape:$NoEscape
        $FileInfo = Test-PodePath -Path $Path -Force -ReturnItem -FailOnDirectory:(!$FileBrowser)
    }

    # if the file info is still null, return
    if ($null -eq $FileInfo) {
        return
    }

    # Check if the path is a directory, and if enabled, use the directory response function
    if ($FileInfo.PSIsContainer) {
        Write-PodeDirectoryResponseInternal -DirectoryInfo $FileInfo
        return
    }

    # are we dealing with a dynamic file for the view engine? (ignore html)
    # Determine if the file is dynamic and should be processed by the view engine
    $mainExt = $FileInfo.Extension.TrimStart('.')

    # generate dynamic content
    if (![string]::IsNullOrEmpty($mainExt) -and (
            ($mainExt -ieq 'pode') -or
            ($mainExt -ieq $PodeContext.Server.ViewEngine.Extension -and $PodeContext.Server.ViewEngine.IsDynamic)
        )
    ) {
        # Process dynamic content with the view engine
        $content = Get-PodeFileContentUsingViewEngine -FileInfo $FileInfo -Data $Data

        # Determine the correct content type for the response
        # get the sub-file extension, if empty, use original
        $subExt = [System.IO.Path]::GetExtension($FileInfo.BaseName).TrimStart('.')
        $subExt = Protect-PodeValue -Value $subExt -Default $mainExt
        $ContentType = Protect-PodeValue -Value $ContentType -Default (Get-PodeContentType -Extension $subExt)

        # Write the processed content as the HTTP response
        Write-PodeTextResponse -Value $content -ContentType $ContentType -StatusCode $StatusCode
        return
    }

    # this is a static file
    try {
        # load the file content
        $content = [System.IO.File]::ReadAllBytes($FileInfo.FullName)

        # Determine and set the content type for static files
        $ContentType = Protect-PodeValue -Value $ContentType -Default (Get-PodeContentType -Extension $mainExt)

        # Write the file content as the HTTP response
        Write-PodeTextResponse -Bytes $content -ContentType $ContentType -MaxAge $MaxAge -StatusCode $StatusCode -Cache:$Cache
        return
    }
    catch [System.UnauthorizedAccessException] {
        $statusCode = 401
    }
    catch {
        $statusCode = 400
    }

    # If the file does not exist, set the HTTP response status code appropriately
    Set-PodeResponseStatus -Code $StatusCode
}

<#
.SYNOPSIS
Serves a directory listing as a web page.

.DESCRIPTION
The Write-PodeDirectoryResponseInternal function generates an HTML response that lists the contents of a specified directory,
allowing for browsing of files and directories. It supports both Windows and Unix-like environments by adjusting the
display of file attributes accordingly. If the path is a directory, it generates a browsable HTML view; otherwise, it
serves the file directly.

.PARAMETER Path
The relative path to the directory that should be displayed. This path is resolved and used to generate a list of contents.

.PARAMETER FileInfo
A FileSystemInfo object to use instead of the path.

.PARAMETER NoEscape
If supplied, the path will not be escaped. This is useful for paths that contain expected wildcards, or are already escaped.

.EXAMPLE
# resolve for relative path
$RelativePath = Get-PodeRelativePath -Path './static' -JoinRoot
Write-PodeDirectoryResponseInternal -Path './static'

Generates and serves an HTML page that lists the contents of the './static' directory, allowing users to click through files and directories.

.NOTES
This is an internal function and may change in future releases of Pode.
#>
function Write-PodeDirectoryResponseInternal {
    [CmdletBinding(DefaultParameterSetName = 'Path')]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'Path')]
        [string]
        $Path,

        [Parameter(Mandatory = $true, ParameterSetName = 'DirectoryInfo')]
        [System.IO.DirectoryInfo]
        $DirectoryInfo,

        [switch]
        $NoEscape
    )

    # if we have no path, build it from the file info
    if ($null -ne $DirectoryInfo) {
        $Path = $DirectoryInfo.FullName.Replace($DirectoryInfo.PSDrive.Root.TrimEnd('\', '/'), "$($DirectoryInfo.PSDrive.Name):")
    }

    # escape the path
    else {
        $Path = Protect-PodePath -Path $Path -NoEscape:$NoEscape
        $DirectoryInfo = Get-Item -Path $Path -Force -ErrorAction Stop
    }

    # Attempt to retrieve information about the path
    if ($WebEvent.Path -eq '/') {
        $leaf = '/'
        $rootPath = [string]::Empty
    }
    else {
        # get leaf of current physical path, and set root path
        $leaf = ($Path.Split(':', 2)[1] -split '[\\/]+') -join '/'
        $rootPath = $WebEvent.Path -ireplace "$($leaf)$", ''
    }

    # Determine if the server is running in Windows mode or is running a version that support Linux
    # https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/get-childitem?view=powershell-7.4#example-10-output-for-non-windows-operating-systems
    $windowsMode = ((Test-PodeIsWindows) -or ($PSVersionTable.PSVersion -lt [version]'7.1.0'))

    # Construct the HTML content for the file browser view
    $htmlContent = [System.Text.StringBuilder]::new()

    $atoms = $WebEvent.Path -split '/'
    $atoms = @(foreach ($atom in $atoms) {
            if (![string]::IsNullOrEmpty($atom)) {
                [uri]::EscapeDataString($atom)
            }
        })

    if ([string]::IsNullOrEmpty($atoms)) {
        $baseLink = ''
    }
    else {
        $baseLink = "/$($atoms -join '/')"
    }

    # Handle navigation to the parent directory (..)
    if ($leaf -ne '/') {
        $LastSlash = $baseLink.LastIndexOf('/')
        if ($LastSlash -eq -1) {
            Set-PodeResponseStatus -Code 404
            return
        }

        $ParentLink = $baseLink.Substring(0, $LastSlash)
        if ([string]::IsNullOrEmpty($ParentLink)) {
            $ParentLink = '/'
        }

        $item = Get-Item -Path $DirectoryInfo.Parent.FullName -Force -ErrorAction Stop
        $null = $htmlContent.Append('<tr>')

        if ($windowsMode) {
            $null = $htmlContent.Append("<td class='mode'>$($item.Mode)</td>")
        }
        else {
            $null = $htmlContent.Append("<td class='unixMode'>$($item.UnixMode)</td>")
            $null = $htmlContent.Append("<td class='user'>$($item.User)</td>")
            $null = $htmlContent.Append("<td class='group'>$($item.Group)</td>")
        }

        $null = $htmlContent.Append("<td class='dateTime'>$($item.CreationTime.ToString('yyyy-MM-dd HH:mm:ss'))</td>")
        $null = $htmlContent.Append("<td class='dateTime'>$($item.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))</td>")
        $null = $htmlContent.Append("<td class='size'></td>")
        $null = $htmlContent.Append("<td class='icon'><span class='icon icon-folder'></span></td>")
        $null = $htmlContent.Append("<td class='name'><a href='$($ParentLink)'>..</a></td>")
        $null = $htmlContent.AppendLine('</tr>')
    }

    # Retrieve the child items of the specified directory
    $children = Get-ChildItem -Path $DirectoryInfo.FullName -Force -ErrorAction Stop

    foreach ($item in $children) {
        $link = "$baseLink/$([uri]::EscapeDataString($item.Name))"
        if ($item.PSIsContainer) {
            $size = ''
            $icon = 'folder'
        }
        else {
            $size = '{0:N2}KB' -f ($item.Length / 1KB)
            $icon = 'file'
        }

        # Format each item as an HTML row
        $null = $htmlContent.Append('<tr>')

        if ($windowsMode) {
            $null = $htmlContent.Append("<td class='mode'>$($item.Mode)</td>")
        }
        else {
            $null = $htmlContent.Append("<td class='unixMode'>$($item.UnixMode)</td>")
            $null = $htmlContent.Append("<td class='user'>$($item.User)</td>")
            $null = $htmlContent.Append("<td class='group'>$($item.Group)</td>")
        }

        $null = $htmlContent.Append("<td class='dateTime'>$($item.CreationTime.ToString('yyyy-MM-dd HH:mm:ss'))</td>")
        $null = $htmlContent.Append("<td class='dateTime'>$($item.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))</td>")
        $null = $htmlContent.Append("<td class='size'>$($size)</td>")
        $null = $htmlContent.Append("<td class='icon'><span class='icon icon-$($icon)'></span></td>")
        $null = $htmlContent.Append("<td class='name'><a href='$($link)'>$($item.Name)</a></td>")
        $null = $htmlContent.AppendLine('</tr>')
    }

    $Data = @{
        RootPath    = $RootPath
        Path        = $leaf.Replace('\', '/')
        WindowsMode = $windowsMode.ToString().ToLower()
        FileContent = $htmlContent.ToString() # Convert the StringBuilder content to a string
    }

    $podeRoot = Get-PodeModuleMiscPath

    # Write the response
    Write-PodeFileResponseInternal -Path ([System.IO.Path]::Combine($podeRoot, 'default-file-browsing.html.pode')) -Data $Data -NoEscape
}

<#
.SYNOPSIS
Sends a file as an attachment in the response, supporting both file streaming and directory browsing options.

.DESCRIPTION
The Write-PodeAttachmentResponseInternal function is designed to handle HTTP responses for file downloads or directory browsing within a Pode web server. It resolves the given file or directory path, sets the appropriate content type, and configures the response to either download the file as an attachment or list the directory contents if browsing is enabled. The function supports both PowerShell Core and Windows PowerShell environments for file content retrieval.

.PARAMETER Path
The path to the file or directory. This parameter is mandatory and accepts pipeline input. The function resolves relative paths based on the server's root directory.

.PARAMETER FileInfo
A FileSystemInfo object to use instead of the path.

.PARAMETER ContentType
The MIME type of the file being served. This is validated against a pattern to ensure it's in the format 'type/subtype'. If not specified, the function attempts to determine the content type based on the file extension.

.PARAMETER FileBrowser
A switch parameter that, when present, enables directory browsing. If the path points to a directory and this parameter is enabled, the function will list the directory's contents instead of returning a 404 error.

.PARAMETER NoEscape
If supplied, the path will not be escaped. This is useful for paths that contain expected wildcards, or are already escaped.

.EXAMPLE
Write-PodeAttachmentResponseInternal -Path './files/document.pdf' -ContentType 'application/pdf'

Serves the 'document.pdf' file with the 'application/pdf' MIME type as a downloadable attachment.

.EXAMPLE
Write-PodeAttachmentResponseInternal -Path './files' -FileBrowser

Lists the contents of the './files' directory if the FileBrowser switch is enabled; otherwise, returns a 404 error.

.NOTES
- This function integrates with Pode's internal handling of HTTP responses, leveraging other Pode-specific functions like Get-PodeContentType and Set-PodeResponseStatus. It differentiates between streamed and serverless environments to optimize file delivery.
- This is an internal function and may change in future releases of Pode.
#>
function Write-PodeAttachmentResponseInternal {
    [CmdletBinding(DefaultParameterSetName = 'Path')]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'Path')]
        [string]
        $Path,

        [Parameter(Mandatory = $true, ParameterSetName = 'FileInfo')]
        [System.IO.FileSystemInfo]
        $FileInfo,

        [Parameter()]
        [string]
        $ContentType,

        [Parameter()]
        [switch]
        $FileBrowser,

        [switch]
        $NoEscape
    )

    # if the file info isn't supplied, get it from the path
    if ($null -eq $FileInfo) {
        $Path = Protect-PodePath -Path $Path -NoEscape:$NoEscape
        $FileInfo = Test-PodePath -Path $Path -Force -ReturnItem -FailOnDirectory:(!$FileBrowser)
    }

    # if the file info is still null, return
    if ($null -eq $FileInfo) {
        return
    }

    # file browsing is enabled, use the directory response function
    if ($FileInfo.PSIsContainer) {
        Write-PodeDirectoryResponseInternal -DirectoryInfo $FileInfo
        return
    }

    # setup the content type and disposition
    if ([string]::IsNullOrEmpty($ContentType)) {
        $ContentType = Get-PodeContentType -Extension $FileInfo.Extension
    }

    $WebEvent.Response.ContentType = $ContentType
    Set-PodeHeader -Name 'Content-Disposition' -Value "attachment; filename=$($FileInfo.Name)"

    # if serverless, get the content raw and return
    if (!$WebEvent.Streamed) {
        $WebEvent.Response.Body = [System.IO.File]::ReadAllBytes($FileInfo.FullName)
        return
    }

    # else if normal, stream the content back
    $WebEvent.Response.SendChunked = $false

    # set file as an attachment on the response
    $WebEvent.Response.WriteFile($FileInfo)
}