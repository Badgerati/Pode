

function Get-PodeAuthWindowsADIISMethod {
    return {
        param($token, $options)

        # get the close handler
        $win32Handler = Add-Type -Name Win32CloseHandle -PassThru -MemberDefinition @'
            [DllImport("kernel32.dll", SetLastError = true)]
            public static extern bool CloseHandle(IntPtr handle);
'@

        try {
            # parse the auth token and get the user
            $winAuthToken = [System.IntPtr][Int]"0x$($token)"
            $winIdentity = [System.Security.Principal.WindowsIdentity]::new($winAuthToken, 'Windows')

            # get user and domain
            $username = ($winIdentity.Name -split '\\')[-1]
            $domain = ($winIdentity.Name -split '\\')[0]

            # create base user object
            $user = @{
                UserType           = 'Domain'
                Identity           = @{
                    AccessToken = $winIdentity.AccessToken
                }
                AuthenticationType = $winIdentity.AuthenticationType
                DistinguishedName  = [string]::Empty
                Username           = $username
                Name               = [string]::Empty
                Email              = [string]::Empty
                Fqdn               = [string]::Empty
                Domain             = $domain
                Groups             = @()
            }

            # if the domain isn't local, attempt AD user
            if (![string]::IsNullOrWhiteSpace($domain) -and (@('.', $PodeContext.Server.ComputerName) -inotcontains $domain)) {
                # get the server's fdqn (and name/email)
                try {
                    # Open ADSISearcher and change context to given domain
                    $searcher = [adsisearcher]''
                    $searcher.SearchRoot = [adsi]"LDAP://$($domain)"
                    $searcher.Filter = "ObjectSid=$($winIdentity.User.Value.ToString())"

                    # Query the ADSISearcher for the above defined SID
                    $ad = $searcher.FindOne()

                    # Save it to our existing array for later usage
                    $user.DistinguishedName = @($ad.Properties.distinguishedname)[0]
                    $user.Name = @($ad.Properties.name)[0]
                    $user.Email = @($ad.Properties.mail)[0]
                    $user.Fqdn = (Get-PodeADServerFromDistinguishedName -DistinguishedName $user.DistinguishedName)
                }
                finally {
                    Close-PodeDisposable -Disposable $searcher
                }

                try {
                    if (!$options.NoGroups) {

                        # open a new connection
                        $result = (Open-PodeAuthADConnection -Server $user.Fqdn -Domain $domain -Provider $options.Provider)
                        if (!$result.Success) {
                            return @{ Message = "Failed to connect to Domain Server '$($user.Fqdn)' of $domain for $($user.DistinguishedName)." }
                        }

                        # get the connection
                        $connection = $result.Connection

                        # get the users groups
                        $directGroups = $options.DirectGroups
                        $user.Groups = (Get-PodeAuthADGroup -Connection $connection -DistinguishedName $user.DistinguishedName -Username $user.Username -Direct:$directGroups -Provider $options.Provider)
                    }
                }
                finally {
                    if ($null -ne $connection) {
                        Close-PodeDisposable -Disposable $connection.Searcher
                        Close-PodeDisposable -Disposable $connection.Entry -Close
                        $connection.Credential = $null
                    }
                }
            }

            # otherwise, get details of local user
            else {
                # get the user's name and groups
                try {
                    $user.UserType = 'Local'

                    if (!$options.NoLocalCheck) {
                        $localUser = $winIdentity.Name -replace '\\', '/'
                        $ad = [adsi]"WinNT://$($localUser)"
                        $user.Name = @($ad.FullName)[0]

                        # dirty, i know :/ - since IIS runs using pwsh, the InvokeMember part fails
                        # we can safely call windows powershell here, as IIS is only on windows.
                        if (!$options.NoGroups) {
                            $cmd = "`$ad = [adsi]'WinNT://$($localUser)'; @(`$ad.Groups() | Foreach-Object { `$_.GetType().InvokeMember('Name', 'GetProperty', `$null, `$_, `$null) })"
                            $user.Groups = [string[]](powershell -c $cmd)
                        }
                    }
                }
                finally {
                    Close-PodeDisposable -Disposable $ad -Close
                }
            }
        }
        catch {
            $_ | Write-PodeErrorLog
            return @{ Message = 'Failed to retrieve user using Authentication Token' }
        }
        finally {
            $win32Handler::CloseHandle($winAuthToken)
        }

        # is the user valid for any users/groups - if not, error!
        if (!(Test-PodeAuthUserGroup -User $user -Users $options.Users -Groups $options.Groups)) {
            return @{ Message = 'You are not authorised to access this website' }
        }

        $result = @{ User = $user }

        # call additional scriptblock if supplied
        if ($null -ne $options.ScriptBlock.Script) {
            $result = Invoke-PodeAuthInbuiltScriptBlock -User $result.User -ScriptBlock $options.ScriptBlock.Script -UsingVariables $options.ScriptBlock.UsingVariables
        }

        # return final result, this could contain a user obj, or an error message from custom scriptblock
        return $result
    }
}

