# Retrieve every alert across all tickets and display them as a flat list
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

$allAlerts = foreach ($t in $tickets) {
    foreach ($a in $t.alerts) {
        [PSCustomObject]@{
            TicketID        = $t.ticketID
            SiteName        = $t.siteName
            Component       = $t.component
            Dispenser       = $t.dispenser
            Error           = $a.error
            FuelingPosition = $a.fuelingPosition
            AlertOpened     = $a.alertOpenTimestamp
            AlertClosed     = $a.alertCloseTimestamp
            StillOpen       = $null -eq $a.alertCloseTimestamp
        }
    }
}

Write-Host "Total alerts: $(@($allAlerts).Count)"
$allAlerts | Where-Object { $_.StillOpen -eq $true } | Sort-Object SiteName | Format-Table -AutoSize