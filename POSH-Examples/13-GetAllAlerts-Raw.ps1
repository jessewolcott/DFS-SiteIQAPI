# Pull every alert across all tickets using raw Invoke-WebRequest — no module required
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

# Paginate through all tickets
$pageSize = 1000
$offset   = 0
$tickets  = [System.Collections.Generic.List[object]]::new()

do {
    $uri   = "$baseUri/api/external/ticket?status=All&pageLimit=$pageSize&pageOffset=$offset"
    $resp  = Invoke-WebRequest -Uri $uri -Headers $headers
    $batch = $resp.Content | ConvertFrom-Json
    foreach ($t in $batch) { $tickets.Add($t) }
    $offset += $pageSize
} while ($batch.Count -eq $pageSize)

# Flatten all alerts
$allAlerts = foreach ($t in $tickets) {
    foreach ($a in $t.alerts) {
        [PSCustomObject]@{
            TicketID        = $t.ticketID
            SiteName        = $t.siteName
            Component       = $t.component
            Dispenser       = $t.dispenser
            Error           = $a.error
            FuelingPosition = $a.fuelingPosition
            AlertOpened     = $a.alertOpenTimestamp
            AlertClosed     = $a.alertCloseTimestamp
            StillOpen       = $null -eq $a.alertCloseTimestamp
        }
    }
}

Write-Host "Total alerts: $(@($allAlerts).Count)"
$allAlerts | Sort-Object SiteName | Format-Table -AutoSize
