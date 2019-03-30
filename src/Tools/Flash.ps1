function Flash
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet('add', 'clear', 'get', 'keys', 'remove')]
        [Alias('a')]
        [string]
        $Action,

        [Parameter()]
        [Alias('k')]
        [string]
        $Key,

        [Parameter()]
        [Alias('m')]
        [string]
        $Message
    )

    # if sessions haven't been setup, error
    if ($null -eq $PodeContext.Server.Cookies.Session) {
        throw 'Sessions are required to use Flash messages'
    }

    if (@('add', 'get', 'remove') -icontains $Action -and (Test-Empty $Key)) {
        throw "A Key is required for the Flash $($Action) action"
    }

    # run logic for the action
    switch ($Action.ToLowerInvariant())
    {
        'add' {
            # append the message against the key
            if ($null -eq $WebEvent.Session.Data.Flash) {
                $WebEvent.Session.Data.Flash = @{}
            }

            if ($null -eq $WebEvent.Session.Data.Flash[$Key]) {
                $WebEvent.Session.Data.Flash[$Key] = @($Message)
            }
            else {
                $WebEvent.Session.Data.Flash[$Key] += @($Message)
            }
        }

        'get' {
            # retrieve messages from session, then delete it
            if ($null -eq $WebEvent.Session.Data.Flash) {
                return @()
            }

            $v = @($WebEvent.Session.Data.Flash[$Key])
            $WebEvent.Session.Data.Flash.Remove($Key)

            if (Test-Empty $v) {
                return @()
            }

            return @($v)
        }

        'keys' {
            # return list of all current keys
            if ($null -eq $WebEvent.Session.Data.Flash) {
                return @()
            }

            return @($WebEvent.Session.Data.Flash.Keys)
        }

        'clear' {
            # clear all keys
            if ($null -ne $WebEvent.Session.Data.Flash) {
                $WebEvent.Session.Data.Flash = @{}
            }
        }

        'remove' {
            # remove key from flash messages
            if ($null -ne $WebEvent.Session.Data.Flash) {
                $WebEvent.Session.Data.Flash.Remove($Key)
            }
        }
    }
}