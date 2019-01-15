function Write-BytesToStream
{
    param (
        [Parameter(Mandatory=$true)]
        [byte[]]
        $Bytes,

        [Parameter(Mandatory=$true)]
        $Stream,

        [switch]
        $CheckNetwork
    )

    try {
        $ms = New-Object -TypeName System.IO.MemoryStream
        $ms.Write($Bytes, 0, $Bytes.Length)
        $ms.WriteTo($Stream)
        $ms.Close()
    }
    catch {
        if ($CheckNetwork -and (Test-ValidNetworkFailure $_.Exception)) {
            return
        }

        $_.Exception | Out-Default
        throw $_.Exception
    }
}

function Read-ByteLineFromByteArray
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

    $nlBytes = Get-NewLineBytes -Encoding $Encoding

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

function Get-ByteLinesFromByteArray
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
    $nlBytes = Get-NewLineBytes -Encoding $Encoding

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

function ConvertFrom-StreamToBytes
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

function ConvertFrom-ValueToBytes
{
    param (
        [Parameter()]
        [object]
        $Value,

        [Parameter()]
        $Encoding = [System.Text.Encoding]::UTF8
    )

    if ((Get-Type $Value).Name -ieq 'string') {
        $Value = $Encoding.GetBytes($Value)
    }

    return $Value
}

function ConvertFrom-BytesToString
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

    if (Test-Empty $Bytes) {
        return $Bytes
    }

    $value = $Encoding.GetString($Bytes)
    if ($RemoveNewLine) {
        $value = $value.Trim("`r`n")
    }

    return $value
}

function Get-NewLineBytes
{
    param (
        [Parameter()]
        $Encoding = [System.Text.Encoding]::UTF8
    )

    return @{
        'NewLine' = ($Encoding.GetBytes("`n") | Select-Object -First 1);
        'Return' = ($Encoding.GetBytes("`r") | Select-Object -First 1);
    }
}

function Remove-NewLineBytesFromArray
{
    param (
        [Parameter()]
        $Bytes,

        [Parameter()]
        $Encoding = [System.Text.Encoding]::UTF8
    )

    $nlBytes = Get-NewLineBytes -Encoding $Encoding
    $length = $Bytes.Length

    if ($Bytes[$length] -eq $nlBytes.NewLine) {
        $length--
    }

    if ($Bytes[$length] -eq $nlBytes.Return) {
        $length--
    }

    return $Bytes[0..$length]
}