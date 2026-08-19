# start-all.ps1 - Launch all SRM One services at once
#
# Services:
#   1. Academia backend  -> http://localhost:3000
#   2. Placement backend -> http://localhost:3001
#   3. Faculty scraper   -> http://localhost:8080
#   4. Frontend (Vite)   -> http://localhost:5174
#
# Usage:
#   .\start-all.ps1            # start everything
#   .\start-all.ps1 -Stop      # stop everything
#
# Press Ctrl+C in this window to stop all services.

param(
  [switch]$Stop
)

$ErrorActionPreference = "Stop"

$ROOT       = $PSScriptRoot
$ACADEMIA   = Join-Path $ROOT "academia-backend"
$PLACEMENT  = Join-Path $ROOT "placement-backend"
$FRONTEND   = Join-Path $ACADEMIA "frontend"
$FACULTY    = Join-Path $ACADEMIA "faculty-scraper"

$PORTS = @{
  "Academia backend"  = 3000
  "Placement backend" = 3001
  "Faculty scraper"   = 8080
  "Frontend"          = 5174
}

# --- Stop mode ---
if ($Stop) {
  Write-Host ""
  Write-Host "Stopping all SRM One services..." -ForegroundColor Yellow
  Write-Host ""
  foreach ($name in $PORTS.Keys) {
    $port = $PORTS[$name]
    $conns = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
    if ($conns) {
      foreach ($conn in $conns) {
        try {
          $proc = Get-Process -Id $conn.OwningProcess -ErrorAction Stop
          Write-Host "  Stopping $name (PID $($proc.Id)) on port $port..." -ForegroundColor Cyan
          Stop-Process -Id $proc.Id -Force
        } catch {}
      }
    } else {
      Write-Host "  $name (port $port) is not running." -ForegroundColor DarkGray
    }
  }
  Write-Host ""
  Write-Host "All services stopped." -ForegroundColor Green
  Write-Host ""
  exit 0
}

# --- Start mode ---

function Test-Port($port) {
  return [bool](Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue)
}

function Stop-Port($port, $label) {
  $conns = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
  if ($conns) {
    foreach ($conn in $conns) {
      try {
        $proc = Get-Process -Id $conn.OwningProcess -ErrorAction Stop
        Write-Host "  Killing stale $label (PID $($proc.Id)) on port $port..." -ForegroundColor DarkYellow
        Stop-Process -Id $proc.Id -Force
      } catch {}
    }
    Start-Sleep -Milliseconds 500
  }
}

# Check Node availability
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
  Write-Host "ERROR: Node.js is not installed or not on PATH." -ForegroundColor Red
  exit 1
}
if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
  Write-Host "ERROR: npm is not installed or not on PATH." -ForegroundColor Red
  exit 1
}

# Verify directories exist
foreach ($dir in @($ACADEMIA, $PLACEMENT, $FRONTEND, $FACULTY)) {
  if (-not (Test-Path $dir)) {
    Write-Host "ERROR: Missing directory: $dir" -ForegroundColor Red
    exit 1
  }
}

