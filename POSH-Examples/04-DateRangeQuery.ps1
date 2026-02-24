# Custom date range queries
[CmdletBinding(SupportsShouldProcess)]
param(
    [PSCredential]$Credential
)

Import-Module "$PSScriptRoot\..\POSH-SiteIQ" -Force

if (-not $Credential) {
    $credPath = Join-Path $HOME '.siteiq-cred.xml'
    if (($IsWindows -or $PSEdition -eq 'Desktop') -and (Test-Path $credPath)) {
        $Credential = Import-Clixml -Path $credPath
    } else {
        $Credential = Get-Credential -Message 'Enter your Site-IQ credentials'
        if ($IsWindows -or $PSEdition -eq 'Desktop') {
            $Credential | Export-Clixml -Path $credPath
        }
    }
}

Connect-SiteIQ -Credential $Credential

# Specific week
$tickets = Get-SiteIQTicket -Status All -StartDate '2025-01-01' -EndDate '2025-01-07'
Write-Verbose "Jan 1-7: $(@($tickets).Count) tickets"
$tickets | Format-Table ticketID, siteName, ticketStatus, component

# Last 7 days
$recent = Get-SiteIQTicket -Status All -StartDate (Get-Date).AddDays(-7) -EndDate (Get-Date)
Write-Verbose "Last 7 days: $(@($recent).Count) tickets"
