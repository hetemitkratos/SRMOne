package main

import (
	"encoding/json"
	"fmt"
	"os"
	"strings"
	"sync"
	"time"
)

const (
	baseAPIURL  = "https://app.haveloc.com/app"
	chatBaseURL = "https://chat.haveloc.com/communication"
	userAgent   = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36"
)

// ---------------------------------------------------------------------------
// Login / MFA / Session
// ---------------------------------------------------------------------------

func login(client *FHClient, username, password string) (*LoginResponse, error) {
	body := map[string]string{
		"username": username,
		"password": password,
	}

	raw, status, err := client.doRequest("POST", baseAPIURL+"/sign-in", body)
	if err != nil {
		if status == 409 && raw != nil {
			var conflict struct {
				SessionLimitReached bool `json:"sessionLimitReached"`
				ActiveSessions      []struct {
					SessionUUID      string `json:"sessionUuid"`
					RevocationSecret string `json:"revocationSecret"`
				} `json:"activeSessions"`
			}
			if jsonErr := json.Unmarshal(*raw, &conflict); jsonErr == nil && conflict.SessionLimitReached {
				for _, s := range conflict.ActiveSessions {
					revokeSession(client, s.SessionUUID, s.RevocationSecret)
				}
				raw, status, err = client.doRequest("POST", baseAPIURL+"/sign-in", body)
				if err != nil {
					return nil, fmt.Errorf("login failed after revoking sessions: %w", err)
				}
			} else {
				return nil, fmt.Errorf("session limit reached")
			}
		} else {
			return nil, err
		}
	}

	var loginResp LoginResponse
	if err := json.Unmarshal(*raw, &loginResp); err != nil {
		return nil, fmt.Errorf("parse login response: %w", err)
	}

	return &loginResp, nil
}

func revokeSession(client *FHClient, sessionUUID, revocationSecret string) {
	body := map[string]string{
		"sessionUuid":      sessionUUID,
		"revocationSecret": revocationSecret,
	}
	client.doRequest("POST", baseAPIURL+"/sign-in/revoke-session", body)
}

func verifyTOTP(client *FHClient, mfaToken, totpCode, emailOtp string) (*LoginResponse, error) {
	body := map[string]interface{}{
		"mfaToken": mfaToken,
	}
	if emailOtp != "" {
		body["emailOtp"] = strings.TrimSpace(emailOtp)
	} else {
		body["totpCode"] = totpCode
	}

	raw, _, err := client.doRequest("POST", baseAPIURL+"/sign-in/totp", body)
	if err != nil {
		return nil, err
	}

	var resp LoginResponse
	if err := json.Unmarshal(*raw, &resp); err != nil {
		return nil, fmt.Errorf("parse totp response: %w", err)
	}
	return &resp, nil
}

func sendMFAPrompt(client *FHClient, mfaToken string) error {
	body := map[string]string{"mfaToken": mfaToken}
	_, _, err := client.doRequest("POST", baseAPIURL+"/sign-in/mfa-email", body)
	return err
}

func signOut(client *FHClient) error {
	_, _, err := client.doRequest("GET", baseAPIURL+"/sign-out", nil)
	return err
}

// ---------------------------------------------------------------------------
// Section fetchers
// ---------------------------------------------------------------------------

func fetchCompanies(client *FHClient, page, size int, sort string) (*json.RawMessage, error) {
	if sort == "" {
		sort = "name,asc"
	}
	if size == 0 {
		size = 20
	}
	if page > 0 {
		url := fmt.Sprintf("%s/companyViews?respectConfigProp=false&sort=%s&size=%d&page=%d", baseAPIURL, sort, size, page)
		raw, _, err := client.doRequest("POST", url, []interface{}{})
		return raw, err
	}
	return fetchAllPages(client, fmt.Sprintf("%s/companyViews?respectConfigProp=false&sort=%s&size=%d", baseAPIURL, sort, size), []interface{}{})
}

