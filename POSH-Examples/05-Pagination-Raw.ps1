# Manual pagination loop using raw Invoke-WebRequest — no module required
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

$headers = @{ Authorization = "Bearer $token" }

# Manual: 50 at a time
$pageSize = 50
$offset   = 0
$all      = [System.Collections.Generic.List[object]]::new()

do {
    $uri   = "$baseUri/api/external/ticket?status=All&pageLimit=$pageSize&pageOffset=$offset"
    $resp  = Invoke-WebRequest -Uri $uri -Headers $headers
    $batch = $resp.Content | ConvertFrom-Json
    foreach ($ticket in $batch) { $all.Add($ticket) }
    Write-Host "  Offset ${offset}: got $($batch.Count)"
    $offset += $pageSize
} while ($batch.Count -eq $pageSize)

Write-Host "Total: $($all.Count) tickets"
