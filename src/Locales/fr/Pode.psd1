ConvertFrom-StringData -StringData @'
adModuleWindowsOnlyMessage = Le module Active Directory est uniquement disponible sur Windows
adModuleNotInstalledMessage = Le module Active Directory n'est pas installé
secretManagementModuleNotInstalledMessage = Le module Microsoft.PowerShell.SecretManagement n'est pas installé
secretVaultAlreadyRegisteredMessage = Un coffre-fort secret avec le nom '{0}' a déjà été enregistré lors de l'importation automatique des coffres-forts secrets
failedToOpenRunspacePoolMessage = Échec de l'ouverture de RunspacePool : {0}
cronExpressionInvalidMessage = L'expression Cron doit uniquement comporter 5 parties : {0}
invalidAliasFoundMessage = Alias {0} non valide trouvé : {1}
invalidAtomCharacterMessage = Caractère atomique non valide : {0}
minValueGreaterThanMaxMessage = La valeur minimale pour {0} ne doit pas être supérieure à la valeur maximale
minValueInvalidMessage = La valeur minimale '{0}' pour {1} n'est pas valide, elle doit être supérieure ou égale à {2}
maxValueInvalidMessage = La valeur maximale '{0}' pour {1} n'est pas valide, elle doit être inférieure ou égale à {2}
valueOutOfRangeMessage = La valeur '{0}' pour {1} n'est pas valide, elle doit être comprise entre {2} et {3}
daysInMonthExceededMessage = {0} n'a que {1} jours, mais {2} a été fourni
nextTriggerCalculationErrorMessage = Il semble que quelque chose ait mal tourné lors de la tentative de calcul de la prochaine date et heure de déclenchement : {0}
incompatiblePodeDllMessage = Une version incompatible existante de Pode.DLL {0} est chargée. La version {1} est requise. Ouvrez une nouvelle session Powershell/pwsh et réessayez.
endpointNotExistMessage = Un point de terminaison avec le protocole '{0}' et l'adresse '{1}' ou l'adresse locale '{2}' n'existe pas
endpointNameNotExistMessage = Un point de terminaison avec le nom '{0}' n'existe pas
failedToConnectToUrlMessage = Échec de la connexion à l'URL : {0}
failedToParseAddressMessage = Échec de l'analyse de '{0}' en tant qu'adresse IP/Hôte:Port valide
invalidIpAddressMessage = L'adresse IP fournie n'est pas valide : {0}
invalidPortMessage = Le port ne peut pas être négatif : {0}
pathNotExistMessage = Le chemin n'existe pas : {0}
'@