# Build the faculty scraper (Go) if the binary is missing or source is newer
$facultyExe = Join-Path $FACULTY "faculty-scraper.exe"
$needBuild = $false
if (-not (Test-Path $facultyExe)) {
  $needBuild = $true
} else {
  $exeTime = (Get-Item $facultyExe).LastWriteTime
  Get-ChildItem -Path $FACULTY -Recurse -Include *.go, go.mod | ForEach-Object {
    if ($_.LastWriteTime -gt $exeTime) { $needBuild = $true }
  }
}
if ($needBuild) {
  if (-not (Get-Command go -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: Go is not installed or not on PATH - cannot build faculty scraper." -ForegroundColor Red
    exit 1
  }
  Write-Host "Building faculty scraper (Go)..." -ForegroundColor Cyan
  Push-Location $FACULTY
  try {
    go build -o faculty-scraper.exe .
    if ($LASTEXITCODE -ne 0) { throw "go build failed" }
  }
  finally { Pop-Location }
}

# Verify node_modules exist
foreach ($check in @(
  @{ Dir = $ACADEMIA;  Label = "academia-backend" },
  @{ Dir = $PLACEMENT; Label = "placement-backend" },
  @{ Dir = $FRONTEND;  Label = "frontend" }
)) {
  $nm = Join-Path $check.Dir "node_modules"
  if (-not (Test-Path $nm)) {
    Write-Host "Installing dependencies for $($check.Label)..." -ForegroundColor Cyan
    Push-Location $check.Dir
    try { npm install } finally { Pop-Location }
  }
}

# Kill stale processes on the ports we need
Write-Host ""
Write-Host "Checking for stale processes..." -ForegroundColor Yellow
foreach ($name in $PORTS.Keys) {
  Stop-Port $PORTS[$name] $name
}

# Launch each service in its own window so logs are separate and readable
Write-Host ""
Write-Host "Starting services..." -ForegroundColor Green
Write-Host ""

$jobs = @()

# 1. Academia backend (port 3000)
Write-Host "  [1/4] Academia backend  -> http://localhost:3000" -ForegroundColor Cyan
$jobs += Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile", "-Command", "npm run dev" -WorkingDirectory $ACADEMIA -PassThru -WindowStyle Normal

Start-Sleep -Seconds 2

# 2. Placement backend (port 3001)
Write-Host "  [2/4] Placement backend -> http://localhost:3001" -ForegroundColor Cyan
$jobs += Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile", "-Command", "npm start" -WorkingDirectory $PLACEMENT -PassThru -WindowStyle Normal

Start-Sleep -Seconds 2

# 3. Faculty scraper (port 8080, Go binary)
Write-Host "  [3/4] Faculty scraper   -> http://localhost:8080" -ForegroundColor Cyan
$jobs += Start-Process -FilePath $facultyExe -WorkingDirectory $FACULTY -PassThru -WindowStyle Normal

Start-Sleep -Seconds 2

# 4. Frontend (port 5174)
Write-Host "  [4/4] Frontend (Vite)   -> http://localhost:5174" -ForegroundColor Cyan
$jobs += Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile", "-Command", "npm run dev" -WorkingDirectory $FRONTEND -PassThru -WindowStyle Normal

Write-Host ""
Write-Host "All services launched in separate windows." -ForegroundColor Green
Write-Host ""

# Get the local network IP (skip loopback/VirtualBox/APIPA)
$lanIP = $null

# Use ipconfig - most reliable across all Windows environments
$rawOutput = ipconfig
$ipLines = $rawOutput | Select-String -Pattern "IPv4 Address"
foreach ($line in $ipLines) {
  $ip = ($line.ToString() -replace ".*:\s*", "").Trim()
  if ($ip -and $ip -notlike "127.*" -and $ip -notlike "169.*" -and $ip -notlike "192.168.56.*") {
    $lanIP = $ip
    break
  }
}

# Fallback to Get-NetIPAddress if ipconfig didn't find anything
if (-not $lanIP) {
  try {
    $allIPs = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
      Where-Object {
        $_.IPAddress -notlike "127.*" -and
        $_.IPAddress -notlike "169.*" -and
        $_.IPAddress -notlike "192.168.56.*" -and
        $_.InterfaceAlias -notlike "*VirtualBox*" -and
        $_.InterfaceAlias -notlike "*vEthernet*" -and
        $_.InterfaceAlias -notlike "*WSL*"
      }
    if ($allIPs) {
      $dhcpIP = $allIPs | Where-Object { $_.PrefixOrigin -eq "Dhcp" } | Select-Object -First 1
      if ($dhcpIP) { $lanIP = $dhcpIP.IPAddress }
      else { $lanIP = ($allIPs | Select-Object -First 1).IPAddress }
    }
  } catch {}
}

Write-Host "Local server URLs:" -ForegroundColor Yellow
Write-Host "  Frontend          -> http://localhost:5174" -ForegroundColor White
Write-Host "  Academia backend  -> http://localhost:3000" -ForegroundColor White
Write-Host "  Placement backend -> http://localhost:3001" -ForegroundColor White
Write-Host "  Faculty scraper   -> http://localhost:8080" -ForegroundColor White
Write-Host ""

if ($lanIP) {
  Write-Host "Local network URLs (accessible from other devices on your Wi-Fi):" -ForegroundColor Yellow
  Write-Host "  Frontend          -> http://$($lanIP):5174" -ForegroundColor Green
  Write-Host "  Academia backend  -> http://$($lanIP):3000" -ForegroundColor Green
  Write-Host "  Placement backend -> http://$($lanIP):3001" -ForegroundColor Green
  Write-Host "  Faculty scraper   -> http://$($lanIP):8080" -ForegroundColor Green
  Write-Host ""
  Write-Host "Open http://$($lanIP):5174 on any device on your network." -ForegroundColor Cyan
} else {
  Write-Host "Open http://localhost:5174 in your browser." -ForegroundColor Cyan
}
Write-Host ""
Write-Host "To stop all services:  .\start-all.ps1 -Stop" -ForegroundColor DarkGray
Write-Host "Or close the individual windows." -ForegroundColor DarkGray
Write-Host ""

# Print PIDs for reference
Write-Host "Process IDs:" -ForegroundColor DarkGray
foreach ($j in $jobs) {
  Write-Host "  PID $($j.Id)" -ForegroundColor DarkGray
}