function Get-PodeADServerFromDistinguishedName {
    param(
        [Parameter()]
        [string]
        $DistinguishedName
    )

    if ([string]::IsNullOrWhiteSpace($DistinguishedName)) {
        return [string]::Empty
    }

    $parts = @($DistinguishedName -split ',')
    $name = @()

    foreach ($part in $parts) {
        if ($part -imatch '^DC=(?<name>.+)$') {
            $name += $Matches['name']
        }
    }

    return ($name -join '.')
}

function Get-PodeAuthADResult {
    param(
        [Parameter()]
        [string]
        $Server,

        [Parameter()]
        [string]
        $Domain,

        [Parameter()]
        [string]
        $SearchBase,

        [Parameter()]
        [string]
        $Username,

        [Parameter()]
        [string]
        $Password,

        [Parameter()]
        [ValidateSet('DirectoryServices', 'ActiveDirectory', 'OpenLDAP')]
        [string]
        $Provider,

        [switch]
        $NoGroups,

        [switch]
        $DirectGroups,

        [switch]
        $KeepCredential
    )

    try {
        # validate the user's AD creds
        $result = (Open-PodeAuthADConnection -Server $Server -Domain $Domain -Username $Username -Password $Password -Provider $Provider)
        if (!$result.Success) {
            return @{ Message = 'Invalid credentials supplied' }
        }

        # get the connection
        $connection = $result.Connection

        # get the user
        $user = (Get-PodeAuthADUser -Connection $connection -Username $Username -Provider $Provider)
        if ($null -eq $user) {
            return @{ Message = 'User not found in Active Directory' }
        }

        # get the users groups
        $groups = @()
        if (!$NoGroups) {
            $groups = (Get-PodeAuthADGroup -Connection $connection -DistinguishedName $user.DistinguishedName -Username $Username -Direct:$DirectGroups -Provider $Provider)
        }

        # check if we want to keep the credentials in the User object
        if ($KeepCredential) {
            $credential = [pscredential]::new($($Domain + '\' + $Username), (ConvertTo-SecureString -String $Password -AsPlainText -Force))
        }
        else {
            $credential = $null
        }

        # return the user
        return @{
            User = @{
                UserType           = 'Domain'
                AuthenticationType = 'LDAP'
                DistinguishedName  = $user.DistinguishedName
                Username           = ($Username -split '\\')[-1]
                Name               = $user.Name
                Email              = $user.Email
                Fqdn               = $Server
                Domain             = $Domain
                Groups             = $groups
                Credential         = $credential
            }
        }
    }
    finally {
        if ($null -ne $connection) {
            switch ($Provider.ToLowerInvariant()) {
                'openldap' {
                    $connection.Username = $null
                    $connection.Password = $null
                }

                'activedirectory' {
                    $connection.Credential = $null
                }

                'directoryservices' {
                    Close-PodeDisposable -Disposable $connection.Searcher
                    Close-PodeDisposable -Disposable $connection.Entry -Close
                }
            }
        }
    }
}

function Open-PodeAuthADConnection {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Server,

        [Parameter()]
        [string]
        $Domain,

        [Parameter()]
        [string]
        $SearchBase,

        [Parameter()]
        [string]
        $Username,

        [Parameter()]
        [string]
        $Password,

        [Parameter()]
        [ValidateSet('LDAP', 'WinNT')]
        [string]
        $Protocol = 'LDAP',

        [Parameter()]
        [ValidateSet('DirectoryServices', 'ActiveDirectory', 'OpenLDAP')]
        [string]
        $Provider
    )

    $result = $true
    $connection = $null

    # validate the user's AD creds
    switch ($Provider.ToLowerInvariant()) {
        'openldap' {
            if (![string]::IsNullOrWhiteSpace($SearchBase)) {
                $baseDn = $SearchBase
            }
            else {
                $baseDn = "DC=$(($Server -split '\.') -join ',DC=')"
            }

            $query = (Get-PodeAuthADQuery -Username $Username)
            $hostname = "$($Protocol)://$($Server)"

            $user = $Username
            if (!$Username.StartsWith($Domain)) {
                $user = "$($Domain)\$($Username)"
            }

            $null = (ldapsearch -x -LLL -H "$($hostname)" -D "$($user)" -w "$($Password)" -b "$($baseDn)" -o ldif-wrap=no "$($query)" dn)
            if (!$? -or ($LASTEXITCODE -ne 0)) {
                $result = $false
            }
            else {
                $connection = @{
                    Hostname = $hostname
                    Username = $user
                    BaseDN   = $baseDn
                    Password = $Password
                }
            }
        }

        'activedirectory' {
            try {
                $creds = [pscredential]::new($Username, (ConvertTo-SecureString -String $Password -AsPlainText -Force))
                $null = Get-ADUser -Identity $Username -Credential $creds -ErrorAction Stop
                $connection = @{
                    Credential = $creds
                }
            }
            catch {
                $result = $false
            }
        }

        'directoryservices' {
            if ([string]::IsNullOrWhiteSpace($Password)) {
                $ad = [System.DirectoryServices.DirectoryEntry]::new("$($Protocol)://$($Server)")
            }
            else {
                $ad = [System.DirectoryServices.DirectoryEntry]::new("$($Protocol)://$($Server)", "$($Username)", "$($Password)")
            }

            if (Test-PodeIsEmpty $ad.distinguishedName) {
                $result = $false
            }
            else {
                $connection = @{
                    Entry = $ad
                }
            }
        }
    }

    return @{
        Success    = $result
        Connection = $connection
    }
}

function Get-PodeAuthADQuery {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Username
    )

    return "(&(objectCategory=person)(samaccountname=$($Username)))"
}

