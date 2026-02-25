# Non-interactive auth using an encrypted credential file with raw Invoke-WebRequest — no module required
# On Windows the xml is encrypted with DPAPI (tied to your user + machine); on macOS/Linux credentials are prompted each run.
$baseUri  = 'https://dfs.site-iq.com'
$credPath = Join-Path $HOME '.siteiq-cred.xml'

if (($IsWindows -or $PSEdition -eq 'Desktop') -and (Test-Path $credPath)) {
    $cred = Import-Clixml -Path $credPath
} else {
    $cred = Get-Credential -Message 'Enter your Site-IQ credentials'
    if ($IsWindows -or $PSEdition -eq 'Desktop') {
        $cred | Export-Clixml -Path $credPath
        Write-Host "Credential saved to $credPath"
    }
}

$plainPw = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
               [Runtime.InteropServices.Marshal]::SecureStringToBSTR($cred.Password))

# Authenticate
$authBody = @{ email = $cred.UserName; password = $plainPw } | ConvertTo-Json
$authResp  = Invoke-WebRequest -Uri "$baseUri/api/web/auth/token" `
                               -Method Post `
                               -ContentType 'application/json' `
                               -Body $authBody
$token = ($authResp.Content | ConvertFrom-Json).token

$headers = @{ Authorization = "Bearer $token" }

# Fetch in-progress tickets
$resp    = Invoke-WebRequest -Uri "$baseUri/api/external/ticket" -Headers $headers
$tickets = $resp.Content | ConvertFrom-Json

Write-Host "Got $(@($tickets).Count) in-progress tickets"
