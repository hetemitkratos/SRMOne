package main

import (
	"encoding/json"
	"fmt"
	"net/url"
	"strconv"
	"strings"
	"sync"
	"time"
)

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const (
	defaultBaseURL              = "https://academia.srmist.edu.in"
	defaultPortalID             = "40-10002227248"
	defaultStudentPhotoReportID = "2727643000298055031"
	defaultSigninPath           = "/accounts/p/" + defaultPortalID + "/signin"
	defaultAttendanceURL        = defaultBaseURL + "/srm_university/academia-academic-services/page/My_Attendance"
	defaultPersonalTTURL        = defaultBaseURL + "/srm_university/academia-academic-services/page/My_Time_Table_2023_24"
	defaultUnifiedTTB1          = defaultBaseURL + "/srm_university/academia-academic-services/page/Unified_Time_Table_2025_Batch_1"
	defaultUnifiedTTB2          = defaultBaseURL + "/srm_university/academia-academic-services/page/Unified_Time_Table_2025_batch_2"
	defaultUserAgent            = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36"
)

// ---------------------------------------------------------------------------
// Internal result types (used by login flow, not serialized directly)
// ---------------------------------------------------------------------------

type lookupResult struct {
	summary    LookupSummary
	identifier string
	digest     string
}

type passwordResult struct {
	summary     PasswordSummary
	redirectURI string
}

// ---------------------------------------------------------------------------
// LoginSession — holds the fasthttp client + login state
// ---------------------------------------------------------------------------

type LoginSession struct {
	Client     *FHClient
	Host       string
	SigninURL  string
	ServiceURL string
	URIPrefix  string
	CSRFParam  string
	CSRFCookie string
	CLITime    string
}

func NewLoginSession(email, password string) *LoginSession {
	host := "academia.srmist.edu.in"
	serviceURL := defaultBaseURL
	signinURL := defaultBaseURL + defaultSigninPath + "?serviceurl=" + url.QueryEscape(serviceURL)

	client := NewFHClient(host, defaultUserAgent)
	client.csrfParam = "iamcsrcoo"
	client.csrfCookie = "iamcsr"
	client.defaultReferer = signinURL

	return &LoginSession{
		Client:     client,
		Host:       host,
		SigninURL:  signinURL,
		ServiceURL: serviceURL,
		URIPrefix:  "/accounts/p/" + defaultPortalID,
		CSRFParam:  "iamcsrcoo",
		CSRFCookie: "iamcsr",
		CLITime:    strconv.FormatInt(time.Now().UTC().UnixMilli(), 10),
	}
}

// SeedCookies injects pre-known cookies (for fetch-only mode).
func (s *LoginSession) SeedCookies(cookies []SerializedCookie) {
	if len(cookies) == 0 {
		return
	}
	cookieMap := map[string]string{}
	for _, c := range cookies {
		if strings.TrimSpace(c.Name) == "" {
			continue
		}
		cookieMap[c.Name] = c.Value
	}
	s.Client.jar.SeedCookies(s.Host, cookieMap)
}

// SerializedCookies returns cookies in the ProbeResponse format.
func (s *LoginSession) SerializedCookies() []SerializedCookie {
	cookies := s.Client.jar.Cookies(s.Host)
	out := make([]SerializedCookie, 0, len(cookies))
	for name, value := range cookies {
		out = append(out, SerializedCookie{
			Name:  name,
			Value: value,
		})
	}
	return out
}

// CookieNames returns sorted cookie names for the host.
func (s *LoginSession) CookieNames() []string {
	return s.Client.jar.CookieNames(s.Host)
}

// ---------------------------------------------------------------------------
// Login flow steps
// ---------------------------------------------------------------------------

func (s *LoginSession) FetchSigninPage() (*SigninPageInfo, error) {
	snap, err := s.Client.DoRequest("signin_page", methodGet, s.SigninURL, nil, "", map[string]string{
		"Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
	}, true)
	if err != nil {
		return nil, fmt.Errorf("could not fetch sign-in page: %w", err)
	}

	info, err := parseSigninPage(snap.Body, snap.URL, s.ServiceURL)
	if err != nil {
		return nil, fmt.Errorf("could not parse sign-in page: %w", err)
	}

	if info.URIPathPrefix != "" {
		s.URIPrefix = info.URIPathPrefix
	}
	if info.ServiceURL != "" {
		s.ServiceURL = info.ServiceURL
	}
	if info.CSRFParam != "" {
		s.CSRFParam = info.CSRFParam
		s.Client.csrfParam = info.CSRFParam
	}
	if info.CSRFCookieName != "" {
		s.CSRFCookie = info.CSRFCookieName
		s.Client.csrfCookie = info.CSRFCookieName
	}

	return &info, nil
}

