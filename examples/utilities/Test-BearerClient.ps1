
try {
    # Determine the script path and Pode module path
    $ScriptPath = (Split-Path -Parent -Path(Split-Path -Parent -Path $MyInvocation.MyCommand.Path))
    $podePath = Split-Path -Parent -Path $ScriptPath

    # Import the Pode module from the source path if it exists, otherwise from installed modules
    if (Test-Path -Path "$($podePath)/src/Pode.psm1" -PathType Leaf) {
        Import-Module "$($podePath)/src/Pode.psm1" -Force -ErrorAction Stop
    }
    else {
        Import-Module -Name 'Pode' -MaximumVersion 2.99 -ErrorAction Stop
    }
 
    # Define the key storage path
    $certsPath = Join-Path -Path $podePath -ChildPath '/examples/certs'
}
catch { throw }

$apiBaseUrl = 'http://localhost:8081/auth/bearer/jwt'

Write-Output '🔹 Starting JWT Authentication Tests...'
Write-Output "📁 Checking if certificates directory exists: $certsPath"

if (-Not (Test-Path $certsPath)) {
    Write-Error "❌ Certificate directory does not exist: $certsPath"
    Exit
}

$algorithms = 'RS256', 'RS384', 'RS512', 'PS256', 'PS384', 'PS512', 'ES256', 'ES384', 'ES512'
foreach ($alg in $algorithms) {
    Write-Output '-----------------------------------------------'
    Write-Output "🔍 Testing Algorithm: $alg"

    $privateKeyPath = if ($alg.StartsWith('PS')) {
        "$certsPath/$($alg.Replace('PS','RS'))-private.pem"
    }
    else {
        "$certsPath/$alg-private.pem"
    }

    if (-Not (Test-Path $privateKeyPath)) {
        Write-Warning "⚠️ Skipping $($alg): Private key file not found ($privateKeyPath)"
        Continue
    }

    Write-Output "📄 Loading Private Key: $privateKeyPath"

    try {
        $privateKey = Get-Content $privateKeyPath -Raw | ConvertTo-SecureString -AsPlainText -Force
        Write-Output "✅ Private key loaded successfully for $alg"
    }
    catch {
        Write-Error "❌ Failed to load private key for $($alg): $_"
        Continue
    }

    Write-Output "🛠️ Generating JWT for $alg..."

    try {
        $jwt = ConvertTo-PodeJwt -Algorithm $alg -PrivateKey $privateKey -Payload @{
            id       = 'id'
            name     = 'Morty'
            Type     = 'Human'
            username = 'morty'
        }
        Write-Output "✅ JWT successfully generated for $alg"
    }
    catch {
        Write-Error "❌ JWT generation failed for $($alg): $_"
        Continue
    }

    $headers = @{
        'Authorization' = "Bearer $jwt"
        'Accept'        = 'application/json'
    }

    $apiUrl = "$apiBaseUrl/$alg"
    Write-Output "🌐 Sending request to: $apiUrl"

    try {
        $response = Invoke-RestMethod -Uri $apiUrl -Method Get -Headers $headers
        Write-Output "✅ Response for $($alg): $($response | ConvertTo-Json -Depth 2)"
    }
    catch {
        Write-Error "❌ API request failed for $($alg): $_"
    }

    Write-Output '⏳ Waiting 10 seconds before next test...'
    Start-Sleep 10
}

Write-Output '🎉 All JWT authentication tests completed!'
