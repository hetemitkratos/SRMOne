#!/bin/bash
# Render start script — starts the placement backend
# Go binary is pre-built during build phase, no need for Go at runtime
export NODE_ENV=production

cd placement-backend
exec node backend/api/server.js
