#Requires -Version 5.1
# Simplest query — default status is InProgress, default window 30 days — no module required
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

# API defaults: status=InProgress, last 30 days — single page is sufficient for most sites
$Tickets = @(Invoke-RestMethod -Uri "$BaseUri/api/external/ticket" -Headers $Headers)

Write-Verbose "Found $($Tickets.Count) in-progress tickets"
$Tickets
