#Requires -Version 5.1
# Manual pagination loop — no module required
[CmdletBinding()]
param(
    [PSCredential] $Credential,
    [string]       $BaseUri   = 'https://dfs.site-iq.com',
    [int]          $PageSize  = 50
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
$All     = [System.Collections.Generic.List[object]]::new()
$Offset  = 0

do {
    $Batch = @(Invoke-RestMethod -Uri "$BaseUri/api/external/ticket?status=All&pageLimit=$PageSize&pageOffset=$Offset" -Headers $Headers)
    foreach ($Ticket in $Batch) { $All.Add($Ticket) }
    Write-Verbose "  Offset $Offset : got $($Batch.Count)"
    $Offset += $PageSize
} while ($Batch.Count -eq $PageSize)

Write-Verbose "Total: $($All.Count) tickets"
$All