func fetchJobs(client *FHClient, page, size int, sort string, filters []Filter) (*json.RawMessage, error) {
	if sort == "" {
		sort = "jobApplyBy,desc"
	}
	if size == 0 {
		size = 20
	}

	body := []interface{}{}
	for _, f := range filters {
		body = append(body, f)
	}

	if page > 0 {
		url := fmt.Sprintf("%s/studentJobSubViews?sort=%s&size=%d&page=%d", baseAPIURL, sort, size, page)
		raw, _, err := client.doRequest("POST", url, body)
		return raw, err
	}
	return fetchAllPages(client, fmt.Sprintf("%s/studentJobSubViews?sort=%s&size=%d", baseAPIURL, sort, size), body)
}

// fetchAllPages fetches all pages in parallel.
// First page is fetched to determine total page count, then remaining pages
// are fetched concurrently (no sleep between pages).
func fetchAllPages(client *FHClient, baseURL string, body interface{}) (*json.RawMessage, error) {
	// Fetch first page to get totalPages
	firstURL := baseURL + "&page=0"
	raw, _, err := client.doRequest("POST", firstURL, body)
	if err != nil {
		return raw, err
	}

	var resp struct {
		Embedded struct {
			EntityModels []json.RawMessage `json:"entityModels"`
		} `json:"_embedded"`
		Page struct {
			TotalPages int `json:"totalPages"`
		} `json:"page"`
	}
	if err := json.Unmarshal(*raw, &resp); err != nil {
		return raw, nil // return first page as-is if parse fails
	}

	totalPages := resp.Page.TotalPages
	if totalPages <= 1 {
		return raw, nil
	}

	// Collect all entityModels from page 0
	allModels := make([]json.RawMessage, 0, len(resp.Embedded.EntityModels))
	allModels = append(allModels, resp.Embedded.EntityModels...)

	// Fetch remaining pages in parallel
	type pageResult struct {
		pageIndex int
		models    []json.RawMessage
		err       error
	}

	results := make([]pageResult, totalPages-1)
	var wg sync.WaitGroup

	for p := 1; p < totalPages; p++ {
		wg.Add(1)
		go func(idx, pageNum int) {
			defer wg.Done()
			pageURL := fmt.Sprintf("%s&page=%d", baseURL, pageNum)
			pageRaw, _, pageErr := client.doRequest("POST", pageURL, body)
			if pageErr != nil {
				fmt.Fprintf(os.Stderr, "[paginate] page %d failed: %v\n", pageNum, pageErr)
				results[idx] = pageResult{pageIndex: pageNum, err: pageErr}
				return
			}
			var pageResp struct {
				Embedded struct {
					EntityModels []json.RawMessage `json:"entityModels"`
				} `json:"_embedded"`
			}
			if err := json.Unmarshal(*pageRaw, &pageResp); err != nil {
				fmt.Fprintf(os.Stderr, "[paginate] page %d parse failed: %v\n", pageNum, err)
				results[idx] = pageResult{pageIndex: pageNum, err: err}
				return
			}
			results[idx] = pageResult{pageIndex: pageNum, models: pageResp.Embedded.EntityModels}
		}(p-1, p)
	}
	wg.Wait()

	// Append pages in order
	for _, res := range results {
		if res.err != nil {
			continue
		}
		allModels = append(allModels, res.models...)
	}

	// Build merged response preserving the original structure
	var merged map[string]interface{}
	if err := json.Unmarshal(*raw, &merged); err != nil {
		return raw, nil
	}
	if embedded, ok := merged["_embedded"].(map[string]interface{}); ok {
		embedded["entityModels"] = allModels
	}
	if page, ok := merged["page"].(map[string]interface{}); ok {
		page["totalElements"] = len(allModels)
		page["totalPages"] = 1
		page["number"] = 0
	}
	mergedJSON, err := json.Marshal(merged)
	if err != nil {
		return raw, nil
	}
	result := json.RawMessage(mergedJSON)
	return &result, nil
}

