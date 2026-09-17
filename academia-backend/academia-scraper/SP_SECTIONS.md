# Adding Student Portal sections (marks, fees, grades, …)

How to add a new data section from the SRM Student Portal
(`sp.srmist.edu.in`). Attendance (`iden=9`) and internal marks
(`iden=13`) are already implemented — follow the same recipe.

---

## 1. How the portal serves sections

The dashboard menu items look like `onclick="funSetFormId(N)"`. `funSetFormId`
sets `hdnFormId=N` and submits the `#userHomePage` form to
`students/template/HRDSystem.jsp`. **Do not rely on this flow from a scraper** —
posting the form server-side just returns the dashboard shell with `hdnFormId`
reset to `1` and an empty `#divMainDetails`. The real content is loaded
client-side by `funShow(iden, '<jsp>')`, whose `<jsp>` URL is **not** present in
any static HTML or `main.js`.

What actually works (and what attendance/marks use): **POST the section's own
`report/*.jsp` (or `transaction/*.jsp`) directly**, exactly like the browser's
`funShow` AJAX call:

```
POST https://sp.srmist.edu.in/srmiststudentportal/students/report/<PAGE>.jsp
Content-Type: application/x-www-form-urlencoded
Referer: .../students/template/HRDSystem.jsp
X-Requested-With: XMLHttpRequest

iden=<menuFormId>&filter=&hdnFormDetails=1&csrfPreventionSalt=
```

A dashboard GET (`spEnsureDashboard` equivalent — a GET of `HRDSystem.jsp`) must
happen first to put the session in the right state. `csrfPreventionSalt` is empty
on this portal. The only unknown per section is the **`<PAGE>.jsp` filename** —
that's what you probe for.

> Some jsps ignore `iden` and always return their own page
> (`studentAttendanceDetails.jsp` returns attendance for any `iden`). So match a
> section to its own jsp, don't reuse another's.

### Menu formIds (from the dashboard, iden = formId)

| Section | iden | Status |
|---|---|---|
| Dashboard (home) | 1 | — |
| Finance Details | 3 | TODO |
| Grade / Mark & Credit | 8 | TODO |
| Attendance Details | 9 | ✅ `report/studentAttendanceDetails.jsp` |
| Timetable | 10 | (academia) |
| Internal Mark Details | 13 | ✅ `report/studentInternalMarkDetails.jsp` |
| Personal Details | 17 | TODO (name+regno already in every page footer) |
| Fee Payment | 69 | TODO |
| Course Status | 84 | TODO |
| Exam Provisional Results | 24 | TODO |
| Exam Revaluation Results | 27 | TODO |
| Hostel Details | 11 | TODO |
| Transport Details | 12 | TODO |

Full list: log in and read the sidebar `funSetFormId(N)` handlers on
`HRDSystem.jsp`.

---

## 2. Discover the jsp filename (one probe login)

Each probe attempt is one authenticated request, but the **login** costs a
captcha attempt, so batch all candidate URLs into a single login.

1. Add a temporary probe gated by an env var (see the pattern below), wired into
   `spRun`'s `login_and_fetch` tail in `cmd/studentportal/main.go`.
2. Build: `go build -o studentportal.exe ./cmd/studentportal`.
3. Get a captcha, read it yourself, log in through the Cloudflare relay
   (production egress is IP-blocked — see `SP_PORTAL_NOTES` / the relay in
   `relay/cf-worker`):

```bash
export SP_RELAY_URL=https://sp-relay.harshkandoo.workers.dev
export SP_RELAY_SECRET=<the relay secret>          # same value as on Render

# a) fetch a captcha (prepare_only — no login attempt consumed)
echo '{"mode":"prepare_only","email":"<netid>@srmist.edu.in"}' \
  | ./studentportal.exe > prep.json 2>/dev/null
#   decode prep.json .captchaImage (data:image/png;base64,...) and read it

# b) log in with the answer + the probe env var set
export SP_PROBE=1
python - <<'PY'
import json, subprocess, os
d = json.load(open('prep.json'))
req = {"mode":"login_and_fetch","email":"<netid>@srmist.edu.in",
       "password":"<sp password>","captchaAnswer":"<READ>",
       "loginState":d["loginState"],"cookies":d["cookies"]}
p = subprocess.run(["./studentportal.exe"], input=json.dumps(req),
                   capture_output=True, text=True, timeout=200, env={**os.environ})
print("login", json.loads(p.stdout).get("success"))
print("\n".join(l for l in p.stderr.splitlines() if "probe" in l))
PY
```

