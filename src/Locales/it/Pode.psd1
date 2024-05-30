ConvertFrom-StringData -StringData @'
adModuleWindowsOnlyMessage = Il modulo di Active Directory è disponibile solo su Windows
adModuleNotInstalledMessage = Il modulo di Active Directory non è installato
secretManagementModuleNotInstalledMessage = Il modulo Microsoft.PowerShell.SecretManagement non è installato
secretVaultAlreadyRegisteredMessage = Una Secret Vault con il nome '{0}' è già stata registrata durante l'importazione automatica delle Secret Vaults
failedToOpenRunspacePoolMessage = Errore nell'apertura di RunspacePool: {0}
cronExpressionInvalidMessage = L'espressione Cron deve consistere solo di 5 parti: {0}
invalidAliasFoundMessage = Alias {0} non valido trovato: {1}
invalidAtomCharacterMessage = Carattere atomico non valido: {0}
minValueGreaterThanMaxMessage = Il valore minimo per {0} non deve essere maggiore del valore massimo
minValueInvalidMessage = Il valore minimo '{0}' per {1} non è valido, deve essere maggiore o uguale a {2}
maxValueInvalidMessage = Il valore massimo '{0}' per {1} non è valido, deve essere minore o uguale a {2}
valueOutOfRangeMessage = Il valore '{0}' per {1} non è valido, deve essere compreso tra {2} e {3}
daysInMonthExceededMessage = {0} ha solo {1} giorni, ma è stato fornito {2}
nextTriggerCalculationErrorMessage = Sembra che qualcosa sia andato storto nel tentativo di calcolare la prossima data e ora del trigger: {0}
incompatiblePodeDllMessage = È stata caricata una versione incompatibile esistente di Pode.DLL {0}. È richiesta la versione {1}. Aprire una nuova sessione di Powershell/pwsh e riprovare.
endpointNotExistMessage = Non esiste un endpoint con il protocollo '{0}' e l'indirizzo '{1}' o l'indirizzo locale '{2}'
endpointNameNotExistMessage = Non esiste un endpoint con il nome '{0}'
failedToConnectToUrlMessage = Errore nella connessione all'URL: {0}
failedToParseAddressMessage = Errore nell'analisi di '{0}' come indirizzo IP/Host:Porto valido
invalidIpAddressMessage = L'indirizzo IP fornito non è valido: {0}
invalidPortMessage = La porta non può essere negativa: {0}
pathNotExistMessage = Il percorso non esiste: {0}
'@