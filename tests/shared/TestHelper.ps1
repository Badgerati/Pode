[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '')]
param()
<#
.SYNOPSIS
	Ensures the Pode assembly is loaded into the current session.

.DESCRIPTION
	This function checks if the Pode assembly is already loaded into the current PowerShell session.
	If not, it determines the appropriate .NET runtime version and attempts to load the Pode.dll
	from the most compatible directory. If no specific version is found, it defaults to netstandard2.0.

.PARAMETER SrcPath
	The base path where the Pode library (Libs folder) is located.

.EXAMPLE
	Import-PodeAssembly -SrcPath 'C:\Projects\MyApp'
	Ensures that Pode.dll is loaded from the appropriate .NET folder.

.NOTES
	Ensure that the Pode library path is correctly structured with folders named
	`netstandard2.0`, `net6.0`, etc., inside the `Libs` folder.
#>
function Import-PodeAssembly {
  param (
    [Parameter(Mandatory = $true)]
    [string]$SrcPath
  )

  # Check if Pode is already loaded
  if (!([AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.GetName().Name -eq 'Pode' })) {
    # Fetch the .NET runtime version
    $version = [System.Environment]::Version.Major
    $libsPath = Join-Path -Path $SrcPath -ChildPath 'Libs'

    # Filter .NET DLL folders based on version and get the latest one
    $netFolder = if (![string]::IsNullOrWhiteSpace($version)) {
      Get-ChildItem -Path $libsPath -Directory -Force |
        Where-Object { $_.Name -imatch "net[1-$($version)]" } |
        Sort-Object -Property Name -Descending |
        Select-Object -First 1 -ExpandProperty FullName
    }

    # Use netstandard2.0 if no folder found
    if ([string]::IsNullOrWhiteSpace($netFolder)) {
      $netFolder = Join-Path -Path $libsPath -ChildPath 'netstandard2.0'
    }

    # Append Pode.dll and mount
    Add-Type -LiteralPath (Join-Path -Path $netFolder -ChildPath 'Pode.dll') -ErrorAction Stop
  }
}


<#
.SYNOPSIS
  Compares two strings while normalizing line endings.

.DESCRIPTION
  This function trims both input strings and replaces all variations of line endings (`CRLF`, `LF`, `CR`) with a normalized `LF` (`\n`).
  It then compares the normalized strings for equality.

.PARAMETER InputString1
  The first string to compare.

.PARAMETER InputString2
  The second string to compare.

.OUTPUTS
  [bool]
  Returns `$true` if both strings are equal after normalization; otherwise, returns `$false`.

.EXAMPLE
  Compare-StringRnLn -InputString1 "Hello`r`nWorld" -InputString2 "Hello`nWorld"
  # Returns: $true

.EXAMPLE
  Compare-StringRnLn -InputString1 "Line1`r`nLine2" -InputString2 "Line1`rLine2"
  # Returns: $true

.NOTES
  This function ensures that strings with different line-ending formats are treated as equal if their content is otherwise identical.
#>
function Compare-StringRnLn {
  param (
    [string]$InputString1,
    [string]$InputString2
  )
  return ($InputString1.Trim() -replace "`r`n|`n|`r", "`n") -eq ($InputString2.Trim() -replace "`r`n|`n|`r", "`n")
}

<#
.SYNOPSIS
  Converts a PSCustomObject into an ordered hashtable.

.DESCRIPTION
  This function recursively converts a PSCustomObject, including nested objects and collections, into an ordered hashtable.
  It ensures that all properties are retained while maintaining their original structure.

.PARAMETER InputObject
  The PSCustomObject to be converted into an ordered hashtable.

.OUTPUTS
  [System.Collections.Specialized.OrderedDictionary]
  Returns an ordered hashtable representation of the input PSCustomObject.

.EXAMPLE
  $object = [PSCustomObject]@{ Name = "Pode"; Version = "2.0"; Config = [PSCustomObject]@{ Debug = $true } }
  Convert-PsCustomObjectToOrderedHashtable -InputObject $object
  # Returns: An ordered hashtable representation of $object.

