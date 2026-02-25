# Incremental sync using epoch timestamps using raw Invoke-WebRequest — no module required
# Good for scheduled jobs that only need what changed since last run.
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

$lastSync = [datetime]'2025-08-01T00:00:00Z'
$epoch    = [long]($lastSync - [datetime]'1970-01-01T00:00:00Z').TotalSeconds

Write-Host "Fetching changes since $lastSync (epoch $epoch)"

# Paginate through all changed tickets
$pageSize = 1000
$offset   = 0
$changed  = [System.Collections.Generic.List[object]]::new()

do {
    $uri   = "$baseUri/api/external/ticket?status=All&delta=$epoch&pageLimit=$pageSize&pageOffset=$offset"
    $resp  = Invoke-WebRequest -Uri $uri -Headers $headers
    $batch = $resp.Content | ConvertFrom-Json
    foreach ($t in $batch) { $changed.Add($t) }
    $offset += $pageSize
} while ($batch.Count -eq $pageSize)

Write-Host "Got $($changed.Count) tickets"
$changed | Format-Table ticketID, siteName, ticketStatus, component

# Save current time as the next delta marker
$nextDelta = [long]([datetime]::UtcNow - [datetime]'1970-01-01T00:00:00Z').TotalSeconds
Write-Host "Next run, use delta=$nextDelta"