function Get-PodeAuthADUser {
    param(
        [Parameter(Mandatory = $true)]
        $Connection,

        [Parameter(Mandatory = $true)]
        [string]
        $Username,

        [Parameter()]
        [ValidateSet('DirectoryServices', 'ActiveDirectory', 'OpenLDAP')]
        [string]
        $Provider
    )

    $query = (Get-PodeAuthADQuery -Username $Username)
    $user = $null

    # generate query to find user
    switch ($Provider.ToLowerInvariant()) {
        'openldap' {
            $result = (ldapsearch -x -LLL -H "$($Connection.Hostname)" -D "$($Connection.Username)" -w "$($Connection.Password)" -b "$($Connection.BaseDN)" -o ldif-wrap=no "$($query)" name mail)
            if (!$? -or ($LASTEXITCODE -ne 0)) {
                return $null
            }

            $user = @{
                DistinguishedName = (Get-PodeOpenLdapValue -Lines $result -Property 'dn')
                Name              = (Get-PodeOpenLdapValue -Lines $result -Property 'name')
                Email             = (Get-PodeOpenLdapValue -Lines $result -Property 'mail')
            }
        }

        'activedirectory' {
            $result = Get-ADUser -LDAPFilter $query -Credential $Connection.Credential -Properties mail
            $user = @{
                DistinguishedName = $result.DistinguishedName
                Name              = $result.Name
                Email             = $result.mail
            }
        }

        'directoryservices' {
            $Connection.Searcher = [System.DirectoryServices.DirectorySearcher]::new($Connection.Entry)
            $Connection.Searcher.filter = $query

            $result = $Connection.Searcher.FindOne().Properties
            if (Test-PodeIsEmpty $result) {
                return $null
            }

            $user = @{
                DistinguishedName = @($result.distinguishedname)[0]
                Name              = @($result.name)[0]
                Email             = @($result.mail)[0]
            }
        }
    }

    return $user
}



function Get-PodeOpenLdapValue {
    param(
        [Parameter()]
        [string[]]
        $Lines,

        [Parameter()]
        [string]
        $Property,

        [switch]
        $All
    )

    foreach ($line in $Lines) {
        if ($line -imatch "^$($Property)\:\s+(?<$($Property)>.+)$") {
            # return the first found
            if (!$All) {
                return $Matches[$Property]
            }

            # return array of all
            $Matches[$Property]
        }
    }
}
<#
.SYNOPSIS
    Retrieves Active Directory (AD) group information for a user.

