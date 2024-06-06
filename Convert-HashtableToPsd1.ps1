
param (
    [Parameter(Mandatory = $false)]
    [string]$Path = 'c:\Users\m_dan\Documents\GitHub\Pode\src\Locales\en\Pode.psd1 '
)
$PodeFileContent = Get-content $Path -raw
$value = Invoke-Expression $podeFileContent


function Convert-HashTable {
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$hashtable
    )


    $sb = New-Object System.Text.StringBuilder
    $sb.AppendLine('@{')

    foreach ($key in $hashtable.Keys) {
        $value = $hashtable[$key]

        if ($value -is [hashtable]) {
            $nestedPsd1 = Convert-HashTable -hashtable $value
            $sb.AppendLine(" $key = $nestedPsd1") | Out-Null
        }
        else {
            $sb.AppendLine(" $key = `"$($value -replace '$','`$')`"") | Out-Null
        }
    }

    $sb.AppendLine('}')
    return $sb.ToString()
}


$sb = Convert-HashTable -hashtable $value
Move-Item  -path $Path -destination "$Path.old"
Set-Content -Path $Path -Value  $sb