func (s *LoginSession) RunLocate() error {
	locateURL := s.ServiceURL + s.URIPrefix + "/accounts/public/api/locate?cli_time=" + url.QueryEscape(s.CLITime) + "&serviceurl=" + url.QueryEscape(s.ServiceURL)
	_, err := s.Client.DoRequest("locate", methodPost, locateURL, nil, "application/x-www-form-urlencoded;charset=UTF-8", map[string]string{
		"Accept": "application/json,text/plain,*/*",
	}, false)
	if err != nil {
		return fmt.Errorf("locate request failed: %w", err)
	}
	return nil
}

func (s *LoginSession) RunLookup(email string) (*lookupResult, error) {
	fullEmail := strings.TrimSpace(email)
	if !strings.Contains(fullEmail, "@") {
		fullEmail += "@srmist.edu.in"
	}
	encodedEmail := url.PathEscape(fullEmail)
	lookupURL := s.ServiceURL + s.URIPrefix + "/signin/v2/lookup/" + encodedEmail
	body := []byte("mode=primary&cli_time=" + url.QueryEscape(s.CLITime) + "&serviceurl=" + url.QueryEscape(s.ServiceURL))

	snap, err := s.Client.DoRequest("lookup", methodPost, lookupURL, body, "application/x-www-form-urlencoded;charset=UTF-8", map[string]string{
		"Accept": "application/json,text/plain,*/*",
	}, false)

	result := parseLookupResponse(snap.Body)
	result.summary.Attempted = true
	result.summary.StatusCode = snap.StatusCode

	if err != nil {
		return &result, fmt.Errorf("lookup request failed: %w", err)
	}
	if snap.StatusCode < 200 || snap.StatusCode > 299 {
		return &result, fmt.Errorf("lookup request returned %d", snap.StatusCode)
	}
	if result.identifier == "" || result.digest == "" {
		return &result, fmt.Errorf("lookup response did not contain identifier/digest (status=%d)", snap.StatusCode)
	}
	return &result, nil
}

func (s *LoginSession) RunPassword(identifier, digest, password string) (*passwordResult, error) {
	passwordURL := s.ServiceURL + s.URIPrefix + "/signin/v2/primary/" + url.PathEscape(identifier) + "/password?digest=" + url.QueryEscape(digest) + "&cli_time=" + url.QueryEscape(s.CLITime) + "&serviceurl=" + url.QueryEscape(s.ServiceURL)
	body := []byte(`{"passwordauth":{"password":` + strconvQuote(strings.TrimSpace(password)) + `}}`)

	snap, err := s.Client.DoRequest("password", methodPost, passwordURL, body, "application/x-www-form-urlencoded;charset=UTF-8", map[string]string{
		"Accept": "application/json,text/plain,*/*",
	}, false)

	result := parsePasswordResponse(snap.Body, snap.Location)
	result.summary.Attempted = true
	result.summary.StatusCode = snap.StatusCode
	result.summary.Location = snap.Location

	if err != nil {
		return &result, fmt.Errorf("password request failed: %w", err)
	}
	if snap.StatusCode < 200 || snap.StatusCode > 299 {
		return &result, fmt.Errorf("password request returned %d", snap.StatusCode)
	}
	return &result, nil
}

// ---------------------------------------------------------------------------
// Post-login navigation + session termination
// ---------------------------------------------------------------------------

func (s *LoginSession) CompletePostLogin(redirectURI string) (RequestSnapshot, error) {
	finalTarget := strings.TrimSpace(redirectURI)
	if finalTarget == "" {
		finalTarget = s.ServiceURL
	}

	snap, err := s.Client.DoRequest("post_login_navigation", methodGet, finalTarget, nil, "", map[string]string{
		"Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
	}, true)
	if err != nil {
		return snap, fmt.Errorf("could not open post-login target: %w", err)
	}

	return s.completePostLoginFlow(snap)
}

