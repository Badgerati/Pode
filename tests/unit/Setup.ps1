$PSModuleAutoloadingPreference = 'None'

# Import Pode Module
Import-Module './src/Pode.psm1' -Force

# Import Localized Data
Import-LocalizedData -BindingVariable PodeLocale -BaseDirectory './src/Locales' -FileName 'Pode'