.DESCRIPTION
    This function retrieves AD group information for a specified user. It supports two modes of operation:
    1. Direct: Retrieves groups directly associated with the user.
    2. All: Retrieves all groups within the specified distinguished name (DN).

.PARAMETER Connection
    The AD connection object or credentials for connecting to the AD server.

.PARAMETER DistinguishedName
    The distinguished name (DN) of the user or group. If not provided, the default DN is used.

.PARAMETER Username
    The username for which to retrieve group information.

.PARAMETER Provider
    The AD provider to use (e.g., 'DirectoryServices', 'ActiveDirectory', 'OpenLDAP').

.PARAMETER Direct
    Switch parameter. If specified, retrieves only direct group memberships for the user.

.OUTPUTS
    Returns AD group information as needed based on the mode of operation.

.EXAMPLE
    Get-PodeAuthADGroup -Connection $adConnection -Username "john.doe"
    # Retrieves all AD groups for the user "john.doe".

    Get-PodeAuthADGroup -Connection $adConnection -Username "jane.smith" -Direct
    # Retrieves only direct group memberships for the user "jane.smith".
#>
function Get-PodeAuthADGroup {
    param(
        [Parameter(Mandatory = $true)]
        $Connection,

        [Parameter()]
        [string]
        $DistinguishedName,

        [Parameter()]
        [string]
        $Username,

        [Parameter()]
        [ValidateSet('DirectoryServices', 'ActiveDirectory', 'OpenLDAP')]
        [string]
        $Provider,

        [switch]
        $Direct
    )

    if ($Direct) {
        return (Get-PodeAuthADGroupDirect -Connection $Connection -Username $Username -Provider $Provider)
    }

    return (Get-PodeAuthADGroupAll -Connection $Connection -DistinguishedName $DistinguishedName -Provider $Provider)
}

function Get-PodeAuthADGroupDirect {
    param(
        [Parameter(Mandatory = $true)]
        $Connection,

        [Parameter()]
        [string]
        $Username,

        [Parameter()]
        [ValidateSet('DirectoryServices', 'ActiveDirectory', 'OpenLDAP')]
        [string]
        $Provider
    )

    # create the query
    $query = "(&(objectCategory=person)(samaccountname=$($Username)))"
    $groups = @()

    # get the groups
    switch ($Provider.ToLowerInvariant()) {
        'openldap' {
            $result = (ldapsearch -x -LLL -H "$($Connection.Hostname)" -D "$($Connection.Username)" -w "$($Connection.Password)" -b "$($Connection.BaseDN)" -o ldif-wrap=no "$($query)" memberof)
            $groups = (Get-PodeOpenLdapValue -Lines $result -Property 'memberof' -All)
        }

        'activedirectory' {
            $groups = (Get-ADPrincipalGroupMembership -Identity $Username -Credential $Connection.Credential).distinguishedName
        }

        'directoryservices' {
            if ($null -eq $Connection.Searcher) {
                $Connection.Searcher = [System.DirectoryServices.DirectorySearcher]::new($Connection.Entry)
            }

            $Connection.Searcher.filter = $query
            $groups = @($Connection.Searcher.FindOne().Properties.memberof)
        }
    }

    $groups = @(foreach ($group in $groups) {
            if ($group -imatch '^CN=(?<group>.+?),') {
                $Matches['group']
            }
        })

    return $groups
}

function Get-PodeAuthADGroupAll {
    param(
        [Parameter(Mandatory = $true)]
        $Connection,

        [Parameter()]
        [string]
        $DistinguishedName,

        [Parameter()]
        [ValidateSet('DirectoryServices', 'ActiveDirectory', 'OpenLDAP')]
        [string]
        $Provider
    )

    # create the query
    $query = "(member:1.2.840.113556.1.4.1941:=$($DistinguishedName))"
    $groups = @()

    # get the groups
    switch ($Provider.ToLowerInvariant()) {
        'openldap' {
            $result = (ldapsearch -x -LLL -H "$($Connection.Hostname)" -D "$($Connection.Username)" -w "$($Connection.Password)" -b "$($Connection.BaseDN)" -o ldif-wrap=no "$($query)" samaccountname)
            $groups = (Get-PodeOpenLdapValue -Lines $result -Property 'sAMAccountName' -All)
        }

        'activedirectory' {
            $groups = (Get-ADObject -LDAPFilter $query -Credential $Connection.Credential).Name
        }

        'directoryservices' {
            if ($null -eq $Connection.Searcher) {
                $Connection.Searcher = [System.DirectoryServices.DirectorySearcher]::new($Connection.Entry)
            }

            $null = $Connection.Searcher.PropertiesToLoad.Add('samaccountname')
            $Connection.Searcher.filter = $query
            $groups = @($Connection.Searcher.FindAll().Properties.samaccountname)
        }
    }

    return $groups
}

