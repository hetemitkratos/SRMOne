# hacktrackr

A unified academic + placement dashboard for SRM students.

## Structure

```
hacktrackr/
├── academia-backend/      # SRM Academia portal API (Express + Go scraper)
│   ├── backend/           # API server
│   ├── frontend/          # React + Vite dashboard
│   └── academia-scraper/  # Go scraper for SRM portal
├── placement-backend/     # Haveloc placement portal API (Express + Go scraper)
│   ├── backend/           # API server + Supabase credential storage
│   └── integrations/      # Go scraper client
├── haveloc-scraper/       # Go scraper for Haveloc placement portal
└── start-all.ps1          # PowerShell script to start all services
```

## Features

- **Academia Dashboard** — Attendance, marks, timetable, calendar with holiday sync
- **Placement Portal** — Companies, jobs, tracker, notices, policies from Haveloc
- **One-Time Connect** — Link placement account once, auto-login on every visit
- **Calendar Sync** — Academic calendar holidays and day-order changes reflected in timetable
- **Mobile Responsive** — Works seamlessly on phone and desktop

## Tech Stack

- **Frontend**: React, Vite, Tailwind CSS, Framer Motion, Anime.js
- **Academia Backend**: Express 5, Go scraper
- **Placement Backend**: Express 4, Go scraper, Supabase (credential storage)
- **Database**: Supabase (PostgreSQL) for encrypted credential storage

## Setup

### Prerequisites
- Node.js 18+
- Go 1.21+
- Supabase account

### Environment Variables

**academia-backend/.env**
```
PORT=3000
ALLOWED_ORIGINS=http://localhost:5174
```

**placement-backend/.env**
```
PORT=3001
SUPABASE_URL=https://<your-project>.supabase.co
SUPABASE_SERVICE_KEY=<your-service-role-key>
ENCRYPTION_KEY=<32-char-random-string>
```

### Install & Run

```powershell
# Install dependencies
cd academia-backend && npm install
cd ../placement-backend && npm install

# Build Go scrapers
cd ../haveloc-scraper && go build -o haveloc-scraper.exe ./cmd/main/

# Start all services
cd .. && .\start-all.ps1
```

## Supabase Setup

Create a `placement_credentials` table:

```sql
CREATE TABLE public.placement_credentials (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  academia_email TEXT NOT NULL UNIQUE,
  placement_username TEXT NOT NULL,
  encrypted_password TEXT NOT NULL,
  has_mfa BOOLEAN DEFAULT FALSE,
  connected_at TIMESTAMPTZ DEFAULT NOW(),
  last_auto_login TIMESTAMPTZ,
  auto_login_enabled BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.placement_credentials ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Service role full access" ON public.placement_credentials
  FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
```