func (s *LoginSession) completePostLoginFlow(current RequestSnapshot) (RequestSnapshot, error) {
	last := current
	for step := 0; step < 6; step++ {
		classification, _ := classifyPage(last.URL, string(last.Body))
		switch classification {
		case classSessions:
			next, err := s.completeSessionTermination(last)
			if err != nil {
				return last, err
			}
			last = next
		case classDailyLimit:
			next, err := s.completeDailySigninWarning(last)
			if err != nil {
				return last, err
			}
			last = next
		default:
			return last, nil
		}
	}
	return last, fmt.Errorf("post-login flow did not settle after multiple continuation steps")
}

func (s *LoginSession) completeSessionTermination(current RequestSnapshot) (RequestSnapshot, error) {
	last := current
	for step := 0; step < 4; step++ {
		classification, _ := classifyPage(last.URL, string(last.Body))
		if classification != classSessions {
			return last, nil
		}

		if strings.Contains(strings.ToLower(last.URL), "/preannouncement/block-sessions") {
			next, err := s.completePreannouncementSessionTermination(last)
			if err != nil {
				return last, err
			}
			last = next
			continue
		}

		actions := extractContinuationActions(string(last.Body), last.URL)
		if len(actions) == 0 {
			actionURL := extractSessionContinueURL(string(last.Body), last.URL)
			if actionURL == "" {
				actionURL = deriveSessionContinueURL(last.URL)
			}
			if actionURL != "" {
				actions = append(actions, sessionAction{
					name:   "session_terminate_fallback",
					method: methodGet,
					url:    actionURL,
				})
			}
		}
		if len(actions) == 0 {
			return last, fmt.Errorf("session reminder page did not expose a terminate action")
		}

		var lastErr error
		progressed := false
		for _, action := range actions {
			snap, err := s.Client.DoRequest(action.name, action.method, action.url, action.body, action.contentType, map[string]string{
				"Accept":  "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
				"Referer": last.URL,
			}, true)
			if err != nil {
				lastErr = err
				continue
			}
			last = snap
			progressed = true
			classification, _ = classifyPage(last.URL, string(last.Body))
			if classification != classSessions {
				return last, nil
			}
		}

		if !progressed {
			if lastErr != nil {
				return last, fmt.Errorf("session termination request failed: %w", lastErr)
			}
			return last, fmt.Errorf("session termination actions did not change the page state")
		}
	}

	return last, fmt.Errorf("session reminder flow did not complete after multiple attempts")
}

func (s *LoginSession) completePreannouncementSessionTermination(current RequestSnapshot) (RequestSnapshot, error) {
	deleteURL := derivePreannouncementDeleteURL(current.URL)
	if deleteURL == "" {
		return current, fmt.Errorf("preannouncement block-sessions page did not expose a terminate endpoint")
	}

	deleteSnap, err := s.Client.DoRequest("session_terminate_delete", methodDelete, deleteURL, nil, "", map[string]string{
		"Accept":           "application/json,text/plain,*/*",
		"X-Requested-With": "XMLHttpRequest",
		"Referer":          current.URL,
	}, false)
	if err != nil {
		return current, fmt.Errorf("preannouncement terminate request failed: %w", err)
	}
	if deleteSnap.StatusCode < 200 || deleteSnap.StatusCode > 299 {
		return current, fmt.Errorf("preannouncement terminate request returned %d", deleteSnap.StatusCode)
	}

	actionURL := deriveSessionContinueURL(current.URL)
	if actionURL == "" {
		return current, fmt.Errorf("preannouncement block-sessions page did not expose a continuation URL")
	}

	nextSnap, err := s.Client.DoRequest("session_terminate_next", methodGet, actionURL, nil, "", map[string]string{
		"Accept":  "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
		"Referer": current.URL,
	}, true)
	if err != nil {
		return current, fmt.Errorf("preannouncement continuation request failed: %w", err)
	}
	return nextSnap, nil
}

