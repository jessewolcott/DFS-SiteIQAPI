# Weekly report: pull open + closed, summarize, export to CSV
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

$session = Connect-SiteIQ -Credential $Credential

if (-not $session.Connected) {
    Write-Error 'Failed to connect.'
}

$weekAgo = (Get-Date).AddDays(-7)
$open   = Get-SiteIQTicket -Status InProgress -StartDate $weekAgo -All
$closed = Get-SiteIQTicket -Status Closed     -StartDate $weekAgo -All

Write-Verbose "Last 7 days - Open: $(@($open).Count), Closed: $(@($closed).Count)"

$report = foreach ($t in @($open) + @($closed)) {
    [PSCustomObject]@{
        TicketID   = $t.ticketID
        Site       = $t.siteName
        SiteID     = $t.siteID
        Address    = $t.address
        Status     = $t.ticketStatus
        Component  = $t.component
        Dispenser  = $t.dispenser
        Warranty   = $t.warrantyStatus
        Opened     = $t.ticketOpenTimestamp
        AlertCount = @($t.alerts).Count
        FirstAlert = ($t.alerts | Select-Object -First 1).error
    }
}

Write-Verbose "Top 5 sites by volume:"
$report |
    Group-Object Site |
    Sort-Object Count -Descending |
    Select-Object -First 5 |
    Format-Table Count, Name -AutoSize

Write-Verbose "By component:"
$report |
    Group-Object Component |
    Sort-Object Count -Descending |
    Format-Table Count, Name -AutoSize

$timestamp = (Get-Date).ToString('yyyy-MM-dd_HHmmss')
$csvPath = Join-Path $PSScriptRoot "WeeklyReport_$timestamp.csv"
$report | Export-Csv -Path $csvPath -NoTypeInformation
Write-Verbose "Saved to $csvPath"

Disconnect-SiteIQ
