# Incremental sync using epoch timestamps.
# Good for scheduled jobs that only need what changed since last run.
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

$lastSync = [datetime]'2025-08-01T00:00:00Z'
$epoch = [long]($lastSync - [datetime]'1970-01-01T00:00:00Z').TotalSeconds

Write-Verbose "Fetching changes since $lastSync (epoch $epoch)"

$changed = Get-SiteIQTicket -Delta $epoch -All
Write-Verbose "Got $(@($changed).Count) tickets"
$changed | Format-Table ticketID, siteName, ticketStatus, component

# Save current time as the next delta marker
$nextDelta = [long]([datetime]::UtcNow - [datetime]'1970-01-01T00:00:00Z').TotalSeconds
Write-Verbose "Next run, use -Delta $nextDelta"
