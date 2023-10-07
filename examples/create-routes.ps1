
#crete routes using different approaches 
$ScriptPath=Split-Path -Parent -Path $MyInvocation.MyCommand.Path
$path = Split-Path -Parent -Path $ScriptPath
if (Test-Path -Path "$($path)/src/Pode.psm1" -PathType Leaf) {
    Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop
} else {
    Import-Module -Name 'Pode'
}


Start-PodeServer -Threads 1 -ScriptBlock {
    Add-PodeEndpoint -Address localhost -Port 8081 -Protocol Http  
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging

    Add-PodeRoute -PassThru -Method Get -Path '/routeCreateScriptBlock/:id' -ScriptBlock ([ScriptBlock]::Create( (Get-Content -Path "$ScriptPath\scripts\routeScript.ps1" -Raw))) | 
    Set-PodeOARouteInfo -Summary 'Test' -OperationId 'routeCreateScriptBlock' -PassThru | 
    Set-PodeOARequest -Parameters @((New-PodeOAStringProperty -Name 'id' | ConvertTo-PodeOAParameter -In Path) )   

    
    Add-PodeRoute -PassThru -Method Post -Path '/routeFilePath/:id' -FilePath '.\scripts\routeScript.ps1' | Set-PodeOARouteInfo -Summary 'Test' -OperationId 'routeFilePath' -PassThru | 
    Set-PodeOARequest -Parameters @((New-PodeOAStringProperty -Name 'id' | ConvertTo-PodeOAParameter -In Path) )   
    

    Add-PodeRoute -PassThru -Method Get -Path '/routeScriptBlock/:id' -ScriptBlock { $Id = $WebEvent.Parameters['id'] ; Write-PodeJsonResponse -StatusCode 200 -Value @{'id' = $Id } } | 
    Set-PodeOARouteInfo -Summary 'Test' -OperationId 'routeScriptBlock' -PassThru | 
    Set-PodeOARequest -Parameters @((New-PodeOAStringProperty -Name 'id' | ConvertTo-PodeOAParameter -In Path) )   


    Add-PodeRoute -PassThru -Method Get -Path '/routeScriptSameScope/:id' -ScriptBlock { . $ScriptPath\scripts\routeScript.ps1 } | 
    Set-PodeOARouteInfo -Summary 'Test' -OperationId 'routeScriptBlock' -PassThru | 
    Set-PodeOARequest -Parameters @((New-PodeOAStringProperty -Name 'id' | ConvertTo-PodeOAParameter -In Path) )  

}