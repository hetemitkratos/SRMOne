# Deployment Guide — srmone.in

This guide covers deploying HackTrackr to **Vercel** (frontend) + **Render** (backends) with a **GoDaddy** domain.

## Architecture

```
                    ┌─────────────────────────────┐
                    │       srmone.in (GoDaddy)    │
                    │           ↓ DNS              │
                    │   ┌────────────────────┐     │
                    │   │  Vercel (Frontend)  │     │
                    │   │  React + Vite app   │     │
                    │   └────────┬───────────┘     │
                    │            │ rewrites        │
                    │   ┌────────┴───────────┐     │
                    │   │ /api/*  →  Render 1 │     │
                    │   │ /placement-api/*    │     │
                    │   │           → Render 2│     │
                    │   └────────────────────┘     │
                    └─────────────────────────────┘
```

- **Frontend** → Vercel (free tier) — serves the React app + proxies API calls
- **Academia Backend** → Render (free tier, Docker) — SRM portal scraper + API
- **Placement Backend** → Render (free tier, Docker) — Haveloc placement scraper + API
- **Supabase** → Already configured (database, auth, realtime)

---

## Step 1: Deploy Backends to Render

### 1a. Push code to GitHub
Make sure all the deployment files are committed and pushed to your GitHub repo.

### 1b. Create Render Blueprint (auto-creates both services)

1. Go to https://dashboard.render.com
2. Click **New +** → **Blueprint**
3. Select your GitHub repo (`Harsx404/hacktrackr`)
4. Render will detect `render.yaml` and create two services:
   - `academia-backend` (Docker, free tier)
   - `placement-backend` (Docker, free tier)
5. It will prompt for environment variables — set them now (see below)

### 1c. Set Environment Variables in Render

#### academia-backend
| Variable | Value |
|----------|-------|
| `ALLOWED_ORIGINS` | `https://srmone.in,https://www.srmone.in` |
| `SUPABASE_URL` | `https://kolpioxbznypmvivbdhn.supabase.co` |
| `SUPABASE_SERVICE_KEY` | (your Supabase service role key) |

#### placement-backend
| Variable | Value |
|----------|-------|
| `ALLOWED_ORIGINS` | `https://srmone.in,https://www.srmone.in` |
| `SUPABASE_URL` | `https://kolpioxbznypmvivbdhn.supabase.co` |
| `SUPABASE_SERVICE_KEY` | (your Supabase service role key) |
| `ENCRYPTION_KEY` | `cb7faa9e49844b34116652447efcffdd` |

### 1d. Get your Render URLs

After deployment, Render assigns URLs like:
- `https://academia-backend-xxxx.onrender.com`
- `https://placement-backend-xxxx.onrender.com`

**Copy these URLs** — you'll need them for Vercel.

---

## Step 2: Deploy Frontend to Vercel

### 2a. Create Vercel Project

1. Go to https://vercel.com/dashboard
2. Click **Add New** → **Project**
3. Import your GitHub repo (`Harsx404/hacktrackr`)
4. Configure:
   - **Root Directory**: `academia-backend/frontend`
   - **Framework Preset**: Vite
   - **Build Command**: `npm install && npm run build`
   - **Output Directory**: `dist`
5. **Environment Variables** — add these:

| Variable | Value |
|----------|-------|
| `ACADEMIA_BACKEND_URL` | `https://academia-backend-xxxx.onrender.com` |
| `PLACEMENT_BACKEND_URL` | `https://placement-backend-xxxx.onrender.com` |

6. Click **Deploy**

### 2b. Verify the deployment

- Visit your Vercel URL (e.g., `https://hacktrackr-xxxx.vercel.app`)
- Test login — it should proxy through to the Render backends

---

## Step 3: Configure GoDaddy DNS

### 3a. Add domain to Vercel

1. In Vercel dashboard → your project → **Settings** → **Domains**
2. Add `srmone.in` (apex domain)
3. Add `www.srmone.in` (redirects to apex)
4. Vercel will show you the DNS records to add

