$path = $MyInvocation.MyCommand.Path
$src = (Split-Path -Parent -Path $path) -ireplace '\\tests\\unit\\', '\src\'
$sut = (Split-Path -Leaf -Path $path) -ireplace '\.Tests\.', '.'
. "$($src)\$($sut)"

Describe 'Get-PodeRoute' {
    Context 'Invalid parameters supplied' {
        It 'Throw invalid method error for no method' {
            { Get-PodeRoute -HttpMethod 'MOO' -Route '/' } | Should Throw "Cannot validate argument on parameter 'HttpMethod'"
        }

        It 'Throw null route parameter error' {
            { Get-PodeRoute -HttpMethod GET -Route $null } | Should Throw 'The argument is null or empty'
        }

        It 'Throw empty route parameter error' {
            { Get-PodeRoute -HttpMethod GET -Route ([string]::Empty) } | Should Throw 'The argument is null or empty'
        }
    }

    Context 'Valid method and route' {
        It 'Return null as method does not exist' {
            $PodeSession = @{ 'Routes' = @{}; }
            Get-PodeRoute -HttpMethod GET -Route '/' | Should Be $null
        }

        It 'Returns no logic for method/route that do not exist' {
            $PodeSession = @{ 'Routes' = @{ 'GET' = @{}; }; }
            Get-PodeRoute -HttpMethod GET -Route '/' | Should Be $null
        }

        It 'Returns logic for method and exact route' {
            $PodeSession = @{ 'Routes' = @{ 'GET' = @{ '/' = { Write-Host 'Test' }; }; }; }
            $result = (Get-PodeRoute -HttpMethod GET -Route '/')

            $result | Should BeOfType System.Collections.Hashtable
            $result.Logic.ToString() | Should Be ({ Write-Host 'Test' }).ToString()
            $result.Parameters | Should Be $null
        }

        It 'Returns logic and parameters for parameterised route' {
            $PodeSession = @{ 'Routes' = @{ 'GET' = @{ '/(?<userId>[\w-_]+?)' = { Write-Host 'Test' }; }; }; }
            $result = (Get-PodeRoute -HttpMethod GET -Route '/123')

            $result | Should BeOfType System.Collections.Hashtable
            $result.Logic.ToString() | Should Be ({ Write-Host 'Test' }).ToString()
            
            $result.Parameters | Should BeOfType System.Collections.Hashtable
            $result.Parameters['userId'] | Should Be '123'
        }
    }
}

Describe 'Route' {
    Context 'Invalid parameters supplied' {
        It 'Throw invalid method error for no method' {
            { Route -HttpMethod 'MOO' -Route '/' -ScriptBlock {} } | Should Throw "Cannot validate argument on parameter 'HttpMethod'"
        }

        It 'Throw null route parameter error' {
            { Route -HttpMethod GET -Route $null -ScriptBlock {} } | Should Throw 'it is an empty string'
        }

        It 'Throw empty route parameter error' {
            { Route -HttpMethod GET -Route ([string]::Empty) -ScriptBlock {} } | Should Throw 'it is an empty string'
        }

        It 'Throw null scriptblock parameter error' {
            { Route -HttpMethod GET -Route '/' -ScriptBlock $null } | Should Throw 'The argument is null'
        }
    }

    Context 'Valid parameters have been supplied' {
        It 'Throw error because only querystring has been given' {
            { Route -HttpMethod GET -Route "?k=v" -ScriptBlock {} } | Should Throw "No route supplied for GET request"
        }
    }
}