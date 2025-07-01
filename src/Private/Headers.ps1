
function ConvertFrom-PodeHeaderQValue {
    param(
        [Parameter()]
        [string]
        $Value
    )

    process {
        $qs = [ordered]@{}

        # return if no value
        if ([string]::IsNullOrWhiteSpace($Value)) {
            return $qs
        }

        # split the values up
        $parts = @($Value -isplit ',').Trim()

        # go through each part and check its q-value
        foreach ($part in $parts) {
            # default of 1 if no q-value
            if ($part.IndexOf(';q=') -eq -1) {
                $qs[$part] = 1.0
                continue
            }

            # parse for q-value
            $atoms = @($part -isplit ';q=')
            $qs[$atoms[0]] = [double]$atoms[1]
        }

        return $qs
    }
}


<#
.SYNOPSIS
    Resolves the most appropriate compression encoding for a Pode route based on Accept-Encoding or Content-Encoding headers.

.DESCRIPTION
    This function determines the best compression encoding to use for a given route by evaluating the Accept-Encoding or Content-Encoding HTTP headers.
    It supports quality (q) values and prioritizes encodings based on client preference and route configuration.
    If no suitable encoding is found, it can optionally throw an HTTP 406 error.

.PARAMETER Route
    The route hashtable containing compression configuration.

.PARAMETER AcceptEncoding
    The Accept-Encoding header value from the client request. Used to negotiate response compression.

.PARAMETER ContentEncoding
    The Content-Encoding header value from the client request. Used to negotiate request decompression.

.PARAMETER ThrowError
    If specified, throws an HTTP 406 error when no acceptable encoding is found.

.OUTPUTS
    System.String
    Returns the resolved encoding name as a string, or an empty string if no encoding is selected.

.EXAMPLE
    Resolve-PodeCompressionEncoding -AcceptEncoding 'gzip,deflate' -Route $Route

.EXAMPLE
    Resolve-PodeCompressionEncoding -ContentEncoding 'gzip' -Route $Route

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function Resolve-PodeCompressionEncoding {
    [CmdletBinding(DefaultParameterSetName = 'AcceptEncoding')]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [Hashtable]
        $Route,

        [Parameter(mandatory = $true, ParameterSetName = 'AcceptEncoding')]
        [allowemptystring()]
        [string]
        $AcceptEncoding,

        [Parameter(mandatory = $true, ParameterSetName = 'ContentEncoding')]
        [allowemptystring()]
        [String]
        $ContentEncoding,

        [switch]
        $ThrowError
    )
    # return empty if compression is not enabled
    if (!$Route.Compression.Enabled -or $Route.Compression.Encodings.Count -eq 0) {
        return [string]::Empty
    }

    if ($PSCmdlet.ParameterSetName -ieq 'ContentEncoding') {

        if ([string]::IsNullOrWhiteSpace($ContentEncoding) -or !$Route.Compression.Request) {
            return [string]::Empty
        }
        # convert encoding form q-form
        $encodings = ConvertFrom-PodeHeaderQValue -Value $ContentEncoding
    }
    elseif ($PSCmdlet.ParameterSetName -ieq 'AcceptEncoding') {
        if ([string]::IsNullOrWhiteSpace($AcceptEncoding) -or !$Route.Compression.Response) {
            return [string]::Empty
        }
        # convert encoding form q-form
        $encodings = ConvertFrom-PodeHeaderQValue -Value $AcceptEncoding
    }

    if ($encodings.Count -eq 0) {
        return [string]::Empty
    }

    # check the encodings for one that matches
    $normal = @('identity', '*')
    $valid = @()

    # build up supported and invalid
    foreach ($encoding in $encodings.Keys) {
        if (($encoding -iin $Route.Compression.Encodings) -or ($encoding -iin $normal)) {
            $valid += @{
                Name  = $encoding
                Value = $encodings[$encoding]
            }
        }
    }

    # if it's empty, just return empty
    if ($valid.Length -eq 0) {
        return [string]::Empty
    }

    # find the highest ranked match
    $found = @{}
    $failOnIdentity = $false

    foreach ($encoding in $valid) {
        if ($encoding.Value -gt $found.Value) {
            $found = $encoding
        }

        if (!$failOnIdentity -and ($encoding.Value -eq 0) -and ($encoding.Name -iin $normal)) {
            $failOnIdentity = $true
        }
    }

    # force found to identity/* if the 0 is not identity - meaning it's still allowed
    if (($found.Value -eq 0) -and !$failOnIdentity) {
        $found = @{
            Name  = 'identity'
            Value = 1.0
        }
    }

    # return invalid, error, or return empty for idenity?
    if ($found.Value -eq 0) {
        if ($ThrowError) {
            throw (New-PodeRequestException -StatusCode 406)
        }
    }

    # else, we're safe
    if ($found.Name -iin $normal) {
        return [string]::Empty
    }

    if ($found.Name -ieq 'x-gzip') {
        return 'gzip'
    }

    return $found.Name
}



