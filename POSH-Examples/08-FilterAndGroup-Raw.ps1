# Pipeline filtering and grouping using raw Invoke-WebRequest — no module required
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

# By component
Write-Host 'Tickets by component:'
$tickets |
    Group-Object component |
    Sort-Object Count -Descending |
    Format-Table Count, Name -AutoSize

# Top 10 sites
Write-Host 'Top 10 sites:'
$tickets |
    Group-Object siteName |
    Sort-Object Count -Descending |
    Select-Object -First 10 |
    Format-Table Count, Name -AutoSize

# Tickets with 3+ alerts
$tickets |
    Where-Object { @($_.alerts).Count -ge 3 } |
    Format-Table ticketID, siteName, component, @{
        Name       = 'Alerts'
        Expression = { @($_.alerts).Count }
    } -AutoSize

# Opened today
$todayStr    = (Get-Date).ToString('yyyy-MM-dd')
$openedToday = $tickets | Where-Object { $_.ticketOpenTimestamp -like "$todayStr*" }
Write-Host "Opened today: $(@($openedToday).Count)"
