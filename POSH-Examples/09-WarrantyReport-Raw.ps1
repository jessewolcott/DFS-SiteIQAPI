#Requires -Version 5.1
# Warranty breakdown for open tickets — no module required
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

$Token       = Get-SiteIQToken -Cred $Credential -Uri $BaseUri
$Tickets     = @(Get-SiteIQTickets -Token $Token -Uri $BaseUri -Filter @{ status = 'InProgress' })
$Cutoff      = (Get-Date).AddDays(30).ToString('yyyy-MM-dd')

$InWarranty   = @($Tickets | Where-Object { $_.warrantyStatus -eq 'In' })
$OutWarranty  = @($Tickets | Where-Object { $_.warrantyStatus -eq 'Out' })
$ExpiringSoon = @($InWarranty | Where-Object { $_.warrantyDate -and $_.warrantyDate -le $Cutoff })

Write-Verbose "Under warranty:  $($InWarranty.Count)"
Write-Verbose "Out of warranty: $($OutWarranty.Count)"
if ($ExpiringSoon.Count -gt 0) { Write-Verbose "$($ExpiringSoon.Count) warranties expiring within 30 days" }

[PSCustomObject]@{
    InWarrantyCount     = $InWarranty.Count
    OutWarrantyCount    = $OutWarranty.Count
    ExpiringSoon        = $ExpiringSoon
    OutOfWarrantyBySite = $OutWarranty | Group-Object siteName | Sort-Object Count -Descending
}