### 3b. Configure DNS in GoDaddy

Log into https://dcc.godaddy.com/manage/dns

#### Option A: Using Nameservers (recommended — easiest)

1. In GoDaddy, go to your domain → **Manage DNS** → **Nameservers**
2. Change nameservers to Vercel's:
   - `ns1.vercel-dns.com`
   - `ns2.vercel-dns.com`
3. Save (may take 15-30 min to propagate)

#### Option B: Using A Record + CNAME (keep GoDaddy DNS)

Add these records:

| Type | Name | Value | TTL |
|------|------|-------|-----|
| A | `@` | `76.76.21.21` | 600 |
| CNAME | `www` | `cname.vercel-dns.com` | 600 |

### 3c. Verify domain

- Wait for DNS propagation (check with https://whatsmydns.net)
- Vercel will show a green checkmark when the domain is verified
- HTTPS is automatic via Vercel's SSL

---

## Step 4: Update Render CORS (after domain is live)

Once `srmone.in` is live, update the `ALLOWED_ORIGINS` env var in both Render services to:
```
https://srmone.in,https://www.srmone.in,https://hacktrackr-xxxx.vercel.app
```

(Include the Vercel preview URL for testing.)

---

## Security Measures

### Already implemented:

1. **CORS** — Both backends only accept requests from `ALLOWED_ORIGINS`
2. **Helmet** — Security headers (X-Content-Type-Options, X-Frame-Options, etc.)
3. **Rate limiting** — Both backends have express-rate-limit
4. **HSTS** — Vercel enforces HTTPS with Strict-Transport-Security
5. **X-Frame-Options: DENY** — Prevents clickjacking
6. **Referrer-Policy** — strict-origin-when-cross-origin
7. **Permissions-Policy** — camera, microphone, geolocation disabled
8. **No secrets in repo** — All `.env` files are gitignored
9. **Docker multi-stage build** — Go binaries compiled in isolated stage
10. **Health checks** — Both services have `/health` endpoint for uptime monitoring
11. **Encrypted credentials** — Placement passwords encrypted with AES-256
12. **Supabase RLS** — Row-level security on all tables

### Recommended additional steps:

1. **Set up UptimeRobot** (free) — Monitor `https://srmone.in` and both Render health endpoints
2. **Enable Vercel DDoS protection** — Automatic on all plans
3. **Rotate Supabase keys** if they were ever shared
4. **Set Supabase RLS policies** — Ensure only authenticated users can read their own data
5. **Add CSP header** in Vercel if you want stricter content security

---

## Free Tier Limitations

### Render Free Tier
- Services spin down after 15 min of inactivity
- First request after spin-down takes ~30-50 seconds (cold start)
- 750 hours/month of free runtime
- No custom domains on free tier (use `.onrender.com` URLs)

### Vercel Free Tier
- 100GB bandwidth/month
- Unlimited static deployments
- Automatic HTTPS
- Custom domains included

### Mitigation for Render cold starts:
- Use UptimeRobot to ping `/health` every 10 minutes
- This keeps services warm (but uses your free hours faster)

---

## Troubleshooting

### Frontend can't reach backend
- Check Vercel env vars `ACADEMIA_BACKEND_URL` and `PLACEMENT_BACKEND_URL` are set
- Check Render services are running (visit the `.onrender.com` URL directly)
- Check CORS — `ALLOWED_ORIGINS` must include `https://srmone.in`

### Login fails
- Check the Go scraper binary was built (check Render build logs)
- The Dockerfile compiles it from source — Go must be in the build context
- Verify `academia-backend/academia-scraper/` directory is in the repo

### CORS errors in browser
- Check `ALLOWED_ORIGINS` in Render includes your exact domain
- No trailing slashes: `https://srmone.in` not `https://srmone.in/`
- Vercel rewrites should make this a non-issue (same-origin requests)

### DNS not propagating
- Check with https://whatsmydns.net/#A/srmone.in
- GoDaddy can take up to 48 hours (usually 15-30 min)
- Try switching to Vercel nameservers (Option A above)
