function Auth
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet('use', 'check')]
        [Alias('a')]
        [string]
        $Action,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [Alias('n')]
        [string]
        $Name,

        [Parameter()]
        [Alias('v')]
        [object]
        $Validator,

        [Parameter()]
        [Alias('p')]
        [scriptblock]
        $Parser,

        [Parameter()]
        [Alias('o')]
        [hashtable]
        $Options,

        [Parameter()]
        [Alias('t')]
        [string]
        $Type,

        [switch]
        [Alias('c')]
        $Custom
    )

    # for the 'use' action, ensure we have a validator. and a parser for custom types
    if ($Action -ieq 'use') {
        # was a validator passed
        if (Test-IsEmpty $Validator) {
            throw "Authentication method '$($Name)' is missing required Validator script"
        }

        # is the validator a string/scriptblock?
        $vTypes = @('string', 'scriptblock')
        if ($vTypes -inotcontains (Get-PodeType $Validator).Name) {
            throw "Authentication method '$($Name)' has an invalid validator supplied, should be one of: $($vTypes -join ', ')"
        }

        # don't fail if custom and type supplied, and it's already defined
        if ($Custom)
        {
            $typeDefined = (![string]::IsNullOrWhiteSpace($Type) -and $PodeContext.Server.Authentications.ContainsKey($Type))
            if (!$typeDefined -and (Test-IsEmpty $Parser)) {
                throw "Custom authentication method '$($Name)' is missing required Parser script"
            }
        }
    }

    # invoke the appropriate auth logic for the action
    switch ($Action.ToLowerInvariant())
    {
        'use' {
            Invoke-PodeAuthUse -Name $Name -Type $Type -Validator $Validator -Parser $Parser -Options $Options -Custom:$Custom
        }

        'check' {
            return (Invoke-PodeAuthCheck -Name $Name -Options $Options)
        }
    }
}