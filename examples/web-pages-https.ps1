if ((Get-Module -Name Pode | Measure-Object).Count -ne 0)
{
    Remove-Module -Name Pode
}

$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -ErrorAction Stop

# or just:
# Import-Module Pode

#web-pages-https.ps1 example notes: 
#Adding a self-signed cert in this method (netsh) will only work on Windows.  Looking at httpcfg command on Unix, but currently running into some issues.
#This will not clear the binding after (netsh http delete sslcert 0.0.0.0:port), nor will it remove the certificate from the personal store.  Cleanup should be done manually as required.
#As this generates a self-signed cert for fqdn localhost, this is just for testing and proof of concept.

$port = 8443
# create a server with the https switch, and start listening on 8443
Server -Port $port -Https {
    #get all current sslcert bindings
    $bindings = netsh http show sslcert
    #check if selected port is already bound to an sslcert
    $sslPortInUse = $bindings | Where-Object{$_ -like "*IP:port*" -and $_ -like "*:$port"}
    #if port is not yet bound, create self signed cert, and bind it to all IPs (0.0.0.0)
    if(!$sslPortInUse){
        #create cert, store it in personal cert store
        $cert = New-SelfSignedCertificate -DnsName "localhost" -CertStoreLocation "cert:\LocalMachine\My"
        $ipport = "0.0.0.0:$port"
        #bind cert to ipport
        $result = netsh http add sslcert ipport=$ipport certhash=$($cert.Thumbprint) appid=`{00112233-4455-6677-8899-AABBCCDDEEFF`}
        #print result
        $output = $result.trim()
        write-host $output
    } else {
        write-host "sslcert already bound to $ipport"
        write-host "$sslPortInUse"
    }

    engine pode

    # GET request for web page on "https://localhost:8443/"
    route 'get' '/' {
        param($session)
        view 'simple' -Data @{ 'numbers' = @(1, 2, 3); }
    }

    # GET request throws fake "500" server error status code
    route 'get' '/error' {
        param($session)
        status 500
    }

}
