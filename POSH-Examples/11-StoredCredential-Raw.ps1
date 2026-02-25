#Requires -Version 5.1
# Non-interactive auth via DPAPI credential file — no module required
# Windows: encrypted with DPAPI (user + machine bound). macOS/Linux: prompts each run.
[CmdletBinding()]
param(
    [string] $BaseUri  = 'https://dfs.site-iq.com',
    [string] $StorePath = (Join-Path $HOME '.siteiq-cred.xml')
)

$ErrorActionPreference = 'Stop'

function Get-SiteIQToken ([PSCredential]$Cred, [string]$Uri) {
    $Body = @{ email = $Cred.UserName; password = $Cred.GetNetworkCredential().Password } |
            ConvertTo-Json
    try   { (Invoke-RestMethod -Uri "$Uri/api/web/auth/token" -Method Post -ContentType 'application/json' -Body $Body).token }
    catch { throw "Authentication failed for '$($Cred.UserName)': $($_.Exception.Message)" }
}

if (($env:OS -eq 'Windows_NT') -and (Test-Path $StorePath)) {
    $Credential = Import-Clixml -Path $StorePath
} else {
    $Credential = Get-Credential -Message 'Enter your Site-IQ credentials'
    if ($env:OS -eq 'Windows_NT') {
        $Credential | Export-Clixml -Path $StorePath
        Write-Verbose "Credential saved to $StorePath"
    }
}

$Token   = Get-SiteIQToken -Cred $Credential -Uri $BaseUri
$Headers = @{ Authorization = "Bearer $Token" }

$Tickets = @(Invoke-RestMethod -Uri "$BaseUri/api/external/ticket" -Headers $Headers)
Write-Verbose "Got $($Tickets.Count) in-progress tickets"
$Tickets