.EXAMPLE
  $object = [PSCustomObject]@{ Users = @([PSCustomObject]@{ Name = "Alice" }, [PSCustomObject]@{ Name = "Bob" }) }
  Convert-PsCustomObjectToOrderedHashtable -InputObject $object
  # Returns: An ordered hashtable where 'Users' is an array of ordered hashtables.

.NOTES
  This function preserves key order and supports recursive conversion of nested objects and collections.
#>
function Convert-PsCustomObjectToOrderedHashtable {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
    [PSCustomObject]$InputObject
  )
  begin {
    # Define a recursive function within the process block
    function Convert-ObjectRecursively {
      param (
        [Parameter(Mandatory = $true)]
        [System.Object]
        $InputObject
      )

      # Initialize an ordered dictionary
      $orderedHashtable = [ordered]@{}

      # Loop through each property of the PSCustomObject
      foreach ($property in $InputObject.PSObject.Properties) {
        # Check if the property value is a PSCustomObject
        if ($property.Value -is [PSCustomObject]) {
          # Recursively convert the nested PSCustomObject
          $orderedHashtable[$property.Name] = Convert-ObjectRecursively -InputObject $property.Value
        }
        elseif ($property.Value -is [System.Collections.IEnumerable] -and -not ($property.Value -is [string])) {
          # If the value is a collection, check each element
          $convertedCollection = @()
          foreach ($item in $property.Value) {
            if ($item -is [PSCustomObject]) {
              $convertedCollection += Convert-ObjectRecursively -InputObject $item
            }
            else {
              $convertedCollection += $item
            }
          }
          $orderedHashtable[$property.Name] = $convertedCollection
        }
        else {
          # Add the property name and value to the ordered hashtable
          $orderedHashtable[$property.Name] = $property.Value
        }
      }

      # Return the resulting ordered hashtable
      return $orderedHashtable
    }
  }
  process {
    # Call the recursive helper function for each input object
    Convert-ObjectRecursively -InputObject $InputObject
  }
}

<#
.SYNOPSIS
  Compares two hashtables to determine if they are equal.

.DESCRIPTION
  This function recursively compares two hashtables, checking whether they contain the same keys and values.
  It also handles nested hashtables and arrays, ensuring deep comparison of all elements.

.PARAMETER Hashtable1
  The first hashtable to compare.

.PARAMETER Hashtable2
  The second hashtable to compare.

.OUTPUTS
  [bool]
  Returns `$true` if both hashtables are equal, otherwise returns `$false`.

.EXAMPLE
  $hash1 = @{ Name = "Pode"; Version = "2.0"; Config = @{ Debug = $true } }
  $hash2 = @{ Name = "Pode"; Version = "2.0"; Config = @{ Debug = $true } }
  Compare-Hashtable -Hashtable1 $hash1 -Hashtable2 $hash2
  # Returns: $true

.EXAMPLE
  $hash1 = @{ Name = "Pode"; Version = "2.0" }
  $hash2 = @{ Name = "Pode"; Version = "2.1" }
  Compare-Hashtable -Hashtable1 $hash1 -Hashtable2 $hash2
  # Returns: $false

