#!/bin/bash
# Render build script — installs Go, then installs Node deps
# Render's Node runtime doesn't include Go, so we install it during build

set -e

GO_VERSION="1.25.0"
GO_TAR="go${GO_VERSION}.linux-amd64.tar.gz"

echo "=== Installing Go ${GO_VERSION} ==="
wget -q "https://go.dev/dl/${GO_TAR}" -O "/tmp/${GO_TAR}"
sudo tar -C /usr/local -xzf "/tmp/${GO_TAR}"
rm "/tmp/${GO_TAR}"
export PATH=$PATH:/usr/local/go/bin
export GOPATH=$HOME/go
export PATH=$PATH:$GOPATH/bin

echo "Go version: $(go version)"

echo "=== Installing Node dependencies ==="
cd placement-backend
npm install --omit=dev

echo "=== Pre-downloading Go modules (for faster first request) ==="
cd ../academia-backend/academia-scraper
go mod download

echo "=== Build complete ==="
