# Retrieve only unresolved (still-open) alerts across all tickets
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

$tickets = Get-SiteIQTicket -Status All -All

$openAlerts = foreach ($t in $tickets) {
    foreach ($a in $t.alerts) {
        if ($null -eq $a.alertCloseTimestamp) {
            [PSCustomObject]@{
                TicketID        = $t.ticketID
                SiteName        = $t.siteName
                Component       = $t.component
                Dispenser       = $t.dispenser
                Error           = $a.error
                FuelingPosition = $a.fuelingPosition
                AlertOpened     = $a.alertOpenTimestamp
            }
        }
    }
}

Write-Host "Open alerts: $(@($openAlerts).Count)"
$openAlerts | Sort-Object SiteName | Format-Table -AutoSize
