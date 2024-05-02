function Read-PodeStreamToEnd {
    param(
        [Parameter()]
        $Stream,

        [Parameter()]
        $Encoding = [System.Text.Encoding]::UTF8
    )

    if ($null -eq $Stream) {
        return [string]::Empty
    }

    return (Use-PodeStream -Stream ([System.IO.StreamReader]::new($Stream, $Encoding)) {
            return $args[0].ReadToEnd()
        })
}

function Read-PodeByteLineFromByteArray {
    param(
        [Parameter(Mandatory = $true)]
        [byte[]]
        $Bytes,

        [Parameter()]
        $Encoding = [System.Text.Encoding]::UTF8,

        [Parameter()]
        [int]
        $StartIndex = 0,

        [switch]
        $IncludeNewLine
    )

    $nlBytes = Get-PodeNewLineByte -Encoding $Encoding

    # attempt to find \n
    $index = [array]::IndexOf($Bytes, $nlBytes.NewLine, $StartIndex)
    $fIndex = $index

    # if not including new line, remove any trailing \r and \n
    if (!$IncludeNewLine) {
        $fIndex--

        if ($Bytes[$fIndex] -eq $nlBytes.Return) {
            $fIndex--
        }
    }

    # grab the portion of the bytes array - which is our line
    return @{
        Bytes      = $Bytes[$StartIndex..$fIndex]
        StartIndex = $StartIndex
        EndIndex   = $index
    }
}

function Get-PodeByteLinesFromByteArray {
    param(
        [Parameter(Mandatory = $true)]
        [byte[]]
        $Bytes,

        [Parameter()]
        $Encoding = [System.Text.Encoding]::UTF8,

        [switch]
        $IncludeNewLine
    )

    # lines
    $lines = @()
    $nlBytes = Get-PodeNewLineByte -Encoding $Encoding

    # attempt to find \n
    $index = 0
    while (($nextIndex = [array]::IndexOf($Bytes, $nlBytes.NewLine, $index)) -gt 0) {
        $fIndex = $nextIndex

        # if not including new line, remove any trailing \r and \n
        if (!$IncludeNewLine) {
            $fIndex--
            if ($Bytes[$fIndex] -eq $nlBytes.Return) {
                $fIndex--
            }
        }

        # add the line, and get the next one
        $lines += , $Bytes[$index..$fIndex]
        $index = $nextIndex + 1
    }

    return $lines
}
<#
.SYNOPSIS
    Converts a stream to a byte array.

.DESCRIPTION
    The `ConvertFrom-PodeStreamToByte` function reads data from a stream and converts it to a byte array.
    It's useful for scenarios where you need to work with binary data from a stream.

.PARAMETER Stream
    Specifies the input stream to convert. This parameter is mandatory.

.OUTPUTS
    Returns a byte array containing the data read from the input stream.

.EXAMPLE
    # Example usage:
    # Read data from a file stream and convert it to a byte array
    $stream = [System.IO.File]::OpenRead("C:\path\to\file.bin")
    $byteArray = ConvertFrom-PodeStreamToByte -Stream $stream
    $stream.Close()

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function ConvertFrom-PodeStreamToByte {
    param(
        [Parameter(Mandatory = $true)]
        $Stream
    )

    # Initialize a buffer to read data in chunks
    $buffer = [byte[]]::new(64 * 1024)
    $ms = New-Object -TypeName System.IO.MemoryStream
    $read = 0

    # Read data from the stream and write it to the memory stream
    while (($read = $Stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
        $ms.Write($buffer, 0, $read)
    }

    # Close the memory stream and return the byte array
    $ms.Close()
    return $ms.ToArray()
}
<#
.SYNOPSIS
    Converts a string value to a byte array using the specified encoding.

.DESCRIPTION
    The `ConvertFrom-PodeValueToByte` function takes a string value and converts it to a byte array.
    You can specify the desired encoding (default is UTF-8).

.PARAMETER Value
    Specifies the input string value to convert.

.PARAMETER Encoding
    Specifies the encoding to use when converting the string to bytes.
    Default value is UTF-8.

.OUTPUTS
    Returns a byte array containing the encoded representation of the input string.

.EXAMPLE
    # Example usage:
    $inputString = "Hello, world!"
    $byteArray = ConvertFrom-PodeValueToByte -Value $inputString
    # Now you can work with the byte array as needed.

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function ConvertFrom-PodeValueToByte {
    param(
        [Parameter()]
        [string]
        $Value,

        [Parameter()]
        $Encoding = [System.Text.Encoding]::UTF8
    )

    return $Encoding.GetBytes($Value)
}

function ConvertFrom-PodeValueToByte {
    param(
        [Parameter()]
        [string]
        $Value,

        [Parameter()]
        $Encoding = [System.Text.Encoding]::UTF8
    )

    return $Encoding.GetBytes($Value)
}

function ConvertFrom-PodeBytesToString {
    param(
        [Parameter()]
        [byte[]]
        $Bytes,

        [Parameter()]
        $Encoding = [System.Text.Encoding]::UTF8,

        [switch]
        $RemoveNewLine
    )

    if (($null -eq $Bytes) -or ($Bytes.Length -eq 0)) {
        return $Bytes
    }

    $value = $Encoding.GetString($Bytes)
    if ($RemoveNewLine) {
        $value = $value.Trim("`r`n")
    }

    return $value
}

<#
.SYNOPSIS
    Retrieves information about newline characters in different encodings.

.DESCRIPTION
    The `Get-PodeNewLineByte` function returns a hashtable containing information about newline characters.
    It calculates the byte values for newline (`n`) and carriage return (`r`) based on the specified encoding (default is UTF-8).

.PARAMETER Encoding
    Specifies the encoding to use when calculating newline and carriage return byte values.
    Default value is UTF-8.

.OUTPUTS
    Returns a hashtable with the following keys:
    - `NewLine`: Byte value for newline character (`n`).
    - `Return`: Byte value for carriage return character (`r`).

.EXAMPLE
    Get-PodeNewLineByte -Encoding [System.Text.Encoding]::ASCII
    # Returns the byte values for newline and carriage return in ASCII encoding.

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function Get-PodeNewLineByte {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter()]
        $Encoding = [System.Text.Encoding]::UTF8
    )

    return @{
        NewLine = @($Encoding.GetBytes("`n"))[0]
        Return  = @($Encoding.GetBytes("`r"))[0]
    }
}

function Test-PodeByteArrayIsBoundary {
    param(
        [Parameter()]
        [byte[]]
        $Bytes,

        [Parameter()]
        [string]
        $Boundary,

        [Parameter()]
        $Encoding = [System.Text.Encoding]::UTF8
    )

    # if no bytes, return
    if ($Bytes.Length -eq 0) {
        return $false
    }

    # if length difference >3, return (ie, 2 offset for `r`n)
    if (($Bytes.Length - $Boundary.Length) -gt 3) {
        return $false
    }

    # check if bytes starts with the boundary
    return (ConvertFrom-PodeBytesToString $Bytes $Encoding).StartsWith($Boundary)
}

function Remove-PodeNewLineBytesFromArray {
    param(
        [Parameter()]
        $Bytes,

        [Parameter()]
        $Encoding = [System.Text.Encoding]::UTF8
    )

    $nlBytes = Get-PodeNewLineByte -Encoding $Encoding
    $length = $Bytes.Length - 1

    if ($Bytes[$length] -eq $nlBytes.NewLine) {
        $length--
    }

    if ($Bytes[$length] -eq $nlBytes.Return) {
        $length--
    }

    return $Bytes[0..$length]
}