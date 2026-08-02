package main

import (
	"fmt"
	"net/http"
	"strings"
	"sync"
)

const (
	modeLogin         = "login"
	modeFetch         = "fetch"
	modeLoginAndFetch = "login_and_fetch"
)

type SerializedCookie struct {
	Name        string `json:"name"`
	Value       string `json:"value"`
	Path        string `json:"path,omitempty"`
	Domain      string `json:"domain,omitempty"`
	ExpiresUnix int64  `json:"expiresUnix,omitempty"`
	Secure      bool   `json:"secure,omitempty"`
	HttpOnly    bool   `json:"httpOnly,omitempty"`
}

func normalizeMode(req ProbeRequest) string {
	switch strings.ToLower(strings.TrimSpace(req.Mode)) {
	case modeLogin, modeFetch, modeLoginAndFetch:
		return strings.ToLower(strings.TrimSpace(req.Mode))
	}
	if req.LoginOnly {
		return modeLogin
	}
	if len(req.Cookies) > 0 && strings.TrimSpace(req.Password) == "" {
		return modeFetch
	}
	return modeLoginAndFetch
}

func normalizeRequestedSections(req ProbeRequest, mode string) map[string]bool {
	out := map[string]bool{}
	if mode == modeLogin {
		return out
	}

	for _, raw := range req.Sections {
		switch strings.ToLower(strings.TrimSpace(raw)) {
		case "studentinfo", "student":
			out["studentinfo"] = true
		case "attendance":
			out["attendance"] = true
		case "marks":
			out["marks"] = true
		case "timetable":
			out["timetable"] = true
		case "calendar":
			out["calendar"] = true
		}
	}

	if len(out) == 0 && mode == modeLoginAndFetch {
		out["studentinfo"] = true
		out["attendance"] = true
		out["marks"] = true
		out["timetable"] = true
		out["calendar"] = true
	}

	if len(req.CalendarSems) > 0 {
		out["calendar"] = true
	}

	return out
}

func normalizeRequestedCalendarSems(req ProbeRequest, mode string) []string {
	seen := map[string]bool{}
	sems := make([]string, 0, 2)
	appendSem := func(raw string) {
		sem := strings.ToLower(strings.TrimSpace(raw))
		if (sem == "odd" || sem == "even") && !seen[sem] {
			seen[sem] = true
			sems = append(sems, sem)
		}
	}

	for _, raw := range req.CalendarSems {
		appendSem(raw)
	}

	if len(sems) == 0 && mode == modeLoginAndFetch {
		appendSem("odd")
		appendSem("even")
	}

	if len(sems) == 0 && normalizeRequestedSections(req, mode)["calendar"] {
		appendSem("odd")
		appendSem("even")
	}

	return sems
}

func (p *probe) seedCookies(cookies []SerializedCookie) {
	if len(cookies) == 0 {
		return
	}
	jarCookies := make([]*http.Cookie, 0, len(cookies))
	for _, cookie := range cookies {
		if strings.TrimSpace(cookie.Name) == "" {
			continue
		}
		jarCookies = append(jarCookies, &http.Cookie{
			Name:     cookie.Name,
			Value:    cookie.Value,
			Path:     cookie.Path,
			Domain:   cookie.Domain,
			Secure:   cookie.Secure,
			HttpOnly: cookie.HttpOnly,
		})
	}
	if len(jarCookies) > 0 {
		p.jar.SetCookies(p.baseURL, jarCookies)
	}
}

func (p *probe) serializedCookies() []SerializedCookie {
	cookies := p.jar.Cookies(p.baseURL)
	out := make([]SerializedCookie, 0, len(cookies))
	for _, cookie := range cookies {
		out = append(out, SerializedCookie{
			Name:        cookie.Name,
			Value:       cookie.Value,
			Path:        cookie.Path,
			Domain:      cookie.Domain,
			ExpiresUnix: cookie.Expires.Unix(),
			Secure:      cookie.Secure,
			HttpOnly:    cookie.HttpOnly,
		})
	}
	return out
}

func (p *probe) executeFetchOnly() error {
	p.resp.FinalURL = p.serviceURL
	return p.fetchRequestedSections()
}

