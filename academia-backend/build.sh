#!/bin/bash
# Render build script — installs Go to user dir, builds Go binary, installs Node deps
# Render's Node runtime doesn't include Go and doesn't have sudo access

set -e

GO_VERSION="1.25.0"
GO_TAR="go${GO_VERSION}.linux-amd64.tar.gz"
GO_INSTALL_DIR="$HOME/.go"

echo "=== Installing Go ${GO_VERSION} to ${GO_INSTALL_DIR} ==="
curl -fsSL "https://go.dev/dl/${GO_TAR}" -o "/tmp/${GO_TAR}"
mkdir -p "$GO_INSTALL_DIR"
tar -C "$GO_INSTALL_DIR" -xzf "/tmp/${GO_TAR}"
rm "/tmp/${GO_TAR}"
export GOROOT="$GO_INSTALL_DIR/go"
export GOPATH="$HOME/go"
export PATH="$GOROOT/bin:$GOPATH/bin:$PATH"

echo "Go version: $(go version)"

echo "=== Installing Node dependencies ==="
cd academia-backend
npm install --omit=dev

echo "=== Pre-downloading Go modules ==="
cd academia-scraper
go mod download

echo "=== Pre-building Go scraper binary ==="
go build -o loginprobe ./cmd/loginprobe
echo "Binary built: $(ls -la loginprobe)"

echo "=== Build complete ==="
