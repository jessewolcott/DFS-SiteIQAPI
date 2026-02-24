# Simplest query - default status is InProgress, default window is 30 days
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

$tickets = Get-SiteIQTicket

Write-Verbose "Found $(@($tickets).Count) in-progress tickets"
$tickets | Format-Table ticketID, siteName, component, ticketStatus -AutoSize
