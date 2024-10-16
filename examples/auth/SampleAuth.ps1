# setup bearer auth
New-PodeAuthScheme -ApiKey -Location $Location | Add-PodeAuth -Name 'Validate' -Sessionless -ScriptBlock {
    param($key)

    # here you'd check a real user storage, this is just for example
    if ($key -ieq 'test-api-key') {
        return @{
            User = @{
                ID   = 'M0R7Y302'
                Name = 'Morty'
                Type = 'Human'
            }
        }
    }

    return $null
}