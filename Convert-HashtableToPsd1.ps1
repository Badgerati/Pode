
param (
    [Parameter(Mandatory = $false)]
    [string]$Path = 'c:\Users\m_dan\Documents\GitHub\Pode\src\Locales'
)



function Convert-HashTable {
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$hashtable
    )


    $sb = New-Object System.Text.StringBuilder
    $sb.AppendLine('@{') | Out-Null

    foreach ($key in $hashtable.Keys) {
        $value = $hashtable[$key]
        $sb.AppendLine(" $key = `"$value`"") | Out-Null
    }

    $sb.AppendLine('}') | Out-Null
    return $sb.ToString()
}

$languageDirs = Get-ChildItem -Path $Path -Directory
foreach ($item in $languageDirs) {
    $fullName = Join-Path -Path $item.FullName -ChildPath 'Pode.psd1'

    $PodeFileContent = Get-content  $fullName  -raw
    $value = Invoke-Expression $podeFileContent


    $result = Convert-HashTable -hashtable $value
    Move-Item  -path $fullName -destination "$fullName.old"
    Set-Content -Path $fullName -Value  $result
}