# Basic connection lifecycle using raw Invoke-WebRequest — no module required
$baseUri = 'https://dfs.site-iq.com'

# Credentials
$email    = Read-Host 'Site-IQ email'
$password = Read-Host 'Password' -AsSecureString
$plainPw  = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
                [Runtime.InteropServices.Marshal]::SecureStringToBSTR($password))

# Authenticate
$authBody = @{ email = $email; password = $plainPw } | ConvertTo-Json
$authResp  = Invoke-WebRequest -Uri "$baseUri/api/web/auth/token" `
                               -Method Post `
                               -ContentType 'application/json' `
                               -Body $authBody
$token = ($authResp.Content | ConvertFrom-Json).token

Write-Host "Connected:  $true"
Write-Host "Email:      $email"
Write-Host "Base URI:   $baseUri"
Write-Host "Has token:  $($null -ne $token -and $token -ne '')"

# Tokens are short-lived; there is no explicit logout endpoint
Write-Host 'Disconnected (token discarded)'
