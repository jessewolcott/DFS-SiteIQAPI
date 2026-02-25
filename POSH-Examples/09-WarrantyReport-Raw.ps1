# Warranty breakdown for open tickets using raw Invoke-WebRequest — no module required
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

# Paginate through all in-progress tickets
$pageSize = 1000
$offset   = 0
$tickets  = [System.Collections.Generic.List[object]]::new()

do {
    $uri   = "$baseUri/api/external/ticket?status=InProgress&pageLimit=$pageSize&pageOffset=$offset"
    $resp  = Invoke-WebRequest -Uri $uri -Headers $headers
    $batch = $resp.Content | ConvertFrom-Json
    foreach ($t in $batch) { $tickets.Add($t) }
    $offset += $pageSize
} while ($batch.Count -eq $pageSize)

$inWarranty  = $tickets | Where-Object { $_.warrantyStatus -eq 'In' }
$outWarranty = $tickets | Where-Object { $_.warrantyStatus -eq 'Out' }

Write-Host "Under warranty:  $(@($inWarranty).Count)"
Write-Host "Out of warranty: $(@($outWarranty).Count)"

# Expiring within 30 days
$cutoff      = (Get-Date).AddDays(30).ToString('yyyy-MM-dd')
$expiringSoon = $inWarranty | Where-Object { $_.warrantyDate -and $_.warrantyDate -le $cutoff }

if ($expiringSoon) {
    Write-Host "$(@($expiringSoon).Count) warranties expiring within 30 days:"
    $expiringSoon | Format-Table ticketID, siteName, warrantyDate, component -AutoSize
}

# Out-of-warranty by site
Write-Host 'Out-of-warranty by site:'
$outWarranty |
    Group-Object siteName |
    Sort-Object Count -Descending |
    Format-Table Count, Name -AutoSize