<#
.SYNOPSIS
    Parses a range string and converts it into a hashtable array of start and end values.

.DESCRIPTION
    This function takes a range string (typically used in HTTP headers) and extracts the relevant start and end values. It supports the 'bytes' unit and handles multiple ranges separated by commas.

.PARAMETER Range
    The range string to parse.

.PARAMETER ThrowError
    A switch parameter. If specified, the function throws an exception (HTTP status code 416) when encountering invalid range formats.

.OUTPUTS
    An array of hashtables, each containing 'Start' and 'End' properties representing the parsed ranges.

.EXAMPLE
    Get-PodeRange -Range 'bytes=100-200,300-400'
    # Returns an array of hashtables:
    # [
    #     @{
    #         Start = 100
    #         End   = 200
    #     },
    #     @{
    #         Start = 300
    #         End   = 400
    #     }
    # ]

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function Get-PodeRange {
    [CmdletBinding()]
    [OutputType([long[]])]
    param(
        [Parameter()]
        [string]
        $Range,

        [switch]
        $ThrowError
    )

    # return if no ranges
    if ([string]::IsNullOrWhiteSpace($Range)) {
        return $null
    }

    # split on '='
    $parts = @($Range -isplit '=').Trim()
    if (($parts.Length -le 1) -or ([string]::IsNullOrWhiteSpace($parts[1]))) {
        return $null
    }

    $unit = $parts[0]
    if ($unit -ine 'bytes') {
        if ($ThrowError) {
            throw (New-PodeRequestException -StatusCode 416)
        }

        return $null
    }

    # split on ','
    $parts = @($parts[1] -isplit ',').Trim()

    # parse into From-To hashtable array
    $ranges = [long[]]@()

    foreach ($atom in $parts) {
        if ($atom -inotmatch '(?<start>[\d]+){0,1}\s?\-\s?(?<end>[\d]+){0,1}') {
            if ($ThrowError) {
                throw (New-PodeRequestException -StatusCode 416)
            }

            return $null
        }
        $ranges += [long]$Matches['start']
        $ranges += [long]$Matches['end']


    }

    return $ranges
}

function Get-PodeTransferEncoding {
    param(
        [Parameter()]
        [string]
        $TransferEncoding,

        [switch]
        $ThrowError
    )

    # return if no encoding
    if ([string]::IsNullOrWhiteSpace($TransferEncoding)) {
        return [string]::Empty
    }

    # convert encoding form q-form
    $encodings = ConvertFrom-PodeHeaderQValue -Value $TransferEncoding
    if ($encodings.Count -eq 0) {
        return [string]::Empty
    }

    # check the encodings for one that matches
    $normal = @('chunked', 'identity')
    $invalid = @()

    # if we see a supported one, return immediately. else build up invalid one
    foreach ($encoding in $encodings.Keys) {
        if ($encoding -iin $PodeContext.Server.Web.Compression.Encodings) {
            if ($encoding -ieq 'x-gzip') {
                return 'gzip'
            }

            return $encoding
        }

        if ($encoding -iin $normal) {
            continue
        }

        $invalid += $encoding
    }

    # if we have any invalid, throw a 415 error
    if ($invalid.Length -gt 0) {
        if ($ThrowError) {
            throw (New-PodeRequestException -StatusCode 415)
        }

        return $invalid[0]
    }

    # else, we're safe
    return [string]::Empty
}

<#
.SYNOPSIS
    Extracts the base MIME type from a Content-Type string that may include additional parameters.

.DESCRIPTION
    This function takes a Content-Type string as input and returns only the base MIME type by splitting the string at the semicolon (';') and trimming any excess whitespace.
    It is useful for handling HTTP headers or other contexts where Content-Type strings include parameters like charset, boundary, etc.

.PARAMETER ContentType
    The Content-Type string from which to extract the base MIME type. This string can include additional parameters separated by semicolons.

.EXAMPLE
    Split-PodeContentType -ContentType "text/html; charset=UTF-8"

    This example returns 'text/html', stripping away the 'charset=UTF-8' parameter.

.EXAMPLE
    Split-PodeContentType -ContentType "application/json; charset=utf-8"

    This example returns 'application/json', removing the charset parameter.
#>
function Split-PodeContentType {
    param(
        [Parameter()]
        [string]
        $ContentType
    )

    # Check if the input string is null, empty, or consists only of whitespace.
    if ([string]::IsNullOrWhiteSpace($ContentType)) {
        return [string]::Empty  # Return an empty string if the input is not valid.
    }

    # Split the Content-Type string by the semicolon, which separates the base MIME type from other parameters.
    # Trim any leading or trailing whitespace from the resulting MIME type to ensure clean output.
    return @($ContentType -isplit ';')[0].Trim()
}