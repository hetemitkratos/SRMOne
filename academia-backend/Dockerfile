# ─── Stage 1: Build Go scraper binaries ───────────────────────────────────────
FROM golang:1.25-alpine AS go-builder

# Install git for Go module downloads
RUN apk add --no-cache git

# Copy the Go module
WORKDIR /build/academia-scraper
COPY academia-backend/academia-scraper/go.mod academia-backend/academia-scraper/go.sum ./

# Download dependencies (cached layer)
RUN go mod download

# Copy the rest of the scraper source
COPY academia-backend/academia-scraper/ ./

# Build the loginprobe binary for Linux
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o /loginprobe ./cmd/loginprobe

# Build the studentportal binary for Linux
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o /studentportal ./cmd/studentportal

# ─── Stage 2: Node runtime ────────────────────────────────────────────────────
FROM node:20-alpine

WORKDIR /app

# Install only production dependencies
COPY academia-backend/package.json academia-backend/package-lock.json* ./
RUN npm ci --omit=dev 2>/dev/null || npm install --omit=dev

# Copy backend source
COPY academia-backend/backend/ ./backend/
COPY academia-backend/server.js ./

# Copy the compiled Go binaries
COPY --from=go-builder /loginprobe /app/academia-scraper/loginprobe
COPY --from=go-builder /studentportal /app/academia-scraper/studentportal

# Set environment defaults
ENV NODE_ENV=production
ENV PORT=3000

# Expose the port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/health || exit 1

# Start the server (Render sets env vars directly, no --env-file needed)
CMD ["node", "server.js"]