func fetchJobTracker(client *FHClient, uuid string, page, size int) (*json.RawMessage, error) {
	if size == 0 {
		size = 50
	}
	if page > 0 {
		url := fmt.Sprintf("%s/jobTrackerViews/studentUuid/%s?respectConfigProp=false&sort=lastModifiedDate,desc&page=%d&size=%d",
			baseAPIURL, uuid, page, size)
		raw, _, err := client.doRequest("POST", url, []interface{}{})
		return raw, err
	}
	baseURL := fmt.Sprintf("%s/jobTrackerViews/studentUuid/%s?respectConfigProp=false&sort=lastModifiedDate,desc&size=%d",
		baseAPIURL, uuid, size)
	return fetchAllPages(client, baseURL, []interface{}{})
}

func fetchStudentProfile(client *FHClient, uuid string) (*json.RawMessage, error) {
	url := fmt.Sprintf("%s/studentViews/u/%s", baseAPIURL, uuid)
	raw, _, err := client.doRequest("GET", url, nil)
	return raw, err
}

func fetchPlacementCycles(client *FHClient, cycleID int) (*json.RawMessage, error) {
	url := fmt.Sprintf("%s/placementCycles/basic/%d", baseAPIURL, cycleID)
	raw, _, err := client.doRequest("POST", url, map[string]interface{}{})
	return raw, err
}

func fetchStudentStats(client *FHClient, uuid string) (*json.RawMessage, error) {
	url := fmt.Sprintf("%s/studentStatsByStudentUuid?studentUuid=%s&respectConfigProp=false", baseAPIURL, uuid)
	raw, _, err := client.doRequest("POST", url, []interface{}{})
	return raw, err
}

func fetchNotices(client *FHClient, page, size int) (*json.RawMessage, error) {
	if size == 0 {
		size = 20
	}
	url := fmt.Sprintf("%s/notification?page=%d&size=%d&sort=createdDate,desc", baseAPIURL, page, size)
	raw, _, err := client.doRequest("POST", url, []interface{}{})
	return raw, err
}

func fetchGlobalPolicy(client *FHClient) (*json.RawMessage, error) {
	raw, _, err := client.doRequest("POST", baseAPIURL+"/globalPolicy", map[string]interface{}{})
	return raw, err
}

func fetchPolicies(client *FHClient) (*json.RawMessage, error) {
	url := baseAPIURL + "/policies?sort=startRange,asc"
	raw, _, err := client.doRequest("POST", url, []interface{}{})
	return raw, err
}

func fetchCalendar(client *FHClient, startDate, endDate string) (*json.RawMessage, error) {
	url := fmt.Sprintf("%s/placementCalendar/dateRange?startDate=%s&endDate=%s", baseAPIURL, startDate, endDate)
	raw, _, err := client.doRequest("POST", url, map[string]interface{}{})
	return raw, err
}

func fetchInsights(client *FHClient) (*json.RawMessage, error) {
	url := baseAPIURL + "/haveloc-insights?requestAPI=overall/get_college_course_branch_list"
	raw, _, err := client.doRequest("POST", url, map[string]interface{}{})
	return raw, err
}

func fetchChatInbox(client *FHClient) (*json.RawMessage, error) {
	url := chatBaseURL + "/v1/comm/inbox?archived=false"
	raw, _, err := client.doRequest("GET", url, nil)
	return raw, err
}

func fetchChatUnread(client *FHClient) (*json.RawMessage, error) {
	url := chatBaseURL + "/v1/comm/inbox/unread-summary"
	raw, _, err := client.doRequest("GET", url, nil)
	return raw, err
}

func fetchStudentSocialMedia(client *FHClient, uuid string) (*json.RawMessage, error) {
	url := fmt.Sprintf("%s/studentSocialMedia/studentUuid/%s", baseAPIURL, uuid)
	raw, _, err := client.doRequest("POST", url, []interface{}{})
	return raw, err
}

