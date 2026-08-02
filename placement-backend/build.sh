#!/bin/bash
# Render build script — installs Go, builds haveloc scraper binary, installs Node deps
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
cd placement-backend
npm install --omit=dev

echo "=== Building haveloc scraper binary ==="
cd ../academia-backend/academia-scraper
go mod download
go build -o haveloc-scraper ./cmd/haveloc
echo "Haveloc scraper binary built: $(ls -la haveloc-scraper)"

echo "=== Build complete ==="
