# Custom date range queries using raw Invoke-WebRequest — no module required
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

# Specific week
$uri     = "$baseUri/api/external/ticket?status=All&startDate=2025-01-01&endDate=2025-01-07"
$resp    = Invoke-WebRequest -Uri $uri -Headers $headers
$tickets = $resp.Content | ConvertFrom-Json

Write-Host "Jan 1-7 2025: $(@($tickets).Count) tickets"
$tickets | Format-Table ticketID, siteName, ticketStatus, component

# Last 7 days
$start  = (Get-Date).AddDays(-7).ToString('yyyy-MM-dd')
$end    = (Get-Date).ToString('yyyy-MM-dd')
$uri    = "$baseUri/api/external/ticket?status=All&startDate=$start&endDate=$end"
$resp   = Invoke-WebRequest -Uri $uri -Headers $headers
$recent = $resp.Content | ConvertFrom-Json

Write-Host "Last 7 days: $(@($recent).Count) tickets"
