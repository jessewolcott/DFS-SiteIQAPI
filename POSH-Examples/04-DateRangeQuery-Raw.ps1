#Requires -Version 5.1
# Custom date range queries — no module required
[CmdletBinding()]
param(
    [PSCredential] $Credential,
    [string]       $BaseUri = 'https://dfs.site-iq.com'
)

$ErrorActionPreference = 'Stop'

function Get-SiteIQToken ([PSCredential]$Cred, [string]$Uri) {
    $Body = @{ email = $Cred.UserName; password = $Cred.GetNetworkCredential().Password } |
            ConvertTo-Json
    try   { (Invoke-RestMethod -Uri "$Uri/api/web/auth/token" -Method Post -ContentType 'application/json' -Body $Body).token }
    catch { throw "Authentication failed for '$($Cred.UserName)': $($_.Exception.Message)" }
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
$Headers = @{ Authorization = "Bearer $Token" }

# Specific week
$JanTickets = @(Invoke-RestMethod -Uri "$BaseUri/api/external/ticket?status=All&startDate=2025-01-01&endDate=2025-01-07" -Headers $Headers)
Write-Verbose "Jan 1-7 2025: $($JanTickets.Count) tickets"
$JanTickets

# Rolling last 7 days
$Start  = (Get-Date).AddDays(-7).ToString('yyyy-MM-dd')
$End    = (Get-Date).ToString('yyyy-MM-dd')
$Recent = @(Invoke-RestMethod -Uri "$BaseUri/api/external/ticket?status=All&startDate=$Start&endDate=$End" -Headers $Headers)
Write-Verbose "Last 7 days ($Start – $End): $($Recent.Count) tickets"
$Recent
