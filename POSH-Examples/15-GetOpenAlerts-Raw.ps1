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

# Classify alerts by error type
$NoTransaction = [System.Collections.Generic.List[object]]::new()
$LowFlow       = [System.Collections.Generic.List[object]]::new()
$Unclassified  = [System.Collections.Generic.List[object]]::new()

foreach ($alert in $openAlerts) {
    switch -Wildcard ($alert.Error) {
        'No Transaction*' {
            $NoTransaction.Add($alert)
            break
        }
        'Grade*' {
            $parts   = $alert.Error -split '\s*:\s*'
            $siteNum = ($alert.SiteName -replace '-.*$').Trim()
            $LowFlow.Add([PSCustomObject]@{
                TicketID        = $alert.TicketID
                SiteID          = $siteNum.PadLeft(4, '0')
                SiteName        = $alert.SiteName
                Component       = $alert.Component
                Dispenser       = $alert.Dispenser
                Product         = $parts[0].Trim()
                FlowRate        = $parts[1].Trim()
                Error           = $alert.Error
                FuelingPosition = $alert.FuelingPosition
                AlertOpened     = $alert.AlertOpened
            })
            break
        }
        default {
            $Unclassified.Add($alert)
        }
    }
}

$NoTransaction | Sort-Object SiteName
$LowFlow       | Sort-Object SiteName | ft 
$Unclassified  | Sort-Object SiteName
