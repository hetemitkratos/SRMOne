#!/bin/bash
# Render build script — installs Go, builds Go binaries, installs Node deps
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

echo "=== Building academia scraper binaries ==="
cd academia-scraper
go mod download
go build -o loginprobe ./cmd/loginprobe
go build -o studentportal ./cmd/studentportal
echo "Academia scraper binaries built"

echo "=== Installing ddddocr for captcha auto-solve ==="
# Student Portal captchas are auto-solved by the local ddddocr OCR
# (solve_captcha.py). Installed into the repo dir so it survives to runtime.
if python3 -m pip install --quiet --target "$PWD/pydeps" ddddocr 2>/dev/null; then
  echo "ddddocr installed to $PWD/pydeps"
else
  echo "WARNING: ddddocr install failed — SP logins will fall back to manual captcha"
fi

echo "=== Building faculty scraper binary ==="
cd ../faculty-scraper
go mod download
go build -o faculty-scraper .
echo "Faculty scraper binary built"

echo "=== Build complete ==="
