#!/bin/bash
# Render start script — sets Go PATH, then starts the placement backend
export PATH=$PATH:/usr/local/go/bin
export GOPATH=$HOME/go
export PATH=$PATH:$GOPATH/bin
export NODE_ENV=production

cd placement-backend
exec node backend/api/server.js