func fetchJobView(client *FHClient, jobUUID string) (*json.RawMessage, error) {
	url := fmt.Sprintf("%s/jobViews/u/%s", baseAPIURL, jobUUID)
	raw, _, err := client.doRequest("POST", url, map[string]interface{}{})
	return raw, err
}

func fetchJobAttachments(client *FHClient, jobUUID string) (*json.RawMessage, error) {
	url := fmt.Sprintf("%s/jobAttachments/jobUuid/%s", baseAPIURL, jobUUID)
	raw, _, err := client.doRequest("POST", url, map[string]interface{}{})
	return raw, err
}

func fetchStudentDocuments(client *FHClient, studentUUID string) (*json.RawMessage, error) {
	url := fmt.Sprintf("%s/studentDocumentService/studentUuid/%s", baseAPIURL, studentUUID)
	raw, _, err := client.doRequest("POST", url, map[string]interface{}{})
	return raw, err
}

func applyForJob(client *FHClient, jobUUID string, jobID int, answers []ApplyAnswer, resumeName string) (*json.RawMessage, int, error) {
	url := baseAPIURL + "/jobTrackerApply"

	answerBeans := make([]map[string]interface{}, len(answers))
	for i, a := range answers {
		answerBeans[i] = map[string]interface{}{
			"questionId":      a.QuestionID,
			"responseOptions": a.ResponseOptions,
		}
	}

	body := map[string]interface{}{
		"jobUuid":               jobUUID,
		"jobId":                 jobID,
		"jobAppliedAnswerBeans": answerBeans,
		"resumeName":            resumeName,
	}

	raw, status, err := client.doRequest("PUT", url, body)
	return raw, status, err
}

// ---------------------------------------------------------------------------
// JD (job description) download
// ---------------------------------------------------------------------------

func fetchJD(client *FHClient, fileURL string, jobUUID string) ([]byte, string, error) {
	if strings.Contains(fileURL, "hlc-secure-url") {
		return client.fetchDirect(fileURL)
	}

	if jobUUID != "" {
		raw, err := fetchJobAttachments(client, jobUUID)
		if err != nil {
			return nil, "", fmt.Errorf("fetch job attachments: %w", err)
		}

		var attachments []map[string]interface{}
		if err := json.Unmarshal(*raw, &attachments); err != nil {
			var wrapper struct {
				Embedded struct {
					EntityModels []map[string]interface{} `json:"entityModels"`
				} `json:"_embedded"`
			}
			if err2 := json.Unmarshal(*raw, &wrapper); err2 == nil && len(wrapper.Embedded.EntityModels) > 0 {
				attachments = wrapper.Embedded.EntityModels
			} else {
				return nil, "", fmt.Errorf("parse job attachments: %w", err)
			}
		}

		for _, att := range attachments {
			if attachmentURL, ok := att["attachmentUrl"].(string); ok && attachmentURL != "" {
				fmt.Fprintf(os.Stderr, "[JD] Found attachmentUrl: %s\n", attachmentURL)
				return client.fetchDirect(attachmentURL)
			}
		}

		fmt.Fprintf(os.Stderr, "[JD] No attachmentUrl found in job attachments response, count=%d\n", len(attachments))
		return nil, "", fmt.Errorf("no attachment URL found in job attachments")
	}

	return nil, "", fmt.Errorf("JD download failed: no job UUID and not a secure URL")
}

// ---------------------------------------------------------------------------
// Section dispatcher
// ---------------------------------------------------------------------------

