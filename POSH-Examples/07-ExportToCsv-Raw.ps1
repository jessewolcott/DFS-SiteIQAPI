# Flatten tickets and dump to CSV using raw Invoke-WebRequest — no module required
$baseUri = 'https://dfs.site-iq.com'
$OutPath = Join-Path $PSScriptRoot 'SiteIQ-Tickets.csv'

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

# Flatten — alerts is nested, so only ticket-level fields go to CSV
$flat = foreach ($t in $tickets) {
    [PSCustomObject]@{
        TicketID       = $t.ticketID
        Opened         = $t.ticketOpenTimestamp
        SiteID         = $t.siteID
        SiteName       = $t.siteName
        Company        = $t.companyName
        Address        = $t.address
        Status         = $t.ticketStatus
        Component      = $t.component
        Dispenser      = $t.dispenser
        WarrantyStatus = $t.warrantyStatus
        WarrantyDate   = $t.warrantyDate
        AlertCount     = @($t.alerts).Count
    }
}

$flat | Export-Csv -Path $OutPath -NoTypeInformation
Write-Host "Wrote $($flat.Count) rows to $OutPath"
