


function Initialize-Categories {
    Lock-PodeObject -Name 'PetCategory' -ScriptBlock {
        Set-PodeState -Scope 'Categories'  -Name 'categories' -Value  @{} | Out-Null

        Add-Category -Id 1 -Name 'Dogs'
        Add-Category -Id 2 -Name 'Cats'
        Add-Category -Id 3 -Name 'Rabbits'
        Add-Category -Id 4 -Name 'Lions'
    }
}
function Initialize-Pet {
    Lock-PodeObject -Name 'PetLock' -ScriptBlock {
        Set-PodeState -Scope 'Pets' -Name 'pets' -Value @{} | Out-Null
        Add-Pet -Id 1 -Cat 'Cats' -Name 'Cat 1' -Urls  'url1', 'url2' -Tags  'tag1', 'tag2'  -Status available
        Add-Pet -Id 2 -Cat 'Cats' -Name 'Cat 2' -Urls  'url1', 'url2' -Tags  'tag2', 'tag3'  -Status available
        Add-Pet -Id 3 -Cat 'Cats' -Name 'Cat 2' -Urls  'url1', 'url2' -Tags  'tag3', 'tag4'  -Status pending

        Add-Pet -Id 4 -Cat 'Dogs' -Name 'Dog 1' -Urls  'url1', 'url2' -Tags  'tag1', 'tag2'  -Status available
        Add-Pet -Id 5 -Cat 'Dogs' -Name 'Dog 2' -Urls  'url1', 'url2' -Tags  'tag2', 'tag3'  -Status sold
        Add-Pet -Id 6 -Cat 'Dogs' -Name 'Dog 2' -Urls  'url1', 'url2' -Tags  'tag3', 'tag4'  -Status pending

        Add-Pet -Id 7 -Cat 'Lions' -Name 'Lion 1' -Urls  'url1', 'url2' -Tags  'tag1', 'tag2'  -Status available
        Add-Pet -Id 8 -Cat 'Lions' -Name 'Lion 2' -Urls  'url1', 'url2' -Tags  'tag2', 'tag3'  -Status available
        Add-Pet -Id 9 -Cat 'Lions' -Name 'Lion 2' -Urls  'url1', 'url2' -Tags  'tag3', 'tag4'  -Status available

        Add-Pet -Id 10 -Cat 'Rabbits' -Name 'Rabbit 1' -Urls  'url1', 'url2' -Tags  'tag2', 'tag3'  -Status available
        Add-Pet -Id 11 -Cat 'Rabbits' -Name 'Rabbit 2' -Urls  'url1', 'url2' -Tags  'tag3', 'tag4'  -Status pending
    }
}




function Add-Pet {

    [CmdletBinding(DefaultParameterSetName = 'Items')]
    param (
        [Parameter(Mandatory, ParameterSetName = 'Items')]
        [long]
        $Id,
        [Parameter( ParameterSetName = 'Items')]
        [String]
        $Category,
        [Parameter(Mandatory, ParameterSetName = 'Items')]
        [string]
        $Name,
        [Parameter(Mandatory, ParameterSetName = 'Items')]
        [string[]]
        $Urls,
        [Parameter( ParameterSetName = 'Items')]
        [string[]]
        $Tags,
        [Parameter( ParameterSetName = 'Items')]
        [ValidateSet('pending', 'available', 'sold')]
        [string]
        $Status,

        [Parameter(Mandatory, ParameterSetName = 'Object')]
        [hashtable]
        $Pet
    )
    Lock-PodeObject -Name 'PetLock' -ScriptBlock {
        $pets = Get-PodeState -Name 'pets'
        switch ($PSCmdlet.ParameterSetName) {
            'Items' {
                Get-PodeState -Name 'pets'
                $pets["$Id"] = @{
                    id           = $Id
                    categoryName = Get-Category -Name $Category
                    name         = $Name
                    photoUrls    = $Urls
                    tags         = $Tags
                    status       = $Status
                }
            }
            'Object' {
                $pets["$($Pet.id)"] = $Pet
            }
        } }
}





