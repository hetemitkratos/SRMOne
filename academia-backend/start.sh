#!/bin/bash
# Render start script — starts the academia backend
# Go binary is pre-built during build phase, no need for Go at runtime
export NODE_ENV=production

cd academia-backend
exec node server.js
