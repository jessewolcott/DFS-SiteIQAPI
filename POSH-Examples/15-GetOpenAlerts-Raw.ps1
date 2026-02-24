# Get open alerts using raw Invoke-WebRequest — no module required
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

# Flatten to open alerts only
$openAlerts = foreach ($t in $tickets) {
    foreach ($a in $t.alerts) {
        if ($null -eq $a.alertCloseTimestamp) {
            [PSCustomObject]@{
                TicketID        = $t.ticketID
                SiteName        = $t.siteName
                Component       = $t.component
                Dispenser       = $t.dispenser
                Error           = $a.error
                FuelingPosition = $a.fuelingPosition
                AlertOpened     = $a.alertOpenTimestamp
            }
        }
    }
}

foreach ($alert in $openAlerts) {
    switch -Wildcard ($alert.Error) {
        'No Transaction*' { $NoTransaction.Add($alert) | Sort-Object SiteName }
        'Grade*'          { $LowFlow.Add($alert)| Sort-Object SiteName  }
        default           { $Unclassified.Add($alert) | Sort-Object SiteName  }
    }
}

$NoTransaction
$LowFlow
$Unclassified 
