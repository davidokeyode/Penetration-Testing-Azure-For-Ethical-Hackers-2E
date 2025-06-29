# Define path to cookies.json
$cookieFile = "$env:USERPROFILE\Downloads\cookies.json"
if (-not (Test-Path $cookieFile)) {
    Write-Error "cookies.json not found in Downloads."
    exit 1
}

# Load and parse JSON
$data = Get-Content $cookieFile -Raw | ConvertFrom-Json

# Collect only necessary cookies
$parts = $data | Where-Object { $_.name -match '^(SID|HSID|SSID|SIDCC)$' } |
         ForEach-Object { "$($_.name)=$($_.value)" }

if (-not $parts) {
    Write-Error "No Google session cookies found."
    exit 1
}

# Build header string and set env var
$cookieHeader = $parts -join ';'
[Environment]::SetEnvironmentVariable('GOOGLE_COOKIES', $cookieHeader, 'Process')
Write-Host "GOOGLE_COOKIES set for this session."
