# Local repro: login_and_fetch vs login+cold-fetch (the Render failure mode).
# Usage:
#   $env:SRM_EMAIL="you@srmist.edu.in"
#   $env:SRM_PASSWORD="..."
#   .\scripts\probe-login-fetch.ps1

$ErrorActionPreference = "Stop"
$bin = Join-Path $PSScriptRoot "..\loginprobe.exe"
if (-not (Test-Path $bin)) {
  Push-Location (Join-Path $PSScriptRoot "..")
  go build -o loginprobe.exe ./cmd/loginprobe
  Pop-Location
}

$email = $env:SRM_EMAIL
$password = $env:SRM_PASSWORD
if (-not $email -or -not $password) {
  Write-Error "Set SRM_EMAIL and SRM_PASSWORD env vars first."
}

function Invoke-Probe($payload) {
  $json = $payload | ConvertTo-Json -Compress -Depth 8
  $out = $json | & $bin 2>&1
  $text = ($out | Out-String)
  try {
    return ($text | ConvertFrom-Json)
  } catch {
    Write-Host $text
    throw
  }
}

Write-Host "`n=== A) login_and_fetch (same process) ==="
$a = Invoke-Probe @{
  mode = "login_and_fetch"
  email = $email
  password = $password
  sections = @("studentInfo", "attendance")
}
Write-Host ("success={0} class={1} cookies={2} attendanceRows={3} error={4}" -f `
  $a.success, $a.classification, @($a.cookieNames).Count, @($a.data.attendance).Count, $a.error)

Write-Host "`n=== B) login only, then cold fetch (old Render path) ==="
$login = Invoke-Probe @{
  mode = "login"
  email = $email
  password = $password
}
Write-Host ("login success={0} class={1} cookies={2} error={3}" -f `
  $login.success, $login.classification, @($login.cookieNames).Count, $login.error)

if (-not $login.success) { exit 1 }

$fetch = Invoke-Probe @{
  mode = "fetch"
  email = $email
  cookies = $login.cookies
  sections = @("attendance")
}
Write-Host ("fetch success={0} class={1} attendanceRows={2} error={3} finalUrl={4}" -f `
  $fetch.success, $fetch.classification, @($fetch.data.attendance).Count, $fetch.error, $fetch.finalUrl)
