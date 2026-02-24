# Closed tickets from the last 30 days, sorted newest first
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

$closed = Get-SiteIQTicket -Status Closed

Write-Verbose "Found $(@($closed).Count) closed tickets"

$closed |
    Sort-Object ticketOpenTimestamp -Descending |
    Select-Object -First 20 |
    Format-Table ticketID, siteName, component, dispenser, ticketStatus