### Probe pattern (temporary `cmd/studentportal/probe.go`)

```go
package main

import ("fmt"; "os"; "strings")

func spProbe(client *SPClient) {
    if os.Getenv("SP_PROBE") == "" { return }
    // dashboard GET first
    client.DoRequest("GET", spDashboardURL, nil, "",
        map[string]string{"Referer": spLoginURL}, true)

    base := spBaseURL + "/srmiststudentportal/students/"
    iden := "3" // <- the section's formId
    candidates := []string{
        "report/studentFeeDetails.jsp", "report/studentFinanceDetails.jsp",
        "transaction/studentFeeDetails.jsp", "report/StudentFeeDetails.jsp",
        // ...add plausible names...
    }
    body := "iden=" + iden + "&filter=&hdnFormDetails=1&csrfPreventionSalt="
    for _, path := range candidates {
        r, err := client.DoRequest("POST", base+path, []byte(body),
            "application/x-www-form-urlencoded",
            map[string]string{"Referer": spDashboardURL, "X-Requested-With": "XMLHttpRequest"}, true)
        if err != nil { fmt.Fprintf(os.Stderr, "[probe] %s ERR %v\n", path, err); continue }
        low := strings.ToLower(string(r.Body))
        hit := r.StatusCode == 200 && len(r.Body) > 400 && strings.Contains(low, "<table")
        fmt.Fprintf(os.Stderr, "[probe] %-45s status=%d len=%d tables=%d\n",
            path, r.StatusCode, len(r.Body), strings.Count(low, "<table"))
        if hit { os.WriteFile("sp_probe_"+strings.ReplaceAll(path,"/","_"), r.Body, 0644) }
    }
}
```

Wire it (temporarily) right before the final `return resp` in `spRun`'s
login-and-fetch branch, then **delete `probe.go` and the call** once you've found
the URL. A `status=200`, non-trivial length, `<table>`-bearing response is the
hit; the saved `sp_probe_*` file is the HTML to parse.

Guessing tips: names are `student<Thing>Details.jsp` in `report/`
(occasionally `transaction/`), camelCase. If everything 404s, capture the real
request from a browser: DevTools → Network → click the menu item → find the
`$.post` to a `.jsp`.

---

## 3. Implement the section (mirror `marks.go`)

1. **Type** — add a record struct + a slice field on `SPResponse` in
   `cmd/studentportal/types.go` (e.g. `Fees []SPFeeRecord`).
2. **Fetch + parse** — new `cmd/studentportal/<section>.go` with
   `spFetch<Section>(client)`: dashboard GET, POST the discovered jsp with the
   `iden` body, parse the table with goquery (reuse `parseSPHTML`,
   `spExtractHeaders`, `spContainsHeader`). See `marks.go` for the template.
3. **Wire** — in `main.go`, call it in both the `fetch` and `login_and_fetch`
   branches and set `resp.<Field>` (keep it non-fatal: `if x, err := ...; err == nil`).
4. **Build**: `go build -o studentportal.exe ./cmd/studentportal`.

## 4. Backend (`backend/api/server.js`)

- Store the new data in `storeSPSessionResult` (`spSessions[email].<field>` and
  `session.cache.sp<Field>`).
- Add `GET /sp/<section>` mirroring `/sp/marks`: cache-first →
  `runStudentPortalScraper({mode:"fetch",cookies})` → `spAutoLogin` on a cold
  session (captcha only if auto-solve fails).
- Add `/sp/<section>` to the `RESTORE_PATHS` set so the session-restore
  middleware runs for it.

## 5. Frontend

- Add `sp<Section>: (email) => request('/sp/<section>?...')` in
  `src/api/client.js`.
- Render it in the relevant page; handle `captchaRequired` by pointing the user
  to the Attendance tab to reconnect (that page owns the captcha UI). See
  `pages/Marks.jsx` for the fallback + `captchaRequired` pattern.

## 6. Test before committing

Run the live relay flow from step 2 (mode `login_and_fetch`) and confirm the new
field is populated. Data is cached once per login/refresh — sections like fees,
finance, personal details change rarely, so never fetch them on every page view.

Caching model: fetch once at login / on the 30-min refresh, store in the SP
session (+ Supabase via `persistSPSession` for cookies), serve from cache. See
also `SP_PORTAL_NOTES` and the memory notes `sp-endpoints`,
`sp-portal-blocks-cloud-ips`.
