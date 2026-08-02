$scraper = "d:\NewTakeonhacktracker\haveloc-scraper\haveloc-scraper.exe"

# Step 1: Login
$loginPayload = '{"mode":"login","username":"RA2311056010266","password":"Hinata@7704937211"}'
$loginResult = $loginPayload | & $scraper 2>&1
$loginObj = $loginResult | ConvertFrom-Json
Write-Host "Login success: $($loginObj.success)"

if (-not $loginObj.success) {
    Write-Host "Login error: $($loginObj.error)"
    exit 1
}

$token = $loginObj.token
$phaveloc = $loginObj.phaveloc
Write-Host "Phaveloc: $phaveloc"

# Step 2: Fetch multiple sections
$fetchPayload = @{
    mode = "fetch"
    token = $token
    phaveloc = $phaveloc
    sections = @("profile", "companies", "jobs", "notices", "tracker")
    uuid = "3c34169d-0082-4a64-8318-a9b2463767e0"
} | ConvertTo-Json -Compress

$fetchResult = $fetchPayload | & $scraper 2>&1
Write-Host "Raw fetch result (first 2000 chars):"
Write-Host $fetchResult.Substring(0, [Math]::Min(2000, $fetchResult.Length))
