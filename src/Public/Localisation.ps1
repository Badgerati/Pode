function Get-PodeLocaleValue {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [string]
        $Key,

        [Parameter()]
        [cultureinfo]
        $Culture = $null,

        [switch]
        $Recurse
    )

    # return empty if no locales
    if ($PodeContext.Server.Localisation.Locales.Count -eq 0) {
        return [string]::Empty
    }

    # get the culture to use
    $Culture = Protect-PodeLocaleCulture -Culture $Culture
    if ($WebEvent) {
        $WebEvent.IsLocalised = $true
    }

    # check if we have the culture and locale value
    if ($PodeContext.Server.Localisation.Locales.ContainsKey($Culture.Name) -and
        $PodeContext.Server.Localisation.Locales[$Culture.Name].ContainsKey($Key)) {
        return $PodeContext.Server.Localisation.Locales[$Culture.Name][$Key]
    }

    # do we want to recursively check parent/default?
    if ($Recurse) {
        # otherwise, check the parent culture
        if (![string]::IsNullOrEmpty($Culture.Parent.Name) -and
            $PodeContext.Server.Localisation.Locales.ContainsKey($Culture.Parent.Name) -and
            $PodeContext.Server.Localisation.Locales[$Culture.Parent.Name].ContainsKey($Key)) {
            return $PodeContext.Server.Localisation.Locales[$Culture.Parent.Name][$Key]
        }

        # otherwise, return the default culture
        if ($PodeContext.Server.Localisation.Locales.ContainsKey($PodeContext.Server.Localisation.Defaults.Culture.Name) -and
            $PodeContext.Server.Localisation.Locales[$PodeContext.Server.Localisation.Defaults.Culture.Name].ContainsKey($Key)) {
            return $PodeContext.Server.Localisation.Locales[$PodeContext.Server.Localisation.Defaults.Culture.Name][$Key]
        }
    }

    # otherwise, return empty
    return [string]::Empty
}

function Set-PodeLocaleDefaultCulture {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [cultureinfo]
        $Culture
    )

    $PodeContext.Server.Localisation.Defaults.Culture = $Culture
}

function Test-PodeLocale {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter()]
        [cultureinfo]
        $Culture = $null,

        [switch]
        $Recurse
    )

    # get the culture to use
    $Culture = Protect-PodeLocaleCulture -Culture $Culture

    # test culture exists
    if ($PodeContext.Server.Localisation.Locales.ContainsKey($Culture.Name)) {
        return $true
    }

    # do we want to recursively check parent/default?
    if ($Recurse) {
        # otherwise, check the parent culture
        if (![string]::IsNullOrEmpty($Culture.Parent.Name) -and
            $PodeContext.Server.Localisation.Locales.ContainsKey($Culture.Parent.Name)) {
            return $true
        }

        # otherwise, return the default culture
        if ($PodeContext.Server.Localisation.Locales.ContainsKey($PodeContext.Server.Localisation.Defaults.Culture.Name)) {
            return $true
        }
    }

    return $false
}

function Test-PodeLocaleValue {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter()]
        [string]
        $Key,

        [Parameter()]
        [cultureinfo]
        $Culture = $null,

        [switch]
        $Recurse
    )

    # get the culture to use
    $Culture = Protect-PodeLocaleCulture -Culture $Culture

    # test locale value exists
    if ($PodeContext.Server.Localisation.Locales.ContainsKey($Culture.Name) -and
        $PodeContext.Server.Localisation.Locales[$Culture.Name].ContainsKey($Key)) {
        return $true
    }

    # do we want to recursively check parent/default?
    if ($Recurse) {
        # otherwise, check the parent culture
        if (![string]::IsNullOrEmpty($Culture.Parent.Name) -and
            $PodeContext.Server.Localisation.Locales.ContainsKey($Culture.Parent.Name) -and
            $PodeContext.Server.Localisation.Locales[$Culture.Parent.Name].ContainsKey($Key)) {
            return $true
        }

        # otherwise, return the default culture
        if ($PodeContext.Server.Localisation.Locales.ContainsKey($PodeContext.Server.Localisation.Defaults.Culture.Name) -and
            $PodeContext.Server.Localisation.Locales[$PodeContext.Server.Localisation.Defaults.Culture.Name].ContainsKey($Key)) {
            return $true
        }
    }

    return $false
}

