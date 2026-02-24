# Flatten tickets and dump to CSV
[CmdletBinding(SupportsShouldProcess)]
param(
    [PSCredential]$Credential,

    [string]$OutPath
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

if (-not $OutPath) {
    $OutPath = Join-Path $PSScriptRoot 'SiteIQ-Tickets.csv'
}

Connect-SiteIQ -Credential $Credential

$tickets = Get-SiteIQTicket -Status All -All

# alerts is nested, so flatten to the fields you actually want
$flat = foreach ($t in $tickets) {
    [PSCustomObject]@{
        TicketID       = $t.ticketID
        Opened         = $t.ticketOpenTimestamp
        SiteID         = $t.siteID
        SiteName       = $t.siteName
        Company        = $t.companyName
        Address        = $t.address
        Status         = $t.ticketStatus
        Component      = $t.component
        Dispenser      = $t.dispenser
        WarrantyStatus = $t.warrantyStatus
        WarrantyDate   = $t.warrantyDate
        AlertCount     = @($t.alerts).Count
    }
}

$flat | Export-Csv -Path $OutPath -NoTypeInformation
Write-Verbose "Wrote $($flat.Count) rows to $OutPath"