func fetchSection(client *FHClient, section string, req ScraperRequest) (*json.RawMessage, error) {
	switch section {
	case "companies":
		return fetchCompanies(client, req.Page, req.Size, req.Sort)
	case "jobs":
		return fetchJobs(client, req.Page, req.Size, req.Sort, req.Filters)
	case "tracker":
		return fetchJobTracker(client, req.UUID, req.Page, req.Size)
	case "profile":
		return fetchStudentProfile(client, req.UUID)
	case "placementCycles":
		return fetchPlacementCycles(client, 136)
	case "studentStats":
		return fetchStudentStats(client, req.UUID)
	case "notices":
		return fetchNotices(client, req.Page, req.Size)
	case "globalPolicy":
		return fetchGlobalPolicy(client)
	case "policies":
		return fetchPolicies(client)
	case "calendar":
		startDate := req.StartDate
		endDate := req.EndDate
		if startDate == "" {
			now := time.Now()
			startDate = now.AddDate(0, -1, 0).Format("2006-01-02T15:04:05.000Z")
			endDate = now.AddDate(0, 1, 0).Format("2006-01-02T15:04:05.000Z")
		}
		return fetchCalendar(client, startDate, endDate)
	case "insights":
		return fetchInsights(client)
	case "chatInbox":
		return fetchChatInbox(client)
	case "chatUnread":
		return fetchChatUnread(client)
	case "socialMedia":
		return fetchStudentSocialMedia(client, req.UUID)
	case "jobView":
		return fetchJobView(client, req.JobUUID)
	case "jobAttachments":
		return fetchJobAttachments(client, req.JobUUID)
	case "studentDocuments":
		return fetchStudentDocuments(client, req.UUID)
	case "probeAttendance":
		return probeAttendance(client, req.UUID, req.JobUUID)
	default:
		return nil, fmt.Errorf("unknown section: %s", section)
	}
}

// ---------------------------------------------------------------------------
// Attendance probe (debugging — keeps sequential 200ms sleep intentionally)
// ---------------------------------------------------------------------------

