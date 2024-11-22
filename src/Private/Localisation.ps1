function Protect-PodeLocaleCulture {
    [OutputType([cultureinfo])]
    param(
        [Parameter()]
        [cultureinfo]
        $Culture = $null
    )

    # return the culture if it's already valid
    if ($null -ne $Culture) {
        return $Culture
    }

    # get the culture to use from the web event
    if ($null -ne $WebEvent.Culture) {
        return $WebEvent.Culture
    }

    # return the default culture
    return $PodeContext.Server.Localisation.Defaults.Culture
}

function Get-PodeLocaleAcceptLanguage {
    [OutputType([cultureinfo])]
    param()

    # return if there are no locales, or no Accept-Language header, or no auto-detect
    if (($PodeContext.Server.Localisation.Locales.Count -eq 0) -or
        !$PodeContext.Server.Localisation.AutoDetect -or
        $WebEvent.Request.AcceptLanguages.Count -eq 0) {
        return $null
    }

    # find a supported language
    foreach ($lang in $WebEvent.Request.AcceptLanguages.Keys) {
        if ($PodeContext.Server.Localisation.Locales.ContainsKey($lang)) {
            return [cultureinfo]$lang
        }
    }

    # if none supported, return null
    return $null
}

function Get-PodeLocaleCulture {
    [OutputType([cultureinfo])]
    param()

    # return if there are no locales, or if "disabled", return default culture
    if (!$PodeContext.Server.Localisation.Enabled -or ($PodeContext.Server.Localisation.Locales.Count -eq 0)) {
        return $PodeContext.Server.Localisation.Defaults.Culture
    }

    # check in cookies
    if (![string]::IsNullOrEmpty($PodeContext.Server.Localisation.Locations.CookieName)) {
        $cookie = Get-PodeCookie -Name $PodeContext.Server.Localisation.Locations.CookieName -Raw
        if ($null -ne $cookie) {
            return [cultureinfo]$cookie.Value
        }
    }

    # check in headers
    if (![string]::IsNullOrEmpty($PodeContext.Server.Localisation.Locations.HeaderName)) {
        $header = Get-PodeHeader -Name $PodeContext.Server.Localisation.Locations.HeaderName
        if (![string]::IsNullOrEmpty($header)) {
            return [cultureinfo]$header
        }
    }

    # check for key inside Session.Data
    if (![string]::IsNullOrEmpty($PodeContext.Server.Localisation.Locations.SessionKey) -and ($null -ne $WebEvent.Session.Data)) {
        $session = $WebEvent.Session.Data[$PodeContext.Server.Localisation.Locations.SessionKey]
        if (![string]::IsNullOrEmpty($session)) {
            return [cultureinfo]$session
        }
    }

    # check for key inside Auth.User
    if (![string]::IsNullOrEmpty($PodeContext.Server.Localisation.Locations.AuthKey) -and ($null -ne $WebEvent.Auth.User)) {
        $auth = $WebEvent.Auth.User[$PodeContext.Server.Localisation.Locations.AuthKey]
        if (![string]::IsNullOrEmpty($auth)) {
            return [cultureinfo]$auth
        }
    }

    # parse Accept-Language header and return if found - or return default
    $lang = Get-PodeLocaleAcceptLanguage
    if ($null -ne $lang) {
        return $lang
    }

    return $PodeContext.Server.Localisation.Defaults.Culture
}

function Add-PodeLocaleEndware {
    $WebEvent.OnEnd += @{
        Logic = {
            # set the Content-Language header to the default culture if not set
            if (($null -eq $WebEvent.Culture) -and !$WebEvent.IsLocalised) {
                Set-PodeHeader -Name 'Content-Language' -Value $PodeContext.Server.Localisation.Defaults.Culture.Name
            }
            else {
                Set-PodeHeader -Name 'Content-Language' -Value $WebEvent.Culture.Name
            }
        }
    }
}

function Protect-PodeLocaleDefaultCulture {
    # if default culture is not set, set it to en
    if ([string]::IsNullOrEmpty($PodeContext.Server.Localisation.Defaults.Culture.Name)) {
        $PodeContext.Server.Localisation.Defaults.Culture = [cultureinfo]'en'
    }

    # if there are no locales, just return
    if ($PodeContext.Server.Localisation.Locales.Count -eq 0) {
        return
    }

    # if the culture has a matching locale, return
    if (Test-PodeLocale -Culture $PodeContext.Server.Localisation.Defaults.Culture) {
        return
    }

    # set to parent, if present, and check again
    if (![string]::IsNullOrEmpty($PodeContext.Server.Localisation.Defaults.Culture.Parent.Name) -and
        (Test-PodeLocale -Culture $PodeContext.Server.Localisation.Defaults.Culture.Parent)) {
        $PodeContext.Server.Localisation.Defaults.Culture = $PodeContext.Server.Localisation.Defaults.Culture.Parent
        return
    }

    # if we get here, force to "en" and try again
    $PodeContext.Server.Localisation.Defaults.Culture = [cultureinfo]'en'
    if (Test-PodeLocale -Culture $PodeContext.Server.Localisation.Defaults.Culture) {
        return
    }

    # if we get here, set to first available locale
    $PodeContext.Server.Localisation.Defaults.Culture = [cultureinfo]$PodeContext.Server.Localisation.Locales.Keys[0]
}