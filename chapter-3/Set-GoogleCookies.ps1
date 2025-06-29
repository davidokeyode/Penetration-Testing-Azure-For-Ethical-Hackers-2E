# Load JSON from the exported cookies.json file
$cookieFile = "$env:USERPROFILE\Downloads\cookies.json"
if (-Not (Test-Path $cookieFile)) {
    Write-Error "cookies.json not found in Downloads folder."
    exit 1
}

$cookieData = Get-Content $cookieFile -Raw | ConvertFrom-Json

# Build <name>=<value> string separated by semicolons
$cookieHeader = $cookieData |
    ForEach-Object {
        "$($_.name)=$($_.value)"
    } |
    Where-Object { $_ -match '^(SID|HSID|SSID|SIDCC)=' } |
    -join ";"

if (-Not $cookieHeader) {
    Write-Error "No Google cookies found in JSON."
    exit 1
}

# Set environment variable for the current session
[Environment]::SetEnvironmentVariable('GOOGLE_COOKIES', $cookieHeader, 'Process')
Write-Host "GOOGLE_COOKIES set successfully."
