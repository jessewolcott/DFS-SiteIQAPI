# Flatten nested alerts to find error patterns across sites
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

Write-Verbose "Total alerts: $(@($allAlerts).Count)"

Write-Verbose "Top 10 error types:"
$allAlerts |
    Group-Object Error |
    Sort-Object Count -Descending |
    Select-Object -First 10 |
    Format-Table Count, Name -AutoSize

$openAlerts = $allAlerts | Where-Object StillOpen
Write-Verbose "Still open: $(@($openAlerts).Count)"

Write-Verbose "Fueling positions with 5+ alerts:"
$allAlerts |
    Group-Object FuelingPosition |
    Where-Object { $_.Count -ge 5 } |
    Sort-Object Count -Descending |
    Format-Table Count, Name -AutoSize
