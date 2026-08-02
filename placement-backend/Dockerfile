# ─── Stage 1: Build Go scraper (haveloc) binary ──────────────────────────────
FROM golang:1.25-alpine AS go-builder

RUN apk add --no-cache git

WORKDIR /build/academia-scraper
COPY academia-backend/academia-scraper/go.mod academia-backend/academia-scraper/go.sum ./
RUN go mod download

COPY academia-backend/academia-scraper/ ./

# Build the haveloc-scraper binary for Linux
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o /haveloc-scraper ./cmd/haveloc

# ─── Stage 2: Node runtime ────────────────────────────────────────────────────
FROM node:20-alpine

WORKDIR /app

# Install only production dependencies
COPY placement-backend/package.json placement-backend/package-lock.json* ./
RUN npm ci --omit=dev 2>/dev/null || npm install --omit=dev

# Copy backend source
COPY placement-backend/backend/ ./backend/

# Copy the compiled Go binary into the expected path
# The scraper client looks in several paths including ../../academia-backend/academia-scraper/
COPY --from=go-builder /haveloc-scraper /app/academia-backend/academia-scraper/haveloc-scraper
# Also place it in a few fallback locations the client checks
COPY --from=go-builder /haveloc-scraper /app/haveloc-scraper
COPY --from=go-builder /haveloc-scraper /usr/local/bin/haveloc-scraper

# Set environment defaults
ENV NODE_ENV=production
ENV PORT=3001

EXPOSE 3001

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3001/health || exit 1

# Start the server
CMD ["node", "backend/api/server.js"]