function Update-Pet {

    [CmdletBinding(DefaultParameterSetName = 'Items')]
    param (
        [Parameter(Mandatory, ParameterSetName = 'Items')]
        [long]
        $Id,
        [Parameter( ParameterSetName = 'Items')]
        [String]
        $Category,
        [Parameter(Mandatory, ParameterSetName = 'Items')]
        [string]
        $Name,
        [Parameter(Mandatory, ParameterSetName = 'Items')]
        [string[]]
        $Urls,
        [Parameter( ParameterSetName = 'Items')]
        [string[]]
        $Tags,
        [Parameter( ParameterSetName = 'Items')]
        [ValidateSet('pending', 'available', 'sold')]
        [string]
        $Status,

        [Parameter(Mandatory, ParameterSetName = 'Object')]
        [hashtable]
        $Pet
    )
    return  Lock-PodeObject -Name 'PetLock' -Return -ScriptBlock {
        $pets = Get-PodeState -Name 'pets'
        switch ($PSCmdlet.ParameterSetName) {
            'Items' {
                if ($pets.ContainsKey("$Id")) { 
                    if ($Category) {
                        $pets["$Id"].categoryName = Get-Category -Name $Category
                    }
                    if ($Name) {
                        $pets["$Id"].name = $Name
                    }
                    if ($Urls) {
                        $pets["$Id"].photoUrls = $Urls
                    }
                    if ($Tags) {
                        $pets["$Id"].tags = $Tags
                    }
                    if ($Status) {
                        $pets["$Id"].status = $Status
                    }
                    return $true
                }
            }
            'Object' {
                if ($pets.ContainsKey("$($Pet.id)")) {
                    $pets["$($Pet.id)"] = $Pet
                    return $true
                }
            }
        }
        return $false
    }
}


function Get-Pet {
    param (
        [Parameter(Mandatory)]
        [long]
        $Id
    )
    return Lock-PodeObject -Name 'PetLock' -Return -ScriptBlock {
        $pets = Get-PodeState -Name 'pets'
        return  $pets["$Id"]
    }
}


function Test-Pet {
    param (
        [Parameter(Mandatory)]
        [long]
        $Id
    )
    return Lock-PodeObject -Name 'PetLock' -Return -ScriptBlock {
        $pets = Get-PodeState -Name 'pets'
        return  $pets.ContainsKey("$Id")
    }
}



function Find-PetByStatus {
    param (
        [Parameter(Mandatory)]
        [string[]]
        $Status
    )
    return Lock-PodeObject -Name 'PetLock' -Return -ScriptBlock {
        $result = @()
        foreach ($pet in (Get-PodeState -Name 'pets').Values) {
            foreach ($s in $Status) {
                if ($s -ieq $pet.status) {
                    $result += $pet
                    break
                }
            }
        }
        return $result
    }

}


function Find-PetByTags {
    param (
        [Parameter(Mandatory)]
        [string[]]
        $Tags
    )

    return  Lock-PodeObject -Name 'PetLock' -Return -ScriptBlock {
        $result = @()
        foreach ($pet in (Get-PodeState -Name 'pets').Values) {
            if ($pet.tags) {
                foreach ($tag in $pet.tags) {
                    foreach ($tagListString in $Tags) {
                        if ($tagListString -ieq $tag) {
                            $result += $pet
                            break
                        }
                    }
                }
            }
        }
        return $result
    }
}


function Remove-Pet {
    param (
        [Parameter(Mandatory)]
        [long]
        $Id
    )
    Lock-PodeObject -Name 'PetLock' -ScriptBlock {
        $pets = (Get-PodeState -Name 'pets')
        $pets.Remove( $Id)
    }
}


function Add-Category {
    param (
        [Parameter(Mandatory)]
        [long]
        $Id,
        [Parameter(Mandatory)]
        [string]
        $Name
    )
    Lock-PodeObject -Name 'PetCategory' -ScriptBlock {
        $categories = (Get-PodeState -Name 'categories')
        $categories[$Name] = $Id
    }
}


function  Get-Category {
    [CmdletBinding(DefaultParameterSetName = 'Name')]
    param (
        [Parameter(Mandatory, ParameterSetName = 'Name')]
        [string]
        $Name,
        [Parameter(Mandatory, ParameterSetName = 'Id')]
        [long]
        $Id
    )
    return Lock-PodeObject -Name 'PetCategory' -Return -ScriptBlock {
        $categories = (Get-PodeState -Name 'categories')
        switch ($PSCmdlet.ParameterSetName) {
            'Name' {
                if ($categories.ContainsKey($name)) {
                    return  @{
                        name = $name
                        id   = $categories[$name]
                    }
                }
            }
            'Id' {
                foreach ($c in $categories) {
                    if ($c.id -eq $Id  ) {
                        return @{
                            name = $c.name
                            id   = $Id
                        }
                    }
                }
            }
        }
        return $null
    }
}
Export-ModuleMember -Function Initialize-Categories
Export-ModuleMember -Function Initialize-Pet
Export-ModuleMember -Function Add-Pet
Export-ModuleMember -Function Update-Pet
Export-ModuleMember -Function Get-Pet
Export-ModuleMember -Function Find-PetByTags
Export-ModuleMember -Function Find-PetByStatus
Export-ModuleMember -Function Remove-Pet
Export-ModuleMember -Function Add-Category
Export-ModuleMember -Function Get-Category
Export-ModuleMember -Function Test-Pet