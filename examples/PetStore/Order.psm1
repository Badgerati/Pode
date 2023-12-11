$orders = @{}
function Initialize-Order {
    $now = (Get-Date)
    New-Order -Id 1 -PetId 1 -Quantity 100 -ShipDate $now -Status 'placed' -Complete
    New-Order -Id 2 -PetId 1 -Quantity 50 -ShipDate $now -Status 'approved' -Complete
    New-Order -Id 3 -PetId 1 -Quantity 50 -ShipDate $now -Status 'delivered' -Complete
    New-Order -Id 4 -PetId 1 -Quantity 20 -ShipDate $now -Status 'placed'
}

function Add-Order {
    [CmdletBinding(DefaultParameterSetName = 'Items')]
    param (
        [Parameter(Mandatory, ParameterSetName = 'Items')]
        [long]
        $Id,

        [Parameter(Mandatory, ParameterSetName = 'Items')]
        [long]
        $PetId,

        [Parameter(Mandatory, ParameterSetName = 'Items')]
        [int]
        $Quantity,

        [Parameter(Mandatory, ParameterSetName = 'Items')]
        [datetime]
        $ShipDate,

        [Parameter(Mandatory, ParameterSetName = 'Items')]
        [string]
        $Status,
        [Parameter(Mandatory, ParameterSetName = 'Items')]
        [switch]
        $Complete,

        [Parameter(Mandatory, ParameterSetName = 'Object')]
        [hashtable]
        $Order
    )
    switch ($PSCmdlet.ParameterSetName) {
        'Items' {
            $orders[$Id] = @{
                id       = $Id
                petId    = $PetId
                quantity = $Quantity
                shipdate = $ShipDate
                status   = $Status
                complete = $Complete.IsPresent
            }
        }
        'Object' {
            $orders[$Order.id] = $Order
        }
    }

}


function Get-OrderById {
    param (
        [Parameter(Mandatory)]
        [long]
        $OrderId
    )

    return  $orders[$Id]
}

function Get-CountByStatus {
    $countByStatus = @{}
    foreach ($order in $orders.Values) {
        $status = $order.status
        if ($countByStatus.containsKey($status)) {
            $countByStatus[$status] += $order.quantity
        } else {
            $countByStatus[$status] = $order.quantity
        }
    }
    return $countByStatus
}

function Remove-OrderById {
    param (
        [Parameter(Mandatory)]
        [long]
        $OrderId
    )
    $orders.Remove( $OrderId)
}


Export-ModuleMember -Function Initialize-Order
Export-ModuleMember -Function Get-OrderById
Export-ModuleMember -Function Get-CountByStatus
Export-ModuleMember -Function Add-Order
Export-ModuleMember -Function Remove-OrderById