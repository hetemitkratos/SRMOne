#!/bin/bash
# Render start script — sets Go PATH, then starts the academia backend
export PATH=$PATH:/usr/local/go/bin
export GOPATH=$HOME/go
export PATH=$PATH:$GOPATH/bin
export NODE_ENV=production

cd academia-backend
exec node server.js
