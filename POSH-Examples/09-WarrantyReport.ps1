# Warranty breakdown for open tickets
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

$tickets = Get-SiteIQTicket -Status InProgress -All

$inWarranty  = $tickets | Where-Object { $_.warrantyStatus -eq 'In' }
$outWarranty = $tickets | Where-Object { $_.warrantyStatus -eq 'Out' }

Write-Verbose "Under warranty:  $(@($inWarranty).Count)"
Write-Verbose "Out of warranty: $(@($outWarranty).Count)"

# Expiring within 30 days
$cutoff = (Get-Date).AddDays(30).ToString('yyyy-MM-dd')
$expiringSoon = $inWarranty | Where-Object { $_.warrantyDate -and $_.warrantyDate -le $cutoff }

if ($expiringSoon) {
    Write-Verbose "$(@($expiringSoon).Count) warranties expiring within 30 days:"
    $expiringSoon | Format-Table ticketID, siteName, warrantyDate, component -AutoSize
}

# Out-of-warranty by site
Write-Verbose "Out-of-warranty by site:"
$outWarranty |
    Group-Object siteName |
    Sort-Object Count -Descending |
    Format-Table Count, Name -AutoSize
