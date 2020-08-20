function Read-PodeStreamToEnd
{
    param (
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

function Read-PodeByteLineFromByteArray
{
    param (
        [Parameter(Mandatory=$true)]
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

    $nlBytes = Get-PodeNewLineBytes -Encoding $Encoding

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
        'Bytes' = $Bytes[$StartIndex..$fIndex];
        'StartIndex' = $StartIndex;
        'EndIndex' = $index;
    }
}

function Get-PodeByteLinesFromByteArray
{
    param (
        [Parameter(Mandatory=$true)]
        [byte[]]
        $Bytes,

        [Parameter()]
        $Encoding = [System.Text.Encoding]::UTF8,

        [switch]
        $IncludeNewLine
    )

    # lines
    $lines = @()
    $nlBytes = Get-PodeNewLineBytes -Encoding $Encoding

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
        $lines += ,$Bytes[$index..$fIndex]
        $index = $nextIndex + 1
    }

    return $lines
}

function ConvertFrom-PodeStreamToBytes
{
    param (
        [Parameter(Mandatory=$true)]
        $Stream
    )

    $buffer = [byte[]]::new(64 * 1024)
    $ms = New-Object -TypeName System.IO.MemoryStream
    $read = 0

    while (($read = $Stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
        $ms.Write($buffer, 0, $read)
    }

    $ms.Close()
    return $ms.ToArray()
}

function ConvertFrom-PodeValueToBytes
{
    param (
        [Parameter()]
        [string]
        $Value,

        [Parameter()]
        $Encoding = [System.Text.Encoding]::UTF8
    )

    return $Encoding.GetBytes($Value)
}

function ConvertFrom-PodeBytesToString
{
    param (
        [Parameter()]
        [byte[]]
        $Bytes,

        [Parameter()]
        $Encoding = [System.Text.Encoding]::UTF8,

        [switch]
        $RemoveNewLine
    )

    if (Test-PodeIsEmpty $Bytes) {
        return $Bytes
    }

    $value = $Encoding.GetString($Bytes)
    if ($RemoveNewLine) {
        $value = $value.Trim("`r`n")
    }

    return $value
}

function Get-PodeNewLineBytes
{
    param (
        [Parameter()]
        $Encoding = [System.Text.Encoding]::UTF8
    )

    return @{
        'NewLine' = @($Encoding.GetBytes("`n"))[0];
        'Return' = @($Encoding.GetBytes("`r"))[0];
    }
}

function Test-PodeByteArrayIsBoundary
{
    param (
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

function Remove-PodeNewLineBytesFromArray
{
    param (
        [Parameter()]
        $Bytes,

        [Parameter()]
        $Encoding = [System.Text.Encoding]::UTF8
    )

    $nlBytes = Get-PodeNewLineBytes -Encoding $Encoding
    $length = $Bytes.Length

    if ($Bytes[$length] -eq $nlBytes.NewLine) {
        $length--
    }

    if ($Bytes[$length] -eq $nlBytes.Return) {
        $length--
    }

    return $Bytes[0..$length]
}