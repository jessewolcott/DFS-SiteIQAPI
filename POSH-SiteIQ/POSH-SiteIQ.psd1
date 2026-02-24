@{
    RootModule        = 'POSH-SiteIQ.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = 'f3a7c8d1-6e2b-4f09-9a1d-8c5b3e7f2a04'
    Author            = 'Jesse Wolcott'
    CompanyName       = ''
    Description       = 'PowerShell wrapper for the Site-IQ Tickets External API'
    PowerShellVersion = '5.1'

    FunctionsToExport = @(
        'Connect-SiteIQ'
        'Disconnect-SiteIQ'
        'Get-SiteIQTicket'
        'Test-SiteIQConnection'
    )

    CmdletsToExport   = @()
    VariablesToExport  = @()
    AliasesToExport    = @()

    PrivateData = @{
        PSData = @{
            Tags = @('SiteIQ', 'Tickets', 'API')
        }
    }
}