function Get-PodeAuthDomainName {
    $domain = $null

    if (Test-PodeIsMacOS) {
        $domain = (scutil --dns | grep -m 1 'search domain\[0\]' | cut -d ':' -f 2)
    }
    elseif (Test-PodeIsUnix) {
        $domain = (dnsdomainname)
        if ([string]::IsNullOrWhiteSpace($domain)) {
            $domain = (/usr/sbin/realm list --name-only)
        }
    }
    else {
        $domain = $env:USERDNSDOMAIN
        if ([string]::IsNullOrWhiteSpace($domain)) {
            $domain = (Get-CimInstance -Class Win32_ComputerSystem -Verbose:$false).Domain
        }
    }

    if (![string]::IsNullOrEmpty($domain)) {
        $domain = $domain.Trim()
    }

    return $domain
}


function Get-PodeAuthWindowsADMethod {
    return {
        param($username, $password, $options)

        # using pscreds?
        if (($null -eq $options) -and ($username -is [pscredential])) {
            $_username = ([pscredential]$username).UserName
            $_password = ([pscredential]$username).GetNetworkCredential().Password
            $_options = [hashtable]$password
        }
        else {
            $_username = $username
            $_password = $password
            $_options = $options
        }

        # parse username to remove domains
        $_username = (($_username -split '@')[0] -split '\\')[-1]

        # validate and retrieve the AD user
        $noGroups = $_options.NoGroups
        $directGroups = $_options.DirectGroups
        $keepCredential = $_options.KeepCredential

        $result = Get-PodeAuthADResult `
            -Server $_options.Server `
            -Domain $_options.Domain `
            -SearchBase $_options.SearchBase `
            -Username $_username `
            -Password $_password `
            -Provider $_options.Provider `
            -NoGroups:$noGroups `
            -DirectGroups:$directGroups `
            -KeepCredential:$keepCredential

        # if there's a message, fail and return the message
        if (![string]::IsNullOrWhiteSpace($result.Message)) {
            return $result
        }

        # if there's no user, then, err, oops
        if (Test-PodeIsEmpty $result.User) {
            return @{ Message = 'An unexpected error occured' }
        }

        # is the user valid for any users/groups - if not, error!
        if (!(Test-PodeAuthUserGroup -User $result.User -Users $_options.Users -Groups $_options.Groups)) {
            return @{ Message = 'You are not authorised to access this website' }
        }

        # call additional scriptblock if supplied
        if ($null -ne $_options.ScriptBlock.Script) {
            $result = Invoke-PodeAuthInbuiltScriptBlock -User $result.User -ScriptBlock $_options.ScriptBlock.Script -UsingVariables $_options.ScriptBlock.UsingVariables
        }

        # return final result, this could contain a user obj, or an error message from custom scriptblock
        return $result
    }
}



function Import-PodeAuthADModule {
    if (!(Test-PodeIsWindows)) {
        # Active Directory module only available on Windows
        throw ($PodeLocale.adModuleWindowsOnlyExceptionMessage)
    }

    if (!(Test-PodeModuleInstalled -Name ActiveDirectory)) {
        # Active Directory module is not installed
        throw ($PodeLocale.adModuleNotInstalledExceptionMessage)
    }

    Import-Module -Name ActiveDirectory -Force -ErrorAction Stop
    Export-PodeModule -Name ActiveDirectory
}

function Get-PodeAuthADProvider {
    param(
        [switch]
        $OpenLDAP,

        [switch]
        $ADModule
    )

    # openldap (literal, or not windows)
    if ($OpenLDAP -or !(Test-PodeIsWindows)) {
        return 'OpenLDAP'
    }

    # ad module
    if ($ADModule) {
        return 'ActiveDirectory'
    }

    # ds
    return 'DirectoryServices'
}
