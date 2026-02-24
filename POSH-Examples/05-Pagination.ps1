# Manual pagination vs the -All switch
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

# Manual: 50 at a time
$pageSize = 50
$offset   = 0
$all      = [System.Collections.Generic.List[object]]::new()

do {
    $batch = @(Get-SiteIQTicket -Status All -PageLimit $pageSize -PageOffset $offset)

    foreach ($ticket in $batch) {
        $all.Add($ticket)
    }

    Write-Verbose "  Offset ${offset}: got $($batch.Count)"
    $offset = $offset + $pageSize

} while ($batch.Count -eq $pageSize)

Write-Verbose "Manual total: $($all.Count)"

# Or just let the module do it
$everything = Get-SiteIQTicket -Status All -All
Write-Verbose "Auto-paged total: $(@($everything).Count)"
