package main

import (
	"encoding/json"
	"fmt"
	"os"
	"strings"
	"sync"
)

func main() {
	var req ProbeRequest
	if err := json.NewDecoder(os.Stdin).Decode(&req); err != nil {
		writeJSON(ProbeResponse{
			Success:        false,
			Classification: classJSDependent,
			Error:          "could not decode stdin JSON: " + err.Error(),
		})
		os.Exit(1)
	}

	mode := normalizeMode(req)
	if strings.TrimSpace(req.Email) == "" {
		writeJSON(ProbeResponse{
			Success:        false,
			Classification: classUnknown,
			Error:          "email is required",
		})
		os.Exit(1)
	}
	if mode != modeFetch && strings.TrimSpace(req.Password) == "" {
		writeJSON(ProbeResponse{
			Success:        false,
			Classification: classUnknown,
			Error:          "password is required for login modes",
		})
		os.Exit(1)
	}
	if mode == modeFetch && len(req.Cookies) == 0 {
		writeJSON(ProbeResponse{
			Success:        false,
			Classification: classUnknown,
			Error:          "cookies are required for fetch mode",
		})
		os.Exit(1)
	}

	result := runProbe(req)
	writeJSON(result)
	if !result.Success {
		os.Exit(1)
	}
}

func writeJSON(v ProbeResponse) {
	encoder := json.NewEncoder(os.Stdout)
	encoder.SetIndent("", "  ")
	if err := encoder.Encode(v); err != nil {
		fmt.Fprintln(os.Stderr, "could not encode JSON:", err)
	}
}