#>
function Compare-Hashtable {
  param (
    [object]$Hashtable1,
    [object]$Hashtable2
  )

  # Function to compare two hashtable values
  function Compare-Value($value1, $value2) {
    # Check if both values are hashtables
    if ((($value1 -is [hashtable] -or $value1 -is [System.Collections.Specialized.OrderedDictionary]) -and
    ($value2 -is [hashtable] -or $value2 -is [System.Collections.Specialized.OrderedDictionary]))) {
      return Compare-Hashtable -Hashtable1 $value1 -Hashtable2 $value2
    }
    # Check if both values are arrays
    elseif (($value1 -is [Object[]]) -and ($value2 -is [Object[]])) {
      if ($value1.Count -ne $value2.Count) {
        return $false
      }
      for ($i = 0; $i -lt $value1.Count; $i++) {
        $found = $false
        for ($j = 0; $j -lt $value2.Count; $j++) {
          if ( Compare-Value $value1[$i] $value2[$j]) {
            $found = $true
          }
        }
        if ($found -eq $false) {
          return $false
        }
      }
      return $true
    }
    else {
      if ($value1 -is [string] -and $value2 -is [string]) {
        return  Compare-StringRnLn $value1 $value2
      }
      # Check if the values are equal
      return $value1 -eq $value2
    }
  }

  $keys1 = $Hashtable1.Keys
  $keys2 = $Hashtable2.Keys

  # Check if both hashtables have the same keys
  if ($keys1.Count -ne $keys2.Count) {
    return $false
  }

  foreach ($key in $keys1) {
    if (! ($Hashtable2.Keys -contains $key)) {
      return $false
    }

    if ($Hashtable2[$key] -is [hashtable] -or $Hashtable2[$key] -is [System.Collections.Specialized.OrderedDictionary]) {
      if (! (Compare-Hashtable -Hashtable1 $Hashtable1[$key] -Hashtable2 $Hashtable2[$key])) {
        return $false
      }
    }
    elseif (!(Compare-Value $Hashtable1[$key] $Hashtable2[$key])) {
      return $false
    }
  }

  return $true
}


<#
.SYNOPSIS
  Waits for a web server to become available at a specified URI or port.

.DESCRIPTION
  This function continuously checks if a web server is online by sending an HTTP request.
  It retries until the server responds with a 200 status code or a timeout is reached.

.PARAMETER Uri
  The full URI to check (e.g., "http://127.0.0.1:5000"). If not provided, defaults to "http://localhost:$Port".

.PARAMETER Port
  The port on which the web server is expected to be available. If no URI is provided, the function constructs a default URI using "http://localhost:$Port".

.PARAMETER Timeout
  The maximum number of seconds to wait before timing out. Default is 60 seconds.

.PARAMETER Interval
  The number of seconds to wait between retries. Default is 2 seconds.

.OUTPUTS
  Boolean - Returns $true if the server is online, otherwise $false.

.EXAMPLE
  Wait-ForWebServer -Port 8080 -Timeout 30 -Interval 2

  Waits up to 30 seconds for the web server on port 8080 to come online.

.EXAMPLE
  Wait-ForWebServer -Uri "http://127.0.0.1:5000" -Timeout 45

  Waits up to 45 seconds for the web server at "http://127.0.0.1:5000" to respond.

#>
function Wait-ForWebServer {
  [CmdletBinding(DefaultParameterSetName = 'localhost')]
  [OutputType([bool])]
  param (
    [Parameter(Mandatory = $true, ParameterSetName = 'Uri' )]
    [string]$Uri,

    [Parameter(ParameterSetName = 'localhost' )]
    [ValidateSet('http', 'https')]
    [string]$Protocol = 'http',

    [Parameter(ParameterSetName = 'localhost' )]
    [int]$Port,

    [Parameter()]
    [int]$Timeout = 60,

    [Parameter()]
    [int]$Interval = 2,

    [Parameter()]
    [switch]$Offline
  )

  # Determine the final URI: If no URI is provided, use "http://localhost:$Port"
  if (-not $Uri) {
    if ($Port -gt 0) {
      $Uri = "$($Protocol)://localhost:$Port"
    }
    else {
      $Uri = "$($Protocol)://localhost"
    }
  }

  $MaxRetries = [math]::Ceiling($Timeout / $Interval)
  $RetryCount = 0

  while ($RetryCount -lt $MaxRetries) {
    try {
      # Use curl to check server status
      if ($PSEdition -eq 'Desktop' -or $IsWindows) {
        $curlCmd = 'curl.exe'
        $outputArg = 'NUL'
      }
      else {
        $curlCmd = 'curl'
        $outputArg = '/dev/null'
      }
      # Suppress curl error output when server is offline
      $statusCode = & $curlCmd --silent --show-error --output $outputArg --write-out '%{http_code}' --max-time 3 --insecure --url $Uri 2>$null
      if ($statusCode -eq '000') { throw 'curl failed to connect' }
      if ($Offline) {
        $RetryCount++
        Write-Host "Webserver is expected to be offline, but it is online at $Uri... (Attempt $($RetryCount)/$MaxRetries)"
        continue
      }
      elseif ($statusCode -eq '200' -or $statusCode -eq '404') {
        Write-Host "Webserver is online at $Uri (HTTP $statusCode)"
        return $true
      }
    }
    catch {
      if ($Offline) {
        return $true
      }
      Write-Host "Waiting for webserver to come online at $Uri... (Attempt $($RetryCount+1)/$MaxRetries)"
    }
    Start-Sleep -Seconds $Interval
    $RetryCount++
  }
  return $false
}

