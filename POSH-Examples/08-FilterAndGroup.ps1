# Pipeline filtering and grouping
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

# By component
Write-Verbose "Tickets by component:"
$tickets |
    Group-Object component |
    Sort-Object Count -Descending |
    Format-Table Count, Name -AutoSize

# Top 10 sites
Write-Verbose "Top 10 sites:"
$tickets |
    Group-Object siteName |
    Sort-Object Count -Descending |
    Select-Object -First 10 |
    Format-Table Count, Name -AutoSize

# Tickets with a lot of alerts
$tickets |
    Where-Object { @($_.alerts).Count -ge 3 } |
    Format-Table ticketID, siteName, component, @{
        Name       = 'Alerts'
        Expression = { @($_.alerts).Count }
    } -AutoSize

# Opened today
$todayStr = (Get-Date).ToString('yyyy-MM-dd')
$openedToday = $tickets | Where-Object { $_.ticketOpenTimestamp -like "$todayStr*" }
Write-Verbose "Opened today: $(@($openedToday).Count)"