func runProbe(req ProbeRequest) ProbeResponse {
	base := strings.TrimSpace(req.BaseURL)
	if base == "" {
		base = defaultBaseURL
	}

	serviceURL := base
	signinURL := strings.TrimSpace(req.SigninURL)
	if signinURL == "" {
		signinURL = base + defaultSigninPath + "?serviceurl=" + urlQueryEscape(serviceURL)
	}

	mode := normalizeMode(req)
	requestedSections := normalizeRequestedSections(req, mode)
	requestedCalendarSems := normalizeRequestedCalendarSems(req, mode)

	session := NewLoginSession(req.Email, req.Password)
	if strings.TrimSpace(req.SigninURL) != "" {
		session.SigninURL = signinURL
	}
	if strings.TrimSpace(req.AttendanceURL) != "" {
		// attendanceURL override could be stored here if needed
	}
	session.SeedCookies(req.Cookies)

	resp := ProbeResponse{Classification: classUnknown}

	if mode == modeFetch {
		resp.FinalURL = session.ServiceURL
		prime, primeErr := session.PrimePortalSession()
		if prime.URL != "" {
			resp.FinalURL = prime.URL
		}
		if primeErr != nil {
			resp.Error = primeErr.Error()
			if strings.Contains(strings.ToLower(primeErr.Error()), "session expired") {
				resp.Classification = classUnknown
			}
			return finalizeResponse(session, resp)
		}
		if err := fetchRequestedSections(session, &resp, requestedSections, requestedCalendarSems); err != nil && resp.Error == "" {
			resp.Error = err.Error()
		}
	} else {
		// Login flow
		signinInfo, err := session.FetchSigninPage()
		if err != nil {
			resp.Classification = classJSDependent
			resp.Error = err.Error()
			return finalizeResponse(session, resp)
		}
		resp.SigninPage = *signinInfo
		resp.FinalURL = signinInfo.FinalURL

		classification, message := classifyPage(signinInfo.FinalURL, "")
		if classification != "" && classification != classUnknown {
			resp.Classification = classification
			resp.Error = message
			return finalizeResponse(session, resp)
		}

		if err := session.RunLocate(); err != nil {
			resp.Classification = classJSDependent
			resp.Error = err.Error()
			return finalizeResponse(session, resp)
		}

		lookup, err := session.RunLookup(req.Email)
		resp.Lookup = lookup.summary
		if err != nil {
			if resp.Classification == "" || resp.Classification == classUnknown {
				resp.Classification = classifyFromMessage(lookup.summary.LocalizedMessage, lookup.summary.ErrorCode)
			}
			resp.Error = err.Error()
			return finalizeResponse(session, resp)
		}

		pwd, err := session.RunPassword(lookup.identifier, lookup.digest, req.Password)
		resp.Password = pwd.summary
		if err != nil {
			if resp.Classification == "" || resp.Classification == classUnknown {
				resp.Classification = classifyFromMessage(pwd.summary.LocalizedMessage, pwd.summary.ErrorCode)
			}
			resp.Error = err.Error()
			return finalizeResponse(session, resp)
		}

		finalSnap, err := session.CompletePostLogin(pwd.redirectURI)
		if err != nil {
			resp.Classification = classUnknown
			resp.Error = err.Error()
			return finalizeResponse(session, resp)
		}

		resp.FinalURL = finalSnap.URL
		classification, message = classifyPage(finalSnap.URL, string(finalSnap.Body))
		if classification != "" && classification != classUnknown {
			resp.Classification = classification
			resp.Error = message
			return finalizeResponse(session, resp)
		}

		if mode == modeLogin {
			if session.looksAuthenticated(finalSnap) {
				resp.Success = true
				resp.Classification = classAuthenticated
			} else {
				resp.Classification = classUnknown
				resp.Error = "login flow completed but authenticated portal session was not established"
			}
			return finalizeResponse(session, resp)
		}

		// login_and_fetch — mark auth before section fetch so a single fragment
		// failure (e.g. attendance 403) does not wipe a valid login.
		if session.looksAuthenticated(finalSnap) {
			resp.Classification = classAuthenticated
		}

		// Prime the portal session to refresh WAF/CSRF cookies before
		// making XHR fragment requests. Without this, the portal WAF
		// returns 403 on attendance/timetable pages.
		_, primeErr := session.PrimePortalSession()
		if primeErr != nil {
			fmt.Fprintf(os.Stderr, "[runProbe] portal prime failed: %v — skipping section fetch\n", primeErr)
			// Login succeeded but session is not usable for fragment fetches.
			// Return as authenticated with no data — the server can retry later.
			resp.Success = true
			return finalizeResponse(session, resp)
		}

		if err := fetchRequestedSections(session, &resp, requestedSections, requestedCalendarSems); err != nil {
			if resp.Error == "" {
				resp.Error = err.Error()
			}
			if resp.Classification == classAuthenticated && session.IsAuthenticated() {
				// Soft failure: cookies are good; missing sections hydrate later.
				resp.Success = true
			} else if resp.Classification == "" || resp.Classification == classUnknown {
				resp.Classification = classUnknown
			}
		}
	}

	return finalizeResponse(session, resp)
}

func finalizeResponse(session *LoginSession, resp ProbeResponse) ProbeResponse {
	resp.Cookies = session.SerializedCookies()
	resp.CookieNames = session.CookieNames()
	resp.HasJSessionID = containsString(resp.CookieNames, "JSESSIONID")
	if resp.FinalURL == "" {
		resp.FinalURL = session.SigninURL
	}
	if resp.Classification == "" {
		resp.Classification = classUnknown
	}
	return resp
}

// ---------------------------------------------------------------------------
// Section fetching (parallel bundles)
// ---------------------------------------------------------------------------