<#
.SYNOPSIS
    Retrieves Server-Sent Events (SSE) from a target server.

.DESCRIPTION
    The `Get-SseEvent` function connects to a server's SSE endpoint and streams incoming events.
    It first queries a metadata endpoint (default = `/sse`) to discover the actual SSE stream URL.
    Then it opens an HTTP/1.1 stream to avoid known flush issues with HTTP/2 and reads
    event frames from the stream, returning them as an array of objects.

.PARAMETER BaseUrl
    The base URL of the server hosting the SSE endpoint.
    Example: 'http://localhost:8080'

.PARAMETER MetaEndpoint
    The relative endpoint used to discover the SSE URL.
    Defaults to '/sse'.

.PARAMETER TimeoutSeconds
    The timeout (in seconds) for the initial HTTP request to the server.
    Default is 150 seconds. (Note: The stream itself uses an extended timeout internally.)

.OUTPUTS
    [pscustomobject[]]
    An array of objects with properties:
    - Event: the event name (default is 'message')
    - Data:  the event payload

.EXAMPLE
    $events = Get-SseEvent -BaseUrl 'http://localhost:8080'

.EXAMPLE
    $events = Get-SseEvent -BaseUrl 'http://localhost:8080' -MetaEndpoint '/my_custom_sse'

.NOTES
    This function uses HttpClient and requires .NET 5+ / PowerShell 7+ for full compatibility.
    For internal or test use; not intended as a fully resilient production SSE client.

#>
function Get-SseEvent {
  param(
    [string]$BaseUrl,
    [string]$MetaEndpoint = '/sse',
    [int] $TimeoutSeconds = 150
  )
  # 1. One client, shared cookies
  $handler = [System.Net.Http.HttpClientHandler]::new()
  $handler.UseCookies = $true
  $handler.CookieContainer = [System.Net.CookieContainer]::new()
  $client = [System.Net.Http.HttpClient]::new($handler)
  $client.Timeout = [timespan]::FromMinutes(10)      # infinite-ish

  # 2. Discover stream URL  (GET /sse returns  { Sse = @{ Url = '/sse_events' } })
  $meta = $client.GetStringAsync("$BaseUrl$MetaEndpoint").Result | ConvertFrom-Json
  $sseUri = $meta.Sse.Url
  if ([System.Uri]::IsWellFormedUriString( $meta.Sse.Url, 'Absolute')) {
    $sseUri = $meta.Sse.Url
  }
  else {
    # Ensure the base ends with a slash, then combine
    $base = if ($BaseUrl.EndsWith('/')) { $BaseUrl } else { "$BaseUrl/" }
    $sseUri = [System.Uri]::new($base + $meta.Sse.Url.TrimStart('/'))
  }


  # 3. Open the stream (HTTP/1.1 avoids rare HTTP/2 flush issues)
  $req = [System.Net.Http.HttpRequestMessage]::new('GET', $sseUri)
  $req.Version = [Version]::new(1, 1)
  $req.VersionPolicy = [System.Net.Http.HttpVersionPolicy]::RequestVersionExact
  $req.Headers.Accept.Add([System.Net.Http.Headers.MediaTypeWithQualityHeaderValue]::new('text/event-stream'))
  $resp = $client.SendAsync($req, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).Result
  $reader = [System.IO.StreamReader]::new($resp.Content.ReadAsStreamAsync().Result)

  # 4. Parse frames (default = "message")
  $events = @()
  while ($true) {
    $line = $reader.ReadLine(); if ($null -eq $line) { break }
    if ($line -eq '') {
      if ($evtData) {
        $events += [pscustomobject]@{Event = $evtName; Data = $evtData }
        $evtName = 'message'; $evtData = ''
      }
      continue
    }
    if ($line.StartsWith('event:')) { $evtName = $line.Substring(6).Trim() }
    elseif ($line.StartsWith('data:')) {
      if ($evtData) {
        $evtData += "`n"
      }
      $evtData += $line.Substring(5).Trim()
    }
  }

  return $events
}


