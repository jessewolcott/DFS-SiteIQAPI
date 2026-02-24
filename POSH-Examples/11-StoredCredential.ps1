# Non-interactive auth using an encrypted credential file.
# On Windows the xml is encrypted with DPAPI (tied to your user + machine); on macOS/Linux credentials are prompted each run.
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$Path = (Join-Path $HOME '.siteiq-cred.xml')
)

Import-Module "$PSScriptRoot\..\POSH-SiteIQ" -Force

if (($IsWindows -or $PSEdition -eq 'Desktop') -and (Test-Path $Path)) {
    $cred = Import-Clixml -Path $Path
} else {
    $cred = Get-Credential -Message 'Enter your Site-IQ credentials'
    if ($IsWindows -or $PSEdition -eq 'Desktop') {
        $cred | Export-Clixml -Path $Path
        Write-Verbose "Credential saved to $Path"
    }
}
Connect-SiteIQ -Credential $cred

$tickets = Get-SiteIQTicket
Write-Verbose "Got $(@($tickets).Count) in-progress tickets"
