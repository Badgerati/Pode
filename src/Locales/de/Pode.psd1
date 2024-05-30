ConvertFrom-StringData -StringData @'
adModuleWindowsOnlyMessage = Das Active Directory-Modul ist nur unter Windows verfügbar
adModuleNotInstalledMessage = Das Active Directory-Modul ist nicht installiert
secretManagementModuleNotInstalledMessage = Das Microsoft.PowerShell.SecretManagement-Modul ist nicht installiert
secretVaultAlreadyRegisteredMessage = Ein Secret Vault mit dem Namen '{0}' wurde bereits beim automatischen Importieren von Secret Vaults registriert
failedToOpenRunspacePoolMessage = Fehler beim Öffnen des RunspacePool: {0}
cronExpressionInvalidMessage = Cron-Ausdruck sollte nur aus 5 Teilen bestehen: {0}
invalidAliasFoundMessage = Ungültiger {0} Alias gefunden: {1}
invalidAtomCharacterMessage = Ungültiges Atomzeichen: {0}
minValueGreaterThanMaxMessage = Der Mindestwert für {0} sollte nicht größer als der Höchstwert sein
minValueInvalidMessage = Der Mindestwert '{0}' für {1} ist ungültig, sollte größer oder gleich {2} sein
maxValueInvalidMessage = Der Höchstwert '{0}' für {1} ist ungültig, sollte kleiner oder gleich {2} sein
valueOutOfRangeMessage = Der Wert '{0}' für {1} ist ungültig, sollte zwischen {2} und {3} liegen
daysInMonthExceededMessage = {0} hat nur {1} Tage, aber {2} wurde angegeben
nextTriggerCalculationErrorMessage = Es scheint, dass beim Versuch, das nächste Trigger-Datum und die nächste Uhrzeit zu berechnen, etwas schiefgelaufen ist: {0}
incompatiblePodeDllMessage = Eine vorhandene inkompatible Version von Pode.DLL {0} ist geladen. Version {1} wird benötigt. Öffnen Sie eine neue Powershell/pwsh-Sitzung und versuchen Sie es erneut.
endpointNotExistMessage = Ein Endpunkt mit dem Protokoll '{0}' und der Adresse '{1}' oder der lokalen Adresse '{2}' existiert nicht
endpointNameNotExistMessage = Ein Endpunkt mit dem Namen '{0}' existiert nicht
failedToConnectToUrlMessage = Fehler beim Verbinden mit der URL: {0}
failedToParseAddressMessage = Fehler beim Parsen von '{0}' als gültige IP/Host:Port-Adresse
invalidIpAddressMessage = Die angegebene IP-Adresse ist ungültig: {0}
invalidPortMessage = Der Port kann nicht negativ sein: {0}
pathNotExistMessage = Pfad existiert nicht: {0}
'@