# Quickly create a file of the desired size.
# For binary we simply SetLength() – instant, sparse-file friendly.
# For text we write a 1 KiB ASCII buffer repeatedly so the file is 100 % printable.
function New-TestFile {
  param(
    [string]$Path,
    [long]  $SizeBytes,
    [ValidateSet('Text', 'Binary')]$Kind
  )

  if (Test-Path -Path $Path -PathType Leaf) { Remove-Item $Path -Force }

  $fs = [System.IO.File]::Open($Path, 'CreateNew')
  try {
    switch ($Kind) {
      'Binary' { $fs.SetLength($SizeBytes) }
      'Text' {
        $chunkSz = 8KB
        $chunk = [byte[]]::new($chunkSz)
        $rand = [System.Random]::new()

        for ($i = 0; $i -lt $chunkSz - 1; $i++) {
          $chunk[$i] = [byte]($rand.Next(32, 127))   # any printable char
        }
        $chunk[$chunkSz - 1] = 0x0A                    # newline

        # Pre-allocate to avoid fragmentation, then overwrite with data
        $fs.SetLength($SizeBytes)
        $fs.Position = 0

        $remaining = $SizeBytes
        while ($remaining -gt 0) {
          $toWrite = [long][System.Math]::Min([long]$chunkSz, $remaining)
          $fs.Write($chunk, 0, [int]$toWrite)        # Stream.Write wants Int32
          $remaining -= $toWrite
        }
      }
    }
  }
  finally { $fs.Dispose() }
}


<#
.SYNOPSIS
  Minimal, curl-backed replacement for Invoke-WebRequest that can
  stream very large responses (≫2 GB) on Windows, Linux, and macOS.
  Now supports range-based downloads for very large files.

.PARAMETER Uri
  URL to fetch.

.PARAMETER OutFile
  Path where the response body should be written.
  If omitted the body is buffered into the returned object
  (fine for your text tests, but skip this for multi-GB payloads).

.PARAMETER Headers
  Hashtable of request headers.

.PARAMETER PassThru
  Return a response object instead of being silent.

.PARAMETER UseRangeDownload
  Use range-based downloading for large files. Automatically detects file size
  and downloads in chunks, then joins them together.

.PARAMETER RangeSize
  Size of each range chunk when UseRangeDownload is enabled. Default is 1GB.

.PARAMETER DownloadDir
  Directory for temporary part files when using range downloads.
  If not specified, uses the OutFile directory or a temporary directory.

.PARAMETER ETag
  ETag value to use for conditional requests. If provided, the request will include
  an `If-None-Match` header with this value.

.PARAMETER IfModifiedSince
  DateTime value for the `If-Modified-Since` header.
  If provided, the request will include this header to check for modifications.