func probeAttendance(client *FHClient, studentUuid, jobUuid string) (*json.RawMessage, error) {
	type probeResult struct {
		Path   string `json:"path"`
		Method string `json:"method"`
		Status int    `json:"status"`
		Body   string `json:"body"`
	}
	results := []probeResult{}

	probePaths := []struct {
		method string
		path   string
		body   interface{}
	}{
		{"GET", fmt.Sprintf("/app/jobTrackerViews/%s/attendance", studentUuid), nil},
		{"GET", fmt.Sprintf("/app/jobTrackerViews/studentUuid/%s/attendance", studentUuid), nil},
		{"GET", fmt.Sprintf("/app/jobTrackerViews/studentUuid/%s/markAttendance", studentUuid), nil},
		{"GET", fmt.Sprintf("/app/jobTrackerViews/studentUuid/%s/confirmAttendance", studentUuid), nil},
		{"GET", fmt.Sprintf("/app/jobTrackerViews/studentUuid/%s/selfAttendance", studentUuid), nil},
		{"GET", fmt.Sprintf("/app/studentAttendance/studentUuid/%s", studentUuid), nil},
		{"GET", fmt.Sprintf("/app/studentAttendance/%s", studentUuid), nil},
		{"GET", fmt.Sprintf("/app/attendance/student/%s", studentUuid), nil},
		{"GET", fmt.Sprintf("/app/attendance/mark/student/%s", studentUuid), nil},
		{"GET", fmt.Sprintf("/app/attendance/confirm/student/%s", studentUuid), nil},
		{"GET", fmt.Sprintf("/app/jobTrackerViews/attendance/student/%s", studentUuid), nil},
		{"GET", "/app/attendance", nil},
		{"GET", "/app/attendanceTypes", nil},
		{"GET", "/app/studentAttendanceTypes", nil},
		{"POST", fmt.Sprintf("/app/jobTrackerViews/studentUuid/%s/confirmAttendance", studentUuid), map[string]interface{}{"jobUuid": jobUuid, "isStudentConfirmedToAttend": true}},
		{"POST", fmt.Sprintf("/app/jobTrackerViews/studentUuid/%s/markAttendance", studentUuid), map[string]interface{}{"jobUuid": jobUuid, "isStudentAttended": true}},
		{"POST", "/app/jobTrackerViews/confirmAttendance", map[string]interface{}{"jobUuid": jobUuid, "studentUuid": studentUuid, "isStudentConfirmedToAttend": true}},
		{"POST", "/app/attendance/mark", map[string]interface{}{"studentUuid": studentUuid, "jobUuid": jobUuid, "attendance": "Attended"}},
		{"POST", "/app/attendance/confirm", map[string]interface{}{"studentUuid": studentUuid, "jobUuid": jobUuid, "isStudentConfirmedToAttend": true}},
		{"PUT", fmt.Sprintf("/app/jobTrackerViews/studentUuid/%s", studentUuid), map[string]interface{}{"jobUuid": jobUuid, "isStudentConfirmedToAttend": true}},
		{"POST", fmt.Sprintf("/app/jobTrackerViews/%s", studentUuid), []interface{}{}},
		{"POST", fmt.Sprintf("/app/jobTrackerViews/u/%s", studentUuid), []interface{}{}},
		{"POST", fmt.Sprintf("/app/jobTrackerViews/student/%s", studentUuid), []interface{}{}},
		{"POST", fmt.Sprintf("/app/studentViews/u/%s/attendance", studentUuid), []interface{}{}},
		{"POST", fmt.Sprintf("/app/studentViews/%s/attendance", studentUuid), []interface{}{}},
		{"POST", "/app/jobRoundAttendance", map[string]interface{}{"studentUuid": studentUuid, "jobUuid": jobUuid}},
		{"POST", fmt.Sprintf("/app/jobRoundAttendance/student/%s", studentUuid), []interface{}{}},
		{"POST", "/app/roundAttendance", map[string]interface{}{"studentUuid": studentUuid, "jobUuid": jobUuid}},
		{"POST", fmt.Sprintf("/app/roundAttendance/student/%s", studentUuid), []interface{}{}},
		{"POST", "/app/studentRoundAttendance", map[string]interface{}{"studentUuid": studentUuid, "jobUuid": jobUuid}},
		{"POST", fmt.Sprintf("/app/studentRoundAttendance/%s", studentUuid), []interface{}{}},
		{"POST", "/app/hiringWorkflowAttendance", map[string]interface{}{"studentUuid": studentUuid, "jobUuid": jobUuid}},
		{"POST", "/app/hiringWorkflow/attendance", map[string]interface{}{"studentUuid": studentUuid, "jobUuid": jobUuid}},
		{"POST", "/app/jobTrackerViews/attendance", map[string]interface{}{"studentUuid": studentUuid, "jobUuid": jobUuid}},
		{"POST", "/app/jobTrackerViews/mark", map[string]interface{}{"studentUuid": studentUuid, "jobUuid": jobUuid, "isStudentAttended": true}},
		{"POST", "/app/jobTrackerViews/confirm", map[string]interface{}{"studentUuid": studentUuid, "jobUuid": jobUuid, "isStudentConfirmedToAttend": true}},
	}

	for _, p := range probePaths {
		url := baseAPIURL + p.path
		raw, status, err := client.doRequest(p.method, url, p.body)
		bodyStr := ""
		if raw != nil {
			bodyStr = string(*raw)
			if len(bodyStr) > 500 {
				bodyStr = bodyStr[:500]
			}
		}
		if err != nil {
			bodyStr = fmt.Sprintf("error: %v | body: %s", err, bodyStr)
		}
		results = append(results, probeResult{Path: p.path, Method: p.method, Status: status, Body: bodyStr})
		fmt.Fprintf(os.Stderr, "[probe] %s %s => %d\n", p.method, p.path, status)
		time.Sleep(200 * time.Millisecond) // intentionally slow — this is a probing tool
	}

	merged, _ := json.Marshal(results)
	result := json.RawMessage(merged)
	return &result, nil
}
