# Weekly report: pull open + closed, summarize, export to CSV using raw Invoke-WebRequest — no module required
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

if (-not $token) { Write-Error 'Failed to connect.'; exit 1 }

$headers = @{ Authorization = "Bearer $token" }
$weekAgo = (Get-Date).AddDays(-7).ToString('yyyy-MM-dd')

# Helper: paginate a single status+startDate query
function Get-AllPages ($status, $startDate) {
    $pageSize = 1000
    $offset   = 0
    $result   = [System.Collections.Generic.List[object]]::new()
    do {
        $uri   = "$baseUri/api/external/ticket?status=$status&startDate=$startDate&pageLimit=$pageSize&pageOffset=$offset"
        $resp  = Invoke-WebRequest -Uri $uri -Headers $headers
        $batch = $resp.Content | ConvertFrom-Json
        foreach ($t in $batch) { $result.Add($t) }
        $offset += $pageSize
    } while ($batch.Count -eq $pageSize)
    return $result
}

$open   = Get-AllPages 'InProgress' $weekAgo
$closed = Get-AllPages 'Closed'     $weekAgo

Write-Host "Last 7 days — Open: $($open.Count), Closed: $($closed.Count)"

$all = [System.Collections.Generic.List[object]]::new()
foreach ($t in @($open) + @($closed)) { $all.Add($t) }

$report = foreach ($t in $all) {
    [PSCustomObject]@{
        TicketID   = $t.ticketID
        Site       = $t.siteName
        SiteID     = $t.siteID
        Address    = $t.address
        Status     = $t.ticketStatus
        Component  = $t.component
        Dispenser  = $t.dispenser
        Warranty   = $t.warrantyStatus
        Opened     = $t.ticketOpenTimestamp
        AlertCount = @($t.alerts).Count
        FirstAlert = ($t.alerts | Select-Object -First 1).error
    }
}

Write-Host 'Top 5 sites by volume:'
$report |
    Group-Object Site |
    Sort-Object Count -Descending |
    Select-Object -First 5 |
    Format-Table Count, Name -AutoSize

Write-Host 'By component:'
$report |
    Group-Object Component |
    Sort-Object Count -Descending |
    Format-Table Count, Name -AutoSize

$timestamp = (Get-Date).ToString('yyyy-MM-dd_HHmmss')
$csvPath   = Join-Path $PSScriptRoot "WeeklyReport_$timestamp.csv"
$report | Export-Csv -Path $csvPath -NoTypeInformation
Write-Host "Saved to $csvPath"