func fetchRequestedSections(session *LoginSession, resp *ProbeResponse, requestedSections map[string]bool, requestedCalendarSems []string) error {
	needAttendance := requestedSections["studentinfo"] || requestedSections["attendance"] || requestedSections["marks"]
	needTimetable := requestedSections["timetable"]
	needCalendars := len(requestedCalendarSems) > 0

	var mu sync.Mutex
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
			attendanceSum, attendanceErr = session.fetchAttendanceBundle(requestedSections, &resp.Data, &mu)
		}()
	}

	if needTimetable {
		wg.Add(1)
		go func() {
			defer wg.Done()
			timetableErr = session.fetchTimetableBundle(&resp.Data, &mu)
		}()
	}

	if needCalendars {
		wg.Add(1)
		go func() {
			defer wg.Done()
			calendarErr = session.fetchCalendars(requestedCalendarSems, &resp.Data, &mu)
		}()
	}

	wg.Wait()

	if needAttendance {
		resp.Attendance = attendanceSum
	}

	if attendanceErr != nil {
		recordSectionError(&resp.Data, &mu, "attendance", attendanceErr)
		// studentInfo and marks are parsed from the same attendance page HTML,
		// so if attendance fails they are also unavailable.
		recordSectionError(&resp.Data, &mu, "studentInfo", fmt.Errorf("student info unavailable: %s", attendanceErr))
		recordSectionError(&resp.Data, &mu, "marks", fmt.Errorf("marks unavailable: %s", attendanceErr))
		if resp.Error == "" {
			resp.Error = attendanceErr.Error()
		}
		// Don't return immediately — other sections (timetable, calendar) may
		// have succeeded. We'll check missing data at the end.
	}

	if timetableErr != nil {
		recordSectionError(&resp.Data, &mu, "timetable", timetableErr)
		if resp.Error == "" {
			resp.Error = timetableErr.Error()
		}
		return timetableErr
	}

	if calendarErr != nil {
		if resp.Error == "" {
			resp.Error = calendarErr.Error()
		}
		return calendarErr
	}

	missing := missingRequestedData(resp, requestedSections, requestedCalendarSems)
	nonCalendarMissing := make([]string, 0, len(missing))
	for _, item := range missing {
		if !strings.HasPrefix(item, "calendar_") {
			nonCalendarMissing = append(nonCalendarMissing, item)
		}
	}
	// Sections that have recorded errors were attempted but failed (e.g. 403).
	// These are soft failures — don't treat them as fatal missing data.
	fatalMissing := make([]string, 0, len(nonCalendarMissing))
	for _, item := range nonCalendarMissing {
		if _, hasErr := resp.Data.Errors[item]; !hasErr {
			fatalMissing = append(fatalMissing, item)
		}
	}
	if len(fatalMissing) > 0 {
		err := fmt.Errorf("missing requested data: %s", strings.Join(fatalMissing, ", "))
		if resp.Error == "" {
			resp.Error = err.Error()
		}
		return err
	}
	if len(missing) > 0 {
		if resp.Error == "" {
			resp.Error = fmt.Sprintf("missing requested data: %s", strings.Join(missing, ", "))
		}
	}

	if resp.Classification == "" || resp.Classification == classUnknown {
		if containsString(resp.CookieNames, "JSESSIONID") || len(fatalMissing) == 0 {
			resp.Classification = classAuthenticated
		}
	}

	resp.Success = true
	return nil
}

func missingRequestedData(resp *ProbeResponse, requestedSections map[string]bool, requestedCalendarSems []string) []string {
	missing := []string{}
	for section := range requestedSections {
		switch section {
		case "studentinfo":
			if len(resp.Data.StudentInfo) == 0 {
				missing = append(missing, "studentInfo")
			}
		case "attendance":
			if len(resp.Data.Attendance) == 0 {
				missing = append(missing, "attendance")
			}
		case "marks":
			if len(resp.Data.Marks) == 0 {
				missing = append(missing, "marks")
			}
		case "timetable":
			if resp.Data.Timetable == nil || len(resp.Data.Timetable.Courses) == 0 {
				missing = append(missing, "timetable")
			}
		}
	}

	for _, sem := range requestedCalendarSems {
		if resp.Data.Calendars == nil {
			missing = append(missing, "calendar_"+sem)
			continue
		}
		calendar, ok := resp.Data.Calendars[sem]
		if !ok || len(calendar.Months) == 0 {
			missing = append(missing, "calendar_"+sem)
		}
	}
	return missing
}

// ---------------------------------------------------------------------------
// Mode / section normalization
// ---------------------------------------------------------------------------

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

func urlQueryEscape(s string) string {
	// Use net/url.QueryEscape via a helper to avoid importing url in main.go
	return queryEscape(s)
}
