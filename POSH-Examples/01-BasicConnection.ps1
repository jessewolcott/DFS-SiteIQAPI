# Basic connection lifecycle
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

Test-SiteIQConnection

Disconnect-SiteIQ