#>
function Invoke-CurlRequest {

  [CmdletBinding(DefaultParameterSetName = 'Default')]
  param(
    [Parameter(Mandatory, Position = 0)]
    [string]
    $Url,

    [Parameter()]
    [string]
    $OutFile,

    [Parameter()]
    [hashtable]
    $Headers,

    [Parameter()]
    [switch]
    $PassThru,

    [Parameter()]
    [string]
    $DownloadDir,

    [Parameter(ParameterSetName = 'Default')]
    [Parameter(ParameterSetName = 'Etag')]
    [Parameter(ParameterSetName = 'IfModifiedSince')]
    [ValidateSet('gzip', 'deflate', 'br')]
    [string]
    $AcceptEncoding,

    [Parameter(Mandatory = $true, ParameterSetName = 'RangeDownload')]
    [switch]
    $UseRangeDownload,

    [Parameter( ParameterSetName = 'RangeDownload')]
    [long]
    $RangeSize = 1GB,

    [Parameter(Mandatory = $true, ParameterSetName = 'Etag')]
    [string]
    $ETag,

    [Parameter(Mandatory = $true, ParameterSetName = 'IfModifiedSince')]
    [datetime]
    $IfModifiedSince
  )

  # ------------------------------------------------------------
  # Handle range downloads
  # ------------------------------------------------------------
  if ($UseRangeDownload) {
    # Locate the real curl binary (cross-platform, bypass alias)
    if ($PSEdition -eq 'Desktop' -or $IsWindows) { $curlCmd = 'curl.exe' } else { $curlCmd = 'curl' }

    # First get the content length with a HEAD request
    $tmpHdr = [IO.Path]::GetTempFileName()
    $headArgs = @(
      '--silent', '--show-error',
      '--location',
      '--head', # HEAD request only
      '--dump-header', $tmpHdr,
      '--write-out', '%{http_code}',
      '--url', $Url
    )

    $statusLine = & $curlCmd @headArgs
    if ($LASTEXITCODE) {
      throw "curl HEAD request failed with code $LASTEXITCODE"
    }

    # Parse headers from HEAD response
    $hdrHash = @{}
    foreach ($line in Get-Content $tmpHdr) {
      if ([string]::IsNullOrWhiteSpace($line)) { continue }
      if ($line -match '^(?<k>[^:]+):\s*(?<v>.+)$') {
        $hdrHash[$matches.k.Trim()] = $matches.v.Trim()
      }
    }
    Remove-Item $tmpHdr -Force

    if (-not $hdrHash.ContainsKey('Content-Length')) {
      throw 'Server does not provide Content-Length header, cannot use range downloads'
    }

    $length = [int64]$hdrHash['Content-Length']
    if (-not $DownloadDir) {
      if ($OutFile) {
        $DownloadDir = Split-Path -Path $OutFile -Parent
      }
      else {
        $DownloadDir = [IO.Path]::GetTempPath()
      }
    }

    # Create download directory if it doesn't exist
    if (-not (Test-Path -Path $DownloadDir)) {
      New-Item -Path $DownloadDir -ItemType Directory -Force | Out-Null
    }

    # Calculate parts and download each range
    $parts = 0..[math]::Floor(($length - 1) / $RangeSize) | ForEach-Object {
      $start = $_ * $RangeSize
      $end = [math]::Min($length - 1, $start + $RangeSize - 1)
      $part = Join-Path -Path $DownloadDir -ChildPath "part$_.bin"

      # Download this range using curl directly (avoid recursion)
      $rangeArgs = @(
        '--silent', '--show-error',
        '--location',
        '--output', $part,
        '-H', "Range: bytes=$start-$end",
        '--url', $Url
      )

      # Add any additional headers
      if ($Headers) {
        foreach ($k in $Headers.Keys) {
          $rangeArgs += @('-H', "$($k): $($Headers[$k])")
        }
      }

      & $curlCmd @rangeArgs
      if ($LASTEXITCODE) {
        throw "curl range request failed with code $LASTEXITCODE"
      }
      $part
    }

    # Join all parts into final file
    $joined = if ($OutFile) { $OutFile } else { Join-Path -Path $DownloadDir -ChildPath 'joined.tmp' }
    $out = [System.IO.File]::Create($joined)
    try {
      foreach ($p in $parts) {
        $bytes = [System.IO.File]::ReadAllBytes($p)
        $out.Write($bytes, 0, $bytes.Length)
        Remove-Item $p -Force
      }
    }
    finally {
      $out.Dispose()
    }

    if ($PassThru) {
      return [PSCustomObject]@{
        StatusCode = 200
        Headers    = $hdrHash
        OutFile    = $joined
      }
    }
    return
  }

  # ------------------------------------------------------------
  # Normal (non-range) download logic
  # ------------------------------------------------------------

  # Locate the real curl binary (cross-platform, bypass alias)
  if ($PSEdition -eq 'Desktop' -or $IsWindows) { $curlCmd = 'curl.exe' } else { $curlCmd = 'curl' }
  # ------------------------------------------------------------
  # Prep temporary files
  # ------------------------------------------------------------
  $tmpHdr = [IO.Path]::GetTempFileName()
  $tmpBody = if ($OutFile) { $OutFile } else { [IO.Path]::GetTempFileName() }

  # ------------------------------------------------------------
  # Build argument list
  # ------------------------------------------------------------
  $arguments = @(
    '--silent', '--show-error', # quiet transfer, still show errors
    '--location', # follow 3xx
    '--dump-header', $tmpHdr, # capture headers
    '--output', $tmpBody, # stream body
    '--write-out', '%{http_code}'    # print status at the end
  )

  if ($AcceptEncoding) {
    if ($null -eq $Headers) {
      $Headers = @{}
    }
    $Headers['Accept-Encoding'] = $AcceptEncoding
    $arguments += @('--compressed')  # curl will handle Accept-Encoding
  }

  # if Etag header is set, we will add it to the request.
  # This is used for conditional requests.
  if ($ETag) {
    if ($PSEdition -eq 'Desktop' ) {
      $arguments += @('-H', "If-None-Match: ""$ETag""")
    }
    else {
      $arguments += @('-H', "If-None-Match: $ETag")
    }
  }

  # IfModifiedSince header
  # If the header is not set, we will not add it to the request.
  if ($IfModifiedSince) {
    $arguments += @('-H', "If-Modified-Since: $($IfModifiedSince.ToString('R'))")
  }

  # Add any additional headers
  if ($Headers) {
    foreach ($k in $Headers.Keys) {
      $arguments += @('-H', ('{0}: {1}' -f $k, $Headers[$k]))
    }
  }

  $arguments += '--url', $Url

  # ------------------------------------------------------------
  # Run curl
  # ------------------------------------------------------------
  if ($PSEdition -eq 'Desktop') {
    $statusLine = cmd /c $curlCmd @arguments
  }
  else {
    $statusLine = & $curlCmd @arguments
  }
  if ($LASTEXITCODE) {
    throw "curl exited with code $LASTEXITCODE"
  }
  $statusCode = [int]$statusLine

  # ------------------------------------------------------------
  # Parse headers
  # ------------------------------------------------------------
  $hdrHash = @{}
  foreach ($line in Get-Content $tmpHdr) {
    if ([string]::IsNullOrWhiteSpace($line)) { break }
    if ($line -match '^(?<k>[^:]+):\s*(?<v>.+)$') {
      $hdrHash[$matches.k.Trim()] = $matches.v.Trim()
    }
  }

  # Clean up temporary header file
  Remove-Item $tmpHdr -Force

  # ------------------------------------------------------------
  # Build response object (if requested)
  # ------------------------------------------------------------
  if ($PassThru) {
    $raw = if (-not $OutFile) { [IO.File]::ReadAllBytes($tmpBody) }
    $content = if ($raw) { [Text.Encoding]::UTF8.GetString($raw) }

    [PSCustomObject]@{
      StatusCode = $statusCode
      Headers    = $hdrHash
      RawContent = $raw
      Content    = $content
    }
  }

  # Clean up temporary body file if we created one
  if (-not $OutFile -and -not $PassThru) {
    Remove-Item $tmpBody -Force
  }

}