function Initialize-PodeLocale {
    [CmdletBinding()]
    param(
        [Parameter()]
        [cultureinfo]
        $DefaultCulture = $null,

        [Parameter()]
        [string]
        $CookieName = $null,

        [Parameter()]
        [string]
        $HeaderName = $null,

        [Parameter()]
        [string]
        $SessionKey = $null,

        [Parameter()]
        [string]
        $AuthKey = $null,

        [Parameter()]
        [ValidateSet('ShortDate', 'LongDate', 'MonthDay', 'YearMonth')]
        [string]
        $DateFormat,

        [Parameter()]
        [ValidateSet('ShortTime', 'LongTime')]
        [string]
        $TimeFormat,

        [Parameter()]
        [ValidateSet('FullDateTime', 'RFC1123', 'SortableDateTime', 'UniversalSortableDateTime')]
        [string]
        $DateTimeFormat,

        [switch]
        $NoAutoDetect,

        [switch]
        $NoAutoImport
    )

    # set the default culture
    if ($null -ne $DefaultCulture) {
        Set-PodeLocaleDefaultCulture -Culture $DefaultCulture
    }

    # set the localisation settings
    $PodeContext.Server.Localisation.Locations = @{
        CookieName = $CookieName
        HeaderName = $HeaderName
        SessionKey = $SessionKey
        AuthKey    = $AuthKey
    }

    # set default formats if supplied
    if (![string]::IsNullOrEmpty($DateFormat)) {
        $PodeContext.Server.Localisation.Defaults.DateFormat = $DateFormat
    }

    if (![string]::IsNullOrEmpty($TimeFormat)) {
        $PodeContext.Server.Localisation.Defaults.TimeFormat = $TimeFormat
    }

    if (![string]::IsNullOrEmpty($DateTimeFormat)) {
        $PodeContext.Server.Localisation.Defaults.DateTimeFormat = $DateTimeFormat
    }

    # update auto-import settings
    $PodeContext.Server.AutoImport.Locales.Enabled = !$NoAutoImport.IsPresent
}

function Enable-PodeLocale {
    [CmdletBinding()]
    param()

    $PodeContext.Server.Localisation.Enabled = $true
}

function Disable-PodeLocale {
    [CmdletBinding()]
    param()

    $PodeContext.Server.Localisation.Enabled = $false
}

function Import-PodeLocaleData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]
        $Path,

        [Parameter()]
        [cultureinfo[]]
        $Culture = $null
    )

    # loop through each path and load the locale data
    foreach ($_path in $Path) {
        # use default, or custom path
        $_path = Get-PodeRelativePath -Path $_path -JoinRoot

        # fail if path not found
        if (!(Test-Path -Path $_path)) {
            # "Path to load $($DefaultPath) not found: $($Path)"
            throw ($PodeLocale.pathToLoadNotFoundExceptionMessage -f 'locales', $_path)
        }

        # if path isn't a directory, fail
        if (!(Test-Path -Path $_path -PathType Container)) {
            #TODO: "Path to load $($DefaultPath) is not a directory: $($Path)"
            throw ($PodeLocale.pathToLoadNotDirectoryExceptionMessage -f 'locales', $_path)
        }

        # get the initial child sub-directories
        $dirs = Get-ChildItem -Path $_path -Directory -Force

        # for each, check if the directory is a culture, then load the psd1 data
        foreach ($dir in $dirs) {
            try {
                $_culture = [cultureinfo]$dir.Name
            }
            catch {
                #TODO: "Invalid culture directory found: $($dir.Name)"
                throw ($PodeLocale.invalidCultureDirectoryFoundExceptionMessage -f $dir.Name)
            }

            # if a culture is specified, and it doesn't match, skip
            if (!(Test-PodeIsEmpty $Culture) -and ($Culture -notcontains $_culture)) {
                continue
            }

            # add the culture
            if (!$PodeContext.Server.Localisation.Locales.ContainsKey($_culture.Name)) {
                $PodeContext.Server.Localisation.Locales[$_culture.Name] = @{}
            }

            # get the locale data
            foreach ($file in (Get-ChildItem -Path $dir.FullName -Filter *.psd1 -File -Recurse -Force)) {
                # add the locale data
                $localeData = Import-PowerShellDataFile -Path $file.FullName

                foreach ($key in $localeData.Keys) {
                    $PodeContext.Server.Localisation.Locales[$_culture.Name][$key] = $localeData[$key]
                }
            }
        }
    }
}

