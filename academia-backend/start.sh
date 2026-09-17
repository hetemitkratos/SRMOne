#!/bin/bash
# Render start script — starts faculty scraper (port 8080) and academia backend
# Go binaries are pre-built during build phase
export NODE_ENV=production

# ddddocr (captcha auto-solve) is pip-installed into academia-scraper/pydeps at build time
export PYTHONPATH="$PWD/academia-backend/academia-scraper/pydeps${PYTHONPATH:+:$PYTHONPATH}"

cd academia-backend

# Start faculty scraper in background on port 8080
# Render sets PORT=10000 for the main service; faculty scraper must use a different port
PORT=8080 ./faculty-scraper/faculty-scraper &
FACULTY_PID=$!
echo "Faculty scraper started (PID: $FACULTY_PID) on port 8080"

# Wait a moment for faculty scraper to be ready
sleep 2

# Start Node backend (foreground)
exec node server.js