func (p *probe) fetchRequestedSections() error {
	needAttendance := p.requestedSections["studentinfo"] || p.requestedSections["attendance"] || p.requestedSections["marks"]
	needTimetable := p.requestedSections["timetable"]
	needCalendars := len(p.requestedCalendarSems) > 0

	// The attendance, timetable and calendar bundles hit independent endpoints
	// and write to disjoint Data.* fields, so they can be fetched concurrently.
	// Shared state (RedirectSummary, Data.Errors, authenticatedEvidence, FinalURL)
	// is guarded by p.mu inside doRequest/recordSectionError/noteAuthenticatedEvidence.
	var (
		wg            sync.WaitGroup
		attendanceErr error
		attendanceSum AttendanceSummary
		timetableErr  error
		calendarErr   error
	)

	if needAttendance {
		wg.Add(1)
		go func() {
			defer wg.Done()
			attendanceSum, attendanceErr = p.fetchAttendanceBundle(p.requestedSections)
		}()
	}

	if needTimetable {
		wg.Add(1)
		go func() {
			defer wg.Done()
			timetableErr = p.fetchTimetableBundle()
		}()
	}

	if needCalendars {
		wg.Add(1)
		go func() {
			defer wg.Done()
			calendarErr = p.fetchCalendars(p.requestedCalendarSems)
		}()
	}

	wg.Wait()

	if needAttendance {
		p.resp.Attendance = attendanceSum
	}

	// Preserve original error precedence: attendance > timetable > calendar.
	// Unlike the previous sequential short-circuit, all bundles still ran, so
	// any that succeeded will have populated their Data fields.
	if attendanceErr != nil {
		if p.resp.Error == "" {
			p.resp.Error = attendanceErr.Error()
		}
		return attendanceErr
	}

	if timetableErr != nil {
		p.recordSectionError("timetable", timetableErr)
		if p.resp.Error == "" {
			p.resp.Error = timetableErr.Error()
		}
		return timetableErr
	}

	if calendarErr != nil {
		if p.resp.Error == "" {
			p.resp.Error = calendarErr.Error()
		}
		return calendarErr
	}

	missing := p.missingRequestedData()
	nonCalendarMissing := make([]string, 0, len(missing))
	for _, item := range missing {
		if !strings.HasPrefix(item, "calendar_") {
			nonCalendarMissing = append(nonCalendarMissing, item)
		}
	}
	if len(nonCalendarMissing) > 0 {
		err := fmt.Errorf("missing requested data: %s", strings.Join(nonCalendarMissing, ", "))
		if p.resp.Error == "" {
			p.resp.Error = err.Error()
		}
		return err
	}
	if len(missing) > 0 {
		// Calendar pages are year-specific and often renamed; allow partial success.
		if p.resp.Error == "" {
			p.resp.Error = fmt.Sprintf("missing requested data: %s", strings.Join(missing, ", "))
		}
	}

	if p.resp.Classification == "" || p.resp.Classification == classUnknown {
		if p.authenticatedEvidence || p.hasRequestedData() || containsString(p.cookieNames(), "JSESSIONID") || len(nonCalendarMissing) == 0 {
			p.resp.Classification = classAuthenticated
		}
	}

	p.resp.Success = true
	return nil
}

func (p *probe) hasRequestedData() bool {
	return len(p.missingRequestedData()) == 0
}

func (p *probe) missingRequestedData() []string {
	missing := []string{}
	for section := range p.requestedSections {
		switch section {
		case "studentinfo":
			if len(p.resp.Data.StudentInfo) == 0 {
				missing = append(missing, "studentInfo")
			}
		case "attendance":
			if len(p.resp.Data.Attendance) == 0 {
				missing = append(missing, "attendance")
			}
		case "marks":
			if len(p.resp.Data.Marks) == 0 {
				missing = append(missing, "marks")
			}
		case "timetable":
			if p.resp.Data.Timetable == nil || len(p.resp.Data.Timetable.Courses) == 0 {
				missing = append(missing, "timetable")
			}
		}
	}

	for _, sem := range p.requestedCalendarSems {
		if p.resp.Data.Calendars == nil {
			missing = append(missing, "calendar_"+sem)
			continue
		}
		calendar, ok := p.resp.Data.Calendars[sem]
		if !ok || len(calendar.Months) == 0 {
			missing = append(missing, "calendar_"+sem)
		}
	}
	return missing
}

func (p *probe) noteAuthenticatedEvidence(pageURL, body string) {
	if looksLikeUnauthenticatedPage(pageURL, body) {
		return
	}
	p.mu.Lock()
	defer p.mu.Unlock()
	p.authenticatedEvidence = true
	if strings.TrimSpace(pageURL) != "" {
		p.resp.FinalURL = pageURL
	}
}

func looksLikeUnauthenticatedPage(pageURL, body string) bool {
	lowerURL := strings.ToLower(pageURL)
	lowerBody := strings.ToLower(body)
	if strings.Contains(lowerURL, "/accounts/") || strings.Contains(lowerURL, "signin") {
		return true
	}
	return strings.Contains(lowerBody, "zoho accounts") ||
		strings.Contains(lowerBody, "sign in to continue") ||
		strings.Contains(lowerBody, "name=\"login_id\"") ||
		strings.Contains(lowerBody, "id=\"login_id\"")
}
