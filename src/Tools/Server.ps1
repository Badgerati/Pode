
function Server
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [int]
        $Port,

        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [scriptblock]
        $ScriptBlock
    )

    $PodeSession = New-Object -TypeName psobject |
        Add-Member -MemberType NoteProperty -Name Routes -Value $null -PassThru |
        Add-Member -MemberType NoteProperty -Name Port -Value $Port -PassThru

    $PodeSession.Routes = @{
        'delete' = @{};
        'get' = @{};
        'head' = @{};
        'merge' = @{};
        'options' = @{};
        'patch' = @{};
        'post' = @{};
        'put' = @{};
        'trace' = @{};
    }

    & $ScriptBlock
}