func (s *LoginSession) completeDailySigninWarning(current RequestSnapshot) (RequestSnapshot, error) {
	actions := extractContinuationActions(string(current.Body), current.URL)
	if len(actions) == 0 {
		actionURL := extractSessionContinueURL(string(current.Body), current.URL)
		if actionURL == "" {
			actionURL = deriveSessionContinueURL(current.URL)
		}
		if actionURL != "" {
			actions = append(actions, sessionAction{
				name:   "daily_signin_continue_fallback",
				method: methodGet,
				url:    actionURL,
			})
		}
	}
	if len(actions) == 0 {
		return current, fmt.Errorf("daily sign-in warning page did not expose an acknowledgement action")
	}

	var lastErr error
	for _, action := range actions {
		snap, err := s.Client.DoRequest(action.name, action.method, action.url, action.body, action.contentType, map[string]string{
			"Accept":  "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
			"Referer": current.URL,
		}, true)
		if err != nil {
			lastErr = err
			continue
		}
		return snap, nil
	}

	if lastErr != nil {
		return current, fmt.Errorf("daily sign-in acknowledgement failed: %w", lastErr)
	}
	return current, fmt.Errorf("daily sign-in acknowledgement failed")
}

// ---------------------------------------------------------------------------
// Authentication checks
// ---------------------------------------------------------------------------

// PrimePortalSession loads the academia home page with seeded cookies so Zoho
// can refresh CSRF / path cookies before XHR fragment fetches. Fetch-only mode
// used to hit My_Attendance immediately in a cold process and often got 403.
func (s *LoginSession) PrimePortalSession() (RequestSnapshot, error) {
	if !s.IsAuthenticated() {
		return RequestSnapshot{}, fmt.Errorf("session expired: JSESSIONID missing")
	}

	snap, err := s.Client.DoRequest("portal_prime", methodGet, s.ServiceURL+"/", nil, "", map[string]string{
		"Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
	}, true)
	if err != nil {
		return snap, fmt.Errorf("portal prime failed: %w", err)
	}
	if looksLikeUnauthenticatedPage(snap.URL, string(snap.Body)) {
		return snap, fmt.Errorf("session expired: portal redirected to sign-in")
	}
	if snap.StatusCode == 401 || snap.StatusCode == 403 {
		return snap, fmt.Errorf("session expired: portal returned %d", snap.StatusCode)
	}
	if snap.StatusCode < 200 || snap.StatusCode > 299 {
		return snap, fmt.Errorf("portal prime returned %d", snap.StatusCode)
	}
	return snap, nil
}

func (s *LoginSession) IsAuthenticated() bool {
	return s.Client.jar.HasCookie(s.Host, "JSESSIONID")
}

func (s *LoginSession) looksAuthenticated(current RequestSnapshot) bool {
	if s.IsAuthenticated() {
		return true
	}
	lowerURL := strings.ToLower(current.URL)
	return strings.HasPrefix(lowerURL, strings.ToLower(s.ServiceURL)) &&
		!strings.Contains(lowerURL, "/accounts/p/") &&
		!strings.Contains(lowerURL, "/signin")
}

// ---------------------------------------------------------------------------
// Full login (convenience for test harness)
// ---------------------------------------------------------------------------

func (s *LoginSession) FullLogin(email, password string) (string, error) {
	if _, err := s.FetchSigninPage(); err != nil {
		return "", err
	}
	if err := s.RunLocate(); err != nil {
		return "", err
	}
	lookup, err := s.RunLookup(email)
	if err != nil {
		return "", err
	}
	pwd, err := s.RunPassword(lookup.identifier, lookup.digest, password)
	if err != nil {
		return "", err
	}
	snap, err := s.CompletePostLogin(pwd.redirectURI)
	if err != nil {
		return "", err
	}
	if !s.IsAuthenticated() {
		return snap.URL, fmt.Errorf("login completed but JSESSIONID not established")
	}
	return snap.URL, nil
}

// ---------------------------------------------------------------------------
// Fragment fetching
// ---------------------------------------------------------------------------

func (s *LoginSession) fetchDecodedFragment(name, rawURL, referer string) (string, decodedFragmentDebug, error) {
	debug := decodedFragmentDebug{}
	snap, err := s.Client.DoRequest(name, methodGet, rawURL, nil, "", map[string]string{
		"Accept":           "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
		"X-Requested-With": "XMLHttpRequest",
		"Referer":          referer,
	}, false)
	if err != nil {
		return "", debug, fmt.Errorf("%s request failed: %w", name, err)
	}

	debug.statusCode = snap.StatusCode
	if ct, ok := snap.Headers["Content-Type"]; ok {
		debug.contentType = ct
	}
	if snap.StatusCode < 200 || snap.StatusCode > 299 {
		return "", debug, fmt.Errorf("%s request returned %d", name, snap.StatusCode)
	}

	body := string(snap.Body)

	decoded, payload, decodeErr := decodeSanitizedHTML(body)
	if decodeErr == nil {
		debug.payloadFound = payload != ""
		debug.payloadLength = len(payload)
		return decoded, debug, nil
	}

	decoded, payload, zmlErr := decodeZMLValueHTML(body)
	if zmlErr == nil {
		debug.payloadFound = payload != ""
		debug.payloadLength = len(payload)
		return decoded, debug, nil
	}

	if strings.Contains(strings.ToLower(body), "<table") || strings.Contains(strings.ToLower(body), "<html") {
		return body, debug, nil
	}

	return "", debug, fmt.Errorf("%v; %v", decodeErr, zmlErr)
}

