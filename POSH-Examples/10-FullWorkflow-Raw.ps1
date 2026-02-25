#Requires -Version 5.1
# Weekly report: pull open + closed, summarize, export to CSV — no module required
[CmdletBinding()]
param(
    [PSCredential] $Credential,
    [string]       $BaseUri  = 'https://dfs.site-iq.com',
    [string]       $OutDir   = $PSScriptRoot
)

$ErrorActionPreference = 'Stop'

function Get-SiteIQToken ([PSCredential]$Cred, [string]$Uri) {
    $Body = @{ email = $Cred.UserName; password = $Cred.GetNetworkCredential().Password } |
            ConvertTo-Json
    try   { (Invoke-RestMethod -Uri "$Uri/api/web/auth/token" -Method Post -ContentType 'application/json' -Body $Body).token }
    catch { throw "Authentication failed for '$($Cred.UserName)': $($_.Exception.Message)" }
}

function Get-SiteIQTickets ([string]$Token, [string]$Uri, [hashtable]$Filter = @{}) {
    $Headers  = @{ Authorization = "Bearer $Token" }
    $PageSize = 1000
    $Offset   = 0
    do {
        $Qs    = ($Filter + @{ pageLimit = $PageSize; pageOffset = $Offset }).GetEnumerator() |
                 ForEach-Object { "$($_.Key)=$($_.Value)" }
        $Batch = @(Invoke-RestMethod -Uri "$Uri/api/external/ticket?$($Qs -join '&')" -Headers $Headers)
        $Batch
        $Offset += $PageSize
    } while ($Batch.Count -eq $PageSize)
}

if (-not $Credential) {
    $CredPath = Join-Path $HOME '.siteiq-cred.xml'
    if (($env:OS -eq 'Windows_NT') -and (Test-Path $CredPath)) {
        $Credential = Import-Clixml -Path $CredPath
    } else {
        $Credential = Get-Credential -Message 'Enter your Site-IQ credentials'
        if ($env:OS -eq 'Windows_NT') { $Credential | Export-Clixml -Path $CredPath }
    }
}

$Token   = Get-SiteIQToken -Cred $Credential -Uri $BaseUri
$WeekAgo = (Get-Date).AddDays(-7).ToString('yyyy-MM-dd')

$Open   = @(Get-SiteIQTickets -Token $Token -Uri $BaseUri -Filter @{ status = 'InProgress'; startDate = $WeekAgo })
$Closed = @(Get-SiteIQTickets -Token $Token -Uri $BaseUri -Filter @{ status = 'Closed';     startDate = $WeekAgo })

Write-Verbose "Last 7 days — Open: $($Open.Count), Closed: $($Closed.Count)"

$Report = ($Open + $Closed) | ForEach-Object {
    $Alerts = @($_.alerts)
    [PSCustomObject]@{
        TicketID   = $_.ticketID
        Site       = $_.siteName
        SiteID     = $_.siteID
        Address    = $_.address
        Status     = $_.ticketStatus
        Component  = $_.component
        Dispenser  = $_.dispenser
        Warranty   = $_.warrantyStatus
        Opened     = $_.ticketOpenTimestamp
        AlertCount = $Alerts.Count
        FirstAlert = $Alerts[0].error
    }
}

$Timestamp = (Get-Date).ToString('yyyy-MM-dd_HHmmss')
$CsvPath   = Join-Path $OutDir "WeeklyReport_$Timestamp.csv"
$Report | Export-Csv -Path $CsvPath -NoTypeInformation
Write-Verbose "Saved $(@($Report).Count) rows to $CsvPath"

$Report