function Convert-PodeLocaleDate {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [datetime]
        $Value,

        [Parameter()]
        [cultureinfo]
        $Culture = $null,

        [Parameter()]
        [ValidateSet('Default', 'ShortDate', 'LongDate', 'MonthDay', 'YearMonth')]
        [string]
        $Format = 'Default'
    )

    # get the culture to use
    $Culture = Protect-PodeLocaleCulture -Culture $Culture

    # get default format
    if ($Format -ieq 'Default') {
        $Format = $PodeContext.Server.Localisation.Defaults.DateFormat
    }

    # convert the date
    if ($WebEvent) {
        $WebEvent.IsLocalised = $true
    }

    return $Value.ToString($Culture.DateTimeFormat."$($Format)Pattern", $Culture)
}

function Convert-PodeLocaleTime {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [datetime]
        $Value,

        [Parameter()]
        [cultureinfo]
        $Culture = $null,

        [Parameter()]
        [ValidateSet('Default', 'ShortTime', 'LongTime')]
        [string]
        $Format = 'Default'
    )

    # get the culture to use
    $Culture = Protect-PodeLocaleCulture -Culture $Culture

    # get default format
    if ($Format -ieq 'Default') {
        $Format = $PodeContext.Server.Localisation.Defaults.TimeFormat
    }

    # convert the time
    if ($WebEvent) {
        $WebEvent.IsLocalised = $true
    }

    return $Value.ToString($Culture.DateTimeFormat."$($Format)Pattern", $Culture)
}

function Convert-PodeLocaleDateTime {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [datetime]
        $Value,

        [Parameter()]
        [cultureinfo]
        $Culture = $null,

        [Parameter()]
        [ValidateSet('Default', 'FullDateTime', 'RFC1123', 'SortableDateTime', 'UniversalSortableDateTime')]
        [string]
        $Format = 'Default'
    )

    # get the culture to use
    $Culture = Protect-PodeLocaleCulture -Culture $Culture

    # get default format
    if ($Format -ieq 'Default') {
        $Format = $PodeContext.Server.Localisation.Defaults.DateTimeFormat
    }

    # convert to UTC for RFC1123
    if ($Format -ieq 'RFC1123') {
        $Value = $Value.ToUniversalTime()
    }

    # convert the datetime
    if ($WebEvent) {
        $WebEvent.IsLocalised = $true
    }

    return $Value.ToString($Culture.DateTimeFormat."$($Format)Pattern", $Culture)
}

function Convert-PodeLocaleNumber {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [double]
        $Value,

        [Parameter()]
        [cultureinfo]
        $Culture = $null
    )

    # get the culture to use
    $Culture = Protect-PodeLocaleCulture -Culture $Culture

    # convert the number
    if ($WebEvent) {
        $WebEvent.IsLocalised = $true
    }

    return $Value.ToString('N', $Culture.NumberFormat)
}

function Get-PodeLocale {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [cultureinfo]
        $Culture,

        [switch]
        $Recurse
    )

    $Culture = Protect-PodeLocaleCulture -Culture $Culture

    # return the locale if exists
    $locale = $PodeContext.Server.Localisation.Locales[$Culture.Name]
    if ($null -ne $locale) {
        return $locale
    }

    # do we want to recursively check parent/default?
    if ($Recurse) {
        # otherwise, check the parent culture
        if (![string]::IsNullOrEmpty($Culture.Parent.Name)) {
            $locale = $PodeContext.Server.Localisation.Locales[$Culture.Parent.Name]
            if ($null -ne $locale) {
                return $locale
            }
        }

        # otherwise, return the default culture
        $locale = $PodeContext.Server.Localisation.Locales[$PodeContext.Server.Localisation.Defaults.Culture.Name]
        if ($null -ne $locale) {
            return $locale
        }
    }

    return $null
}

function Remove-PodeLocale {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [cultureinfo]
        $Culture
    )

    # remove the locale
    $PodeContext.Server.Localisation.Locales.Remove($Culture.Name)
}

function Add-PodeLocale {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [cultureinfo]
        $Culture,

        [Parameter(Mandatory = $true)]
        [hashtable]
        $Value
    )

    # check the culture pre-exists
    if (!$PodeContext.Server.Localisation.Locales.ContainsKey($Culture.Name)) {
        $PodeContext.Server.Localisation.Locales[$Culture.Name] = @{}
    }

    # loop and add the locale
    foreach ($key in $Value.Keys) {
        $PodeContext.Server.Localisation.Locales[$Culture.Name][$key] = $Value[$key]
    }
}