// ---------------------------------------------------------------------------
// Student photo fetching
// ---------------------------------------------------------------------------

func (s *LoginSession) fetchStudentPhotoDataURL(photoSrc string) (string, error) {
	snap, err := s.Client.DoRequest("student_photo", methodGet, photoSrc, nil, "", map[string]string{
		"Accept":  "image/avif,image/webp,image/apng,image/*,*/*;q=0.8",
		"Referer": s.ServiceURL + "/#Report:Student_Profile_Report",
	}, true)
	if err != nil {
		return "", fmt.Errorf("student photo request failed: %w", err)
	}
	if snap.StatusCode < 200 || snap.StatusCode > 299 {
		return "", fmt.Errorf("student photo request returned %d", snap.StatusCode)
	}
	if len(snap.Body) == 0 {
		return "", fmt.Errorf("student photo response was empty")
	}

	contentType := strings.TrimSpace(snap.Headers["Content-Type"])
	if contentType == "" {
		contentType = guessImageContentType(photoSrc)
	}
	lowerContentType := strings.ToLower(contentType)
	if strings.Contains(lowerContentType, "application/octet-stream") {
		contentType = guessImageContentType(photoSrc)
		lowerContentType = strings.ToLower(contentType)
	}
	if !strings.HasPrefix(lowerContentType, "image/") {
		return "", fmt.Errorf("student photo response was not an image (%s)", contentType)
	}

	return "data:" + contentType + ";base64," + base64StdEncoding.EncodeToString(snap.Body), nil
}

// ---------------------------------------------------------------------------
// Section bundle fetchers (parallel-safe, write to disjoint Data fields)
// ---------------------------------------------------------------------------

