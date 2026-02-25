#Requires -Version 5.1
# Incremental sync using epoch timestamps — good for scheduled jobs — no module required
[CmdletBinding()]
param(
    [PSCredential] $Credential,
    [string]       $BaseUri   = 'https://dfs.site-iq.com',
    [long]         $Delta     = [long]([datetime]'2025-08-01T00:00:00Z' - [datetime]'1970-01-01T00:00:00Z').TotalSeconds
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

Write-Verbose "Fetching changes since epoch $Delta"

$Token   = Get-SiteIQToken -Cred $Credential -Uri $BaseUri
$Changed = @(Get-SiteIQTickets -Token $Token -Uri $BaseUri -Filter @{ status = 'All'; delta = $Delta })

Write-Verbose "Got $($Changed.Count) tickets"

$NextDelta = [long]([datetime]::UtcNow - [datetime]'1970-01-01T00:00:00Z').TotalSeconds
Write-Verbose "Next run, use -Delta $NextDelta"

$Changed
