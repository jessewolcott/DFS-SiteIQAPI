# Simplest query — default status is InProgress using raw Invoke-WebRequest — no module required
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

# Fetch in-progress tickets (API default: status=InProgress, last 30 days)
$resp    = Invoke-WebRequest -Uri "$baseUri/api/external/ticket" -Headers $headers
$tickets = $resp.Content | ConvertFrom-Json

Write-Host "Found $(@($tickets).Count) in-progress tickets"
$tickets | Format-Table ticketID, siteName, component, ticketStatus -AutoSize