func (s *LoginSession) fetchAttendanceBundle(required map[string]bool, data *FetchData, mu *sync.Mutex) (AttendanceSummary, error) {
	summary := AttendanceSummary{Attempted: true}
	decoded, debug, err := s.fetchDecodedFragment(
		"attendance",
		defaultAttendanceURL,
		s.ServiceURL+"/#Page:My_Attendance",
	)
	summary.StatusCode = debug.statusCode
	summary.Debug.ResponseContentType = debug.contentType
	summary.Debug.PayloadFound = debug.payloadFound
	summary.Debug.PayloadLength = debug.payloadLength
	summary.Debug.DecodedLength = len(decoded)
	summary.Debug.DecodedHasCourse = strings.Contains(decoded, "Course Code")
	summary.Debug.DecodedHasAttn = strings.Contains(decoded, "Attn %")
	summary.Debug.DecodedHasHours = strings.Contains(decoded, "Hours Conducted")
	if err != nil {
		summary.Error = err.Error()
		return summary, fmt.Errorf("%s", summary.Error)
	}

	records, headers, err := parseAttendance(decoded)
	summary.Debug.MatchedHeaders = headers
	summary.Debug.MatchedRowCount = len(records)
	if err != nil {
		if required["attendance"] {
			summary.Error = err.Error()
			return summary, fmt.Errorf("%s", summary.Error)
		}
		recordSectionError(data, mu, "attendance", err)
	}

	attendance := []AttendanceRecord{}
	if err == nil {
		attendance = mapAttendanceRows(records)
	}

	info, infoErr := parseStudentInfoHTML(decoded)
	if infoErr != nil {
		recordSectionError(data, mu, "studentInfo", infoErr)
	} else if len(info) > 0 {
		photoCandidate, _ := extractStudentPhotoDownloadURL(decoded)
		if photoCandidate == "" {
			photoCandidate, _ = extractStudentPhotoSource(decoded)
		}
		if photoCandidate != "" {
			if photoDataURL, photoErr := s.fetchStudentPhotoDataURL(photoCandidate); photoErr == nil {
				info["PhotoUrl"] = photoDataURL
			} else {
				info["PhotoUrl"] = photoCandidate
			}
		}

		if info["PhotoUrl"] == "" {
			snap, reqErr := s.Client.DoRequest(
				"student_profile_report",
				methodGet,
				s.ServiceURL+"/srm_university/academia-academic-services/report/Student_Profile_Report",
				nil, "",
				map[string]string{
					"X-Requested-With": "XMLHttpRequest",
					"Referer":          s.ServiceURL + "/#Report:Student_Profile_Report",
				},
				true,
			)

			profileHTML := ""
			if reqErr == nil && snap.StatusCode == 200 {
				profileHTML = string(snap.Body)
			}

			if profileHTML != "" {
				var photoRawHTML string

				startIdx := strings.Index(profileHTML, `{"HTML":`)
				if startIdx >= 0 {
					var parsedData struct {
						Model struct {
							DataJSONArray []map[string]any `json:"DATAJSONARRAY"`
						} `json:"MODEL"`
					}
					if err := json.Unmarshal([]byte(profileHTML[startIdx:]), &parsedData); err == nil {
						if len(parsedData.Model.DataJSONArray) > 0 {
							if photoVal, ok := parsedData.Model.DataJSONArray[0]["Your_Photo"].(string); ok {
								photoRawHTML = photoVal
							}
						}
					}
				}

				if photoRawHTML == "" {
					marker := `"Your_Photo":"`
					if idx := strings.Index(profileHTML, marker); idx >= 0 {
						endIdx := strings.Index(profileHTML[idx+len(marker):], `"}}`)
						if endIdx >= 0 {
							rawValue := profileHTML[idx+len(marker) : idx+len(marker)+endIdx]
							rawValue = strings.ReplaceAll(rawValue, `\"`, `"`)
							rawValue = strings.ReplaceAll(rawValue, `\/`, `/`)
							photoRawHTML = rawValue
						}
					}
				}

				var photoCandidate string
				if photoRawHTML != "" {
					photoCandidate, _ = extractStudentPhotoDownloadURL("<html>" + photoRawHTML + "</html>")
					if photoCandidate == "" {
						photoCandidate, _ = extractStudentPhotoSource("<html>" + photoRawHTML + "</html>")
					}
				}

				if photoCandidate == "" {
					photoCandidate, _ = extractStudentPhotoDownloadURL(profileHTML)
					if photoCandidate == "" {
						photoCandidate, _ = extractStudentPhotoSource(profileHTML)
					}
				}

				if photoCandidate != "" {
					if photoDataURL, photoErr := s.fetchStudentPhotoDataURL(photoCandidate); photoErr == nil {
						info["PhotoUrl"] = photoDataURL
					}
					if info["PhotoUrl"] == "" {
						info["PhotoUrl"] = photoCandidate
					}
				}
			}
		}

		mu.Lock()
		data.StudentInfo = info
		mu.Unlock()
	}

	marks, marksErr := parseMarksHTML(decoded)
	if marksErr != nil {
		recordSectionError(data, mu, "marks", marksErr)
	} else if len(marks) > 0 {
		mu.Lock()
		data.Marks = marks
		mu.Unlock()
	}

	if len(attendance) > 0 {
		mu.Lock()
		data.Attendance = attendance
		mu.Unlock()
	}

	summary.Success = len(attendance) > 0
	summary.Rows = len(attendance)
	if required["attendance"] && !summary.Success {
		summary.Error = "attendance table parsed but contained no data rows"
		return summary, fmt.Errorf("%s", summary.Error)
	}
	if required["studentinfo"] && len(data.StudentInfo) == 0 {
		return summary, fmt.Errorf("student info could not be parsed from attendance bundle")
	}
	if required["marks"] && len(data.Marks) == 0 {
		return summary, fmt.Errorf("marks could not be parsed from attendance bundle")
	}
	return summary, nil
}

