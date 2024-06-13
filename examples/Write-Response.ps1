try {
    $ScriptPath = (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
    $podePath = Split-Path -Parent -Path $ScriptPath
    if (Test-Path -Path "$($podePath)/src/Pode.psm1" -PathType Leaf) {
        Import-Module "$($podePath)/src/Pode.psm1" -Force -ErrorAction Stop
    }
    else {
        Import-Module -Name 'Pode' -ErrorAction Stop
    }
}
catch { throw }

Start-PodeServer {
    Add-PodeEndpoint -Address localhost -Port 8081 -Protocol Http
    #   nopipe
    Add-PodeRoute -Path '/html/processes'  -Method Get -ScriptBlock {
        $myProcess = Get-Process | .{ process { if ($_.WS -gt 100mb) { $_ } } } |
            Select-Object Name, @{e = { [int]($_.WS / 1mb) }; n = 'WS' } |
            Sort-Object WS -Descending
        Write-PodeHtmlResponse -Value $myProcess  -StatusCode 200
    }
    #    pipe
    Add-PodeRoute -Path '/html/processesPiped'  -Method Get -ScriptBlock {
        Get-Process | .{ process { if ($_.WS -gt 100mb) { $_ } } } |
            Select-Object Name, @{e = { [int]($_.WS / 1mb) }; n = 'WS' } |
            Sort-Object WS -Descending | Write-PodeHtmlResponse  -StatusCode 200
    }

    #   nopipe
    Add-PodeRoute -Path '/text/processes'  -Method Get -ScriptBlock {
        $myProcess = Get-Process | .{ process { if ($_.WS -gt 100mb) { $_ } } } |
            Select-Object Name, @{e = { [int]($_.WS / 1mb) }; n = 'WS' } |
            Sort-Object WS -Descending | Out-String
        Write-PodeTextResponse -Value $myProcess  -StatusCode 200
    }
    #    pipe
    Add-PodeRoute -Path '/text/processesPiped'  -Method Get -ScriptBlock {
        Get-Process | .{ process { if ($_.WS -gt 100mb) { $_ } } } |
            Select-Object Name, @{e = { [int]($_.WS / 1mb) }; n = 'WS' } |
            Sort-Object WS -Descending | Out-String | Write-PodeTextResponse  -StatusCode 200
    }

    #   nopipe
    Add-PodeRoute -Path '/csv/processes'  -Method Get -ScriptBlock {
        $myProcess = Get-Process | .{ process { if ($_.WS -gt 100mb) { $_ } } } |
            Select-Object Name, @{e = { [int]($_.WS / 1mb) }; n = 'WS' } |
            Sort-Object WS -Descending
        Write-PodeCsvResponse -Value $myProcess  -StatusCode 200
    }

    #    pipe
    Add-PodeRoute -Path '/csv/processesPiped'  -Method Get -ScriptBlock {
        Get-Process | .{ process { if ($_.WS -gt 100mb) { $_ } } } |
            Select-Object Name, @{e = { [int]($_.WS / 1mb) }; n = 'WS' } |
            Sort-Object WS -Descending | Write-PodeCsvResponse  -StatusCode 200
    }

    Add-PodeRoute -Path '/csv/string'  -Method Get -ScriptBlock {
        Write-PodeCsvResponse -Value "Name`nRick`nDon"
    }

    Add-PodeRoute -Path '/csv/hash'  -Method Get -ScriptBlock {
        Write-PodeCsvResponse -Value @(@{ Name = 'Rick' }, @{ Name = 'Don' })
    }

    #   nopipe
    Add-PodeRoute -Path '/json/processes'  -Method Get -ScriptBlock {
        $myProcess = Get-Process | .{ process { if ($_.WS -gt 100mb) { $_ } } } |
            Select-Object Name, @{e = { [int]($_.WS / 1mb) }; n = 'WS' } |
            Sort-Object WS -Descending
        Write-PodeJsonResponse -Value $myProcess  -StatusCode 200
    }

    #    pipe
    Add-PodeRoute -Path '/json/processesPiped'  -Method Get -ScriptBlock {
        Get-Process | .{ process { if ($_.WS -gt 100mb) { $_ } } } |
            Select-Object Name, @{e = { [int]($_.WS / 1mb) }; n = 'WS' } |
            Sort-Object WS -Descending | Write-PodeJsonResponse  -StatusCode 200
    }

    #   nopipe
    Add-PodeRoute -Path '/xml/processes'  -Method Get -ScriptBlock {
        $myProcess = Get-Process | .{ process { if ($_.WS -gt 100mb) { $_ } } } |
            Select-Object Name, @{e = { [int]($_.WS / 1mb) }; n = 'WS' } |
            Sort-Object WS -Descending
        Write-PodeXmlResponse -Value $myProcess  -StatusCode 200
    }

    #    pipe
    Add-PodeRoute -Path '/xml/processesPiped'  -Method Get -ScriptBlock {
        Get-Process | .{ process { if ($_.WS -gt 100mb) { $_ } } } |
            Select-Object Name, @{e = { [int]($_.WS / 1mb) }; n = 'WS' } |
            Sort-Object WS -Descending | Write-PodeXmlResponse  -StatusCode 200
    }


    Add-PodeRoute -Path '/xml/hash'  -Method Get -ScriptBlock {
        Write-PodeXmlResponse -Value @(@{ Name = 'Rick' }, @{ Name = 'Don' })
    }

    #   nopipe
    Add-PodeRoute -Path '/yaml/processes'  -Method Get -ScriptBlock {
        $myProcess = Get-Process | .{ process { if ($_.WS -gt 100mb) { $_ } } } |
            Select-Object Name, @{e = { [int]($_.WS / 1mb) }; n = 'WS' } |
            Sort-Object WS -Descending
        Write-PodeYamlResponse -Value $myProcess  -StatusCode 200  -ContentType 'text/yaml'
    }

    #    pipe
    Add-PodeRoute -Path '/yaml/processesPiped'  -Method Get -ScriptBlock {
        Get-Process | .{ process { if ($_.WS -gt 100mb) { $_ } } } |
            Select-Object Name, @{e = { [int]($_.WS / 1mb) }; n = 'WS' } |
            Sort-Object WS -Descending | Write-PodeYamlResponse   -StatusCode 200 -ContentType 'text/yaml'
    }
    Start-Job -ScriptBlock {
        Start-Sleep -Seconds 5
        Start-Process http://localhost:8081/html/processesPiped
        Start-Process http://localhost:8081/html/processes
        Start-Process http://localhost:8081/text/processesPiped
        Start-Process http://localhost:8081/text/processes
        Start-Process http://localhost:8081/csv/processesPiped
        Start-Process http://localhost:8081/csv/processes
        Start-Process http://localhost:8081/csv/string
        Start-Process http://localhost:8081/csv/hash
        Start-Process http://localhost:8081/json/processesPiped
        Start-Process http://localhost:8081/json/processes
        Start-Process http://localhost:8081/xml/processesPiped
        Start-Process http://localhost:8081/xml/processes
        Start-Process http://localhost:8081/xml/hash
        Start-Process http://localhost:8081/yaml/processesPiped
        Start-Process http://localhost:8081/yaml/processes
    }
}