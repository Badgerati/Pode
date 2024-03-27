$orders = @{}
function Initialize-Order {
    param (
        [switch]
        $Reset
    )
    New-PodeLockable -Name 'PetOrderLock'
    if ($Reset.IsPresent) {
        $now = (Get-Date)
        Lock-PodeObject -Name 'PetOrderLock' -ScriptBlock {
            Set-PodeState -Scope 'Orders'  -Name 'orders' -Value  @{} | Out-Null
            Add-Order -Id 1 -PetId 1 -Quantity 100 -ShipDate $now -Status 'placed' -Complete
            Add-Order -Id 2 -PetId 1 -Quantity 50 -ShipDate $now -Status 'approved' -Complete
            Add-Order -Id 3 -PetId 1 -Quantity 50 -ShipDate $now -Status 'delivered' -Complete
            Add-Order -Id 4 -PetId 1 -Quantity 20 -ShipDate $now -Status 'placed'
        }
    }
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

        [Parameter(  ParameterSetName = 'Items')]
        [switch]
        $Complete,

        [Parameter(Mandatory, ParameterSetName = 'Object')]
        [hashtable]
        $Order
    )
    Lock-PodeObject -Name 'PetOrderLock' -ScriptBlock {
        $orders = Get-PodeState   -Name 'orders'
        switch ($PSCmdlet.ParameterSetName) {
            'Items' {
                $orders["$Id"] = @{
                    id       = $Id
                    petId    = $PetId
                    quantity = $Quantity
                    shipdate = $ShipDate
                    status   = $Status
                    complete = $Complete.IsPresent
                }
            }
            'Object' {
                $orders["$($Order.id)"] = $Order
            }
        }
    }
}


function Get-Order {
    param (
        [Parameter(Mandatory)]
        [long]
        $Id
    )
    return Lock-PodeObject -Name 'PetOrderLock' -Return -ScriptBlock {
        $orders = Get-PodeState   -Name 'orders'
        return  $orders["$Id"]
    }
}

function Test-Order {
    param (
        [Parameter(Mandatory)]
        [long]
        $Id
    )
    return Lock-PodeObject -Name 'PetOrderLock' -Return -ScriptBlock {
        $orders = Get-PodeState   -Name 'orders'
        return  $orders.ContainsKey("$Id")
    }
}


function Get-CountByStatus {
    return Lock-PodeObject -Name 'PetOrderLock' -Return -ScriptBlock {
        $result = @{}
        foreach ($order in (Get-PodeState -Name 'orders').Values) {
            $status = $order.status
            if ($result.containsKey($status)) {
                $result[$status] += $order.quantity
            } else {
                $result[$status] = $order.quantity
            }
        }
        return $result
    }
}

function Remove-Order {
    param (
        [Parameter(Mandatory)]
        [long]
        $Id
    )
    Lock-PodeObject -Name 'PetOrderLock' -ScriptBlock {
        $order = (Get-PodeState -Name 'orders')
        $order.Remove( "$Id")
    }
}


Export-ModuleMember -Function Initialize-Order
Export-ModuleMember -Function Get-Order
Export-ModuleMember -Function Get-CountByStatus
Export-ModuleMember -Function Add-Order
Export-ModuleMember -Function Test-Order
Export-ModuleMember -Function Remove-Order