func (s *LoginSession) fetchTimetableBundle(data *FetchData, mu *sync.Mutex) error {
	decoded, _, err := s.fetchDecodedFragment(
		"personal_timetable",
		defaultPersonalTTURL,
		s.ServiceURL+"/#Page:My_Time_Table_2023_24",
	)
	if err != nil {
		return err
	}

	batch, rawCourses, advisors, err := parsePersonalTimetableHTML(decoded)
	if err != nil {
		return err
	}

	unifiedURL := defaultUnifiedTTB1
	unifiedName := "unified_timetable_batch_1"
	unifiedReferer := s.ServiceURL + "/#Page:Unified_Time_Table_2025_Batch_1"
	if strings.TrimSpace(batch) == "2" {
		unifiedURL = defaultUnifiedTTB2
		unifiedName = "unified_timetable_batch_2"
		unifiedReferer = s.ServiceURL + "/#Page:Unified_Time_Table_2025_batch_2"
	}

	unifiedHTML, _, err := s.fetchDecodedFragment(unifiedName, unifiedURL, unifiedReferer)
	if err != nil {
		return err
	}

	slotMap, err := parseBatchSlotMapHTML(unifiedHTML)
	if err != nil {
		return err
	}

	courses := mergeTimetableCourses(rawCourses, slotMap)
	mu.Lock()
	data.Timetable = &TimetableResult{
		Batch:    batch,
		Courses:  courses,
		Advisors: advisors,
	}
	mu.Unlock()
	return nil
}

func (s *LoginSession) fetchCalendars(targetSems []string, data *FetchData, mu *sync.Mutex) error {
	calendarResults := map[string]CalendarResult{}

	type calendarCandidate struct {
		url     string
		referer string
		name    string
	}

	candidatesFor := func(sem string) []calendarCandidate {
		yearPairs := []string{"2026_27", "2025_26", "2024_25"}
		semToken := strings.ToUpper(sem)
		out := make([]calendarCandidate, 0, len(yearPairs))
		for _, year := range yearPairs {
			pageName := fmt.Sprintf("Academic_Planner_%s_%s", year, semToken)
			out = append(out, calendarCandidate{
				url:     defaultBaseURL + "/srm_university/academia-academic-services/page/" + pageName,
				referer: s.ServiceURL + "/#Page:" + pageName,
				name:    "calendar_" + sem + "_" + pageName,
			})
		}
		return out
	}

	fetchSem := func(sem string) (CalendarResult, error) {
		var lastErr error
		for _, target := range candidatesFor(sem) {
			decoded, _, err := s.fetchDecodedFragment(target.name, target.url, target.referer)
			if err != nil {
				lastErr = err
				continue
			}

			if looksLikeUnauthenticatedPage(target.url, decoded) || strings.Contains(extractHTMLTitle(decoded), "Login") {
				lastErr = fmt.Errorf("got login shell for %s", target.url)
				continue
			}

			calendar, err := parseAcademicCalendarHTML(decoded, sem)
			if err != nil {
				lastErr = fmt.Errorf("%w (page=%s decodedLen=%d title=%q)", err, target.url, len(decoded), extractHTMLTitle(decoded))
				continue
			}

			return calendar, nil
		}
		return CalendarResult{}, lastErr
	}

	type semResult struct {
		sem      string
		calendar CalendarResult
		err      error
	}

	var selectedSems []string
	for _, sem := range []string{"odd", "even"} {
		if len(targetSems) > 0 && !containsString(targetSems, sem) {
			continue
		}
		selectedSems = append(selectedSems, sem)
	}

	results := make([]semResult, len(selectedSems))
	var wg sync.WaitGroup
	for i, sem := range selectedSems {
		wg.Add(1)
		go func(i int, sem string) {
			defer wg.Done()
			calendar, err := fetchSem(sem)
			results[i] = semResult{sem: sem, calendar: calendar, err: err}
		}(i, sem)
	}
	wg.Wait()

	for _, res := range results {
		if res.err != nil {
			recordSectionError(data, mu, "calendar_"+res.sem, res.err)
			continue
		}
		calendarResults[res.sem] = res.calendar
	}

	if len(calendarResults) > 0 {
		mu.Lock()
		data.Calendars = calendarResults
		mu.Unlock()
	}
	return nil
}

// recordSectionError safely records a section error into FetchData.Errors.
func recordSectionError(data *FetchData, mu *sync.Mutex, section string, err error) {
	if err == nil {
		return
	}
	mu.Lock()
	defer mu.Unlock()
	if data.Errors == nil {
		data.Errors = map[string]string{}
	}
	data.Errors[section] = err.Error()
}
