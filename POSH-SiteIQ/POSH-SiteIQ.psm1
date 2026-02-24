$script:Session = @{
    BaseUri = 'https://dfs.site-iq.com'
    Token   = $null
}

function Connect-SiteIQ {
    <#
    .SYNOPSIS
        Authenticates to the Site-IQ API and stores the session token.
    .PARAMETER Credential
        PSCredential with your Site-IQ email as the username.
    .PARAMETER BaseUri
        API base URL. Defaults to https://dfs.site-iq.com.
    .EXAMPLE
        Connect-SiteIQ -Credential (Get-Credential)
    .EXAMPLE
        $cred = Get-Credential
        Connect-SiteIQ -Credential $cred
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [PSCredential]$Credential,

        [string]$BaseUri = 'https://dfs.site-iq.com'
    )

    if (-not $PSCmdlet.ShouldProcess("$BaseUri as $($Credential.UserName)", 'Authenticate')) {
        return
    }

    $body = @{
        email    = $Credential.UserName
        password = $Credential.GetNetworkCredential().Password
    } | ConvertTo-Json

    $params = @{
        Uri         = "$BaseUri/api/web/auth/token"
        Method      = 'POST'
        ContentType = 'application/json'
        Body        = $body
    }

    Write-Verbose "POST $BaseUri/api/web/auth/token as $($Credential.UserName)"
    $response = Invoke-RestMethod @params

    $script:Session.BaseUri = $BaseUri
    $script:Session.Token   = $response.token

    Write-Verbose "Authenticated as $($Credential.UserName)"

    [PSCustomObject]@{
        Connected = $true
        Email     = $Credential.UserName
        BaseUri   = $BaseUri
    }
}


function Disconnect-SiteIQ {
    <#
    .SYNOPSIS
        Clears the stored Site-IQ session token.
    .EXAMPLE
        Disconnect-SiteIQ
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()

    if (-not $PSCmdlet.ShouldProcess('Site-IQ session token', 'Clear')) {
        return
    }

    $script:Session.Token = $null
    Write-Verbose 'Session token cleared'
}


function Get-SiteIQTicket {
    <#
    .SYNOPSIS
        Retrieves tickets from the Site-IQ API.
    .DESCRIPTION
        Queries tickets with optional filters for status, date range, delta
        sync, and pagination. Use -All to automatically page through results.
    .PARAMETER Status
        Ticket status filter. Defaults to InProgress.
    .PARAMETER StartDate
        Start of the date range. Defaults to 30 days ago server-side.
    .PARAMETER EndDate
        End of the date range. Defaults to today server-side.
    .PARAMETER Delta
        Epoch timestamp for incremental sync. Overrides date range.
    .PARAMETER PageLimit
        Tickets per page, 1-1000. Defaults to 1000.
    .PARAMETER PageOffset
        Zero-based page offset.
    .PARAMETER All
        Auto-pages through all results. Overrides PageLimit/PageOffset.
    .EXAMPLE
        Get-SiteIQTicket
    .EXAMPLE
        Get-SiteIQTicket -Status Closed -StartDate 2025-01-01 -EndDate 2025-01-31
    .EXAMPLE
        Get-SiteIQTicket -Status All -All
    .EXAMPLE
        Get-SiteIQTicket -Delta 1691179200
    #>
    [CmdletBinding(DefaultParameterSetName = 'DateRange', SupportsShouldProcess)]
    param(
        [ValidateSet('InProgress', 'Closed', 'Pending Closed', 'Dispatch', 'All')]
        [string]$Status,

        [Parameter(ParameterSetName = 'DateRange')]
        [datetime]$StartDate,

        [Parameter(ParameterSetName = 'DateRange')]
        [datetime]$EndDate,

        [Parameter(Mandatory, ParameterSetName = 'Delta')]
        [long]$Delta,

        [ValidateRange(1, 1000)]
        [int]$PageLimit = 1000,

        [ValidateRange(0, [int]::MaxValue)]
        [int]$PageOffset = 0,

        [switch]$All
    )

    if (-not $script:Session.Token) {
        throw 'Not connected to Site-IQ. Run Connect-SiteIQ first.'
    }

    $query = [ordered]@{}

    if ($Status) {
        $query['status'] = $Status
    }

    if ($PSCmdlet.ParameterSetName -eq 'Delta') {
        $query['delta'] = $Delta.ToString()
    }
    else {
        if ($StartDate) { $query['startDate'] = $StartDate.ToString('yyyy-MM-dd') }
        if ($EndDate)   { $query['endDate']   = $EndDate.ToString('yyyy-MM-dd') }
    }

    $headers = @{
        Authorization = "Bearer $($script:Session.Token)"
        Accept        = '*/*'
    }

    if ($All) {
        $offset = 0
        $hasMore = $true

        while ($hasMore) {
            $query['pageLimit']  = '1000'
            $query['pageOffset'] = $offset.ToString()

            $uri = BuildQueryUri $query

            if (-not $PSCmdlet.ShouldProcess($uri, 'GET')) {
                return
            }

            $params = @{
                Uri     = $uri
                Method  = 'GET'
                Headers = $headers
            }

            Write-Verbose "GET $uri (offset $offset)"
            $batch = @(Invoke-RestMethod @params)
            Write-Verbose "Got $($batch.Count) tickets"

            foreach ($ticket in $batch) {
                $ticket
            }

            if ($batch.Count -lt 1000) {
                $hasMore = $false
            }
            else {
                $offset = $offset + 1000
            }
        }
    }
    else {
        $query['pageLimit']  = $PageLimit.ToString()
        $query['pageOffset'] = $PageOffset.ToString()

        $uri = BuildQueryUri $query

        if (-not $PSCmdlet.ShouldProcess($uri, 'GET')) {
            return
        }

        $params = @{
            Uri     = $uri
            Method  = 'GET'
            Headers = $headers
        }

        Write-Verbose "GET $uri"
        Invoke-RestMethod @params
    }
}


function Test-SiteIQConnection {
    <#
    .SYNOPSIS
        Returns $true if a Site-IQ session token is stored, $false otherwise.
    .EXAMPLE
        if (Test-SiteIQConnection) { Get-SiteIQTicket }
    #>
    [CmdletBinding()]
    param()

    $null -ne $script:Session.Token
}

function BuildQueryUri {
    param([System.Collections.Specialized.OrderedDictionary]$Query)

    $pairs = foreach ($key in $Query.Keys) {
        [uri]::EscapeDataString($key) + '=' + [uri]::EscapeDataString($Query[$key])
    }

    "$($script:Session.BaseUri)/api/external/ticket?$($pairs -join '&')"
}
