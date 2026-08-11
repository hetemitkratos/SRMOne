package main

import (
	"encoding/base64"
	"encoding/json"
	"fmt"
	"net/url"
	"os"
	"strconv"
	"strings"
	"sync"
	"time"
)

const (
	modeLogin     = "login"
	modeFetch     = "fetch"
	modeVerifyMFA = "verify_mfa"
	modeSendMFA   = "send_mfa"
	modeLogout    = "logout"
	modeJD        = "jd"
	modeApply     = "apply"
)

func main() {
	var req ScraperRequest
	if err := json.NewDecoder(os.Stdin).Decode(&req); err != nil {
		writeResponse(ScraperResponse{
			Error: fmt.Sprintf("could not decode stdin JSON: %v", err),
		})
		os.Exit(1)
	}

	mode := strings.ToLower(strings.TrimSpace(req.Mode))
	if mode == "" {
		mode = modeLogin
	}

	var resp ScraperResponse

	switch mode {
	case modeLogin:
		resp = handleLogin(req)
	case modeFetch:
		resp = handleFetch(req)
	case modeVerifyMFA:
		resp = handleVerifyMFA(req)
	case modeSendMFA:
		resp = handleSendMFA(req)
	case modeLogout:
		resp = handleLogout(req)
	case modeJD:
		resp = handleJD(req)
	case modeApply:
		resp = handleApply(req)
	default:
		resp = ScraperResponse{Error: fmt.Sprintf("unknown mode: %s", mode)}
	}

	writeResponse(resp)
	if !resp.Success {
		os.Exit(1)
	}
}

func handleLogin(req ScraperRequest) ScraperResponse {
	if req.Username == "" || req.Password == "" {
		return ScraperResponse{Error: "username and password are required"}
	}

	client := newFHClient()
	loginResp, err := login(client, req.Username, req.Password)
	if err != nil {
		return ScraperResponse{Error: fmt.Sprintf("login failed: %v", err)}
	}

	if loginResp.RequiresTotp && loginResp.MFAToken != "" {
		return ScraperResponse{
			Success:     true,
			RequiresMFA: true,
			MFAToken:    loginResp.MFAToken,
			PublicURL:   loginResp.PublicURL,
		}
	}

	if loginResp.Token == "" {
		return ScraperResponse{Error: "login succeeded but no token returned"}
	}

	sub, err := extractSubFromJWT(loginResp.Token)
	if err != nil {
		return ScraperResponse{Error: fmt.Sprintf("extract sub from JWT: %v", err)}
	}

	ts, err := extractTSFromJWT(loginResp.Token)
	if err != nil {
		return ScraperResponse{Error: fmt.Sprintf("extract ts from JWT: %v", err)}
	}
	phaveloc := time.Now().Unix() - ts
	encryptedToken := encryptToken(loginResp.Token)
	uuid, _ := extractUUIDFromJWT(loginResp.Token)

	return ScraperResponse{
		Success:        true,
		Token:          loginResp.Token,
		EncryptedToken: encryptedToken,
		Sub:            sub,
		UUID:           uuid,
		Phaveloc:       phaveloc,
		PublicURL:      loginResp.PublicURL,
	}
}

func handleVerifyMFA(req ScraperRequest) ScraperResponse {
	if req.MFAToken == "" {
		return ScraperResponse{Error: "mfaToken is required"}
	}
	if req.TOTPCode == "" && req.EmailOTP == "" {
		return ScraperResponse{Error: "totpCode or emailOtp is required"}
	}

	client := newFHClient()
	resp, err := verifyTOTP(client, req.MFAToken, req.TOTPCode, req.EmailOTP)
	if err != nil {
		return ScraperResponse{Error: fmt.Sprintf("MFA verification failed: %v", err)}
	}

	if resp.Token == "" {
		return ScraperResponse{Error: "MFA verification succeeded but no token returned"}
	}

	sub, err := extractSubFromJWT(resp.Token)
	if err != nil {
		return ScraperResponse{Error: fmt.Sprintf("extract sub from JWT: %v", err)}
	}

	ts, err := extractTSFromJWT(resp.Token)
	if err != nil {
		return ScraperResponse{Error: fmt.Sprintf("extract ts from JWT: %v", err)}
	}
	phaveloc := time.Now().Unix() - ts
	encryptedToken := encryptToken(resp.Token)
	uuid, _ := extractUUIDFromJWT(resp.Token)

	return ScraperResponse{
		Success:        true,
		Token:          resp.Token,
		EncryptedToken: encryptedToken,
		Sub:            sub,
		UUID:           uuid,
		Phaveloc:       phaveloc,
		PublicURL:      resp.PublicURL,
	}
}

func handleSendMFA(req ScraperRequest) ScraperResponse {
	if req.MFAToken == "" {
		return ScraperResponse{Error: "mfaToken is required"}
	}

	client := newFHClient()
	if err := sendMFAPrompt(client, req.MFAToken); err != nil {
		return ScraperResponse{Error: fmt.Sprintf("send MFA email failed: %v", err)}
	}

	return ScraperResponse{Success: true}
}

// handleFetch fetches all requested sections in parallel (no sleep between sections).
func handleFetch(req ScraperRequest) ScraperResponse {
	if req.Token == "" {
		return ScraperResponse{Error: "token is required for fetch mode"}
	}
	if len(req.Sections) == 0 {
		return ScraperResponse{Error: "at least one section is required"}
	}

	client := newFHClient()
	if err := client.setAuth(req.Token, req.Phaveloc); err != nil {
		return ScraperResponse{Error: fmt.Sprintf("set auth: %v", err)}
	}

	// Fetch all sections in parallel
	type sectionResult struct {
		name string
		data *json.RawMessage
		err  error
	}

	results := make([]sectionResult, len(req.Sections))
	var wg sync.WaitGroup

	for i, section := range req.Sections {
		wg.Add(1)
		go func(idx int, sectionName string) {
			defer wg.Done()
			data, err := fetchSection(client, sectionName, req)
			results[idx] = sectionResult{name: sectionName, data: data, err: err}
		}(i, section)
	}
	wg.Wait()

	sections := make(map[string]*json.RawMessage, len(results))
	for _, res := range results {
		if res.err != nil {
			errMsg := fmt.Sprintf("fetch %s: %v", res.name, res.err)
			errJSON := json.RawMessage(fmt.Sprintf(`{"error":"%s"}`, escapeJSON(errMsg)))
			sections[res.name] = &errJSON
			continue
		}
		sections[res.name] = res.data
	}

	return ScraperResponse{
		Success:  true,
		Sections: sections,
	}
}

func handleLogout(req ScraperRequest) ScraperResponse {
	if req.Token == "" {
		return ScraperResponse{Success: true}
	}

	client := newFHClient()
	if err := client.setAuth(req.Token, req.Phaveloc); err != nil {
		return ScraperResponse{Success: true}
	}
	_ = signOut(client)

	return ScraperResponse{Success: true}
}

func handleJD(req ScraperRequest) ScraperResponse {
	if req.Token == "" {
		return ScraperResponse{Error: "token is required"}
	}
	if req.FileURL == "" && req.JobUUID == "" {
		return ScraperResponse{Error: "fileUrl or jobUuid is required"}
	}

	// Extract jobUUID from downloadJobForm URL if not explicitly provided
	jobUUID := req.JobUUID
	if jobUUID == "" && strings.Contains(req.FileURL, "downloadJobForm/jobUuid/") {
		parts := strings.Split(req.FileURL, "downloadJobForm/jobUuid/")
		if len(parts) > 1 {
			jobUUID = strings.TrimSpace(parts[len(parts)-1])
		}
	}

	client := newFHClient()
	if err := client.setAuth(req.Token, req.Phaveloc); err != nil {
		return ScraperResponse{Error: fmt.Sprintf("set auth: %v", err)}
	}

	body, contentType, err := fetchJD(client, req.FileURL, jobUUID)
	if err != nil {
		return ScraperResponse{Error: fmt.Sprintf("fetch JD: %v", err)}
	}

	fileName := "attachment"
	if req.FileURL != "" {
		parts := strings.Split(req.FileURL, "/")
		if len(parts) > 0 {
			fileName = parts[len(parts)-1]
		}
	}
	if strings.Contains(contentType, "pdf") && !strings.HasSuffix(fileName, ".pdf") {
		fileName += ".pdf"
	}

	return ScraperResponse{
		Success:     true,
		FileData:    base64.StdEncoding.EncodeToString(body),
		FileName:    fileName,
		ContentType: contentType,
	}
}

func handleApply(req ScraperRequest) ScraperResponse {
	if req.Token == "" {
		return ScraperResponse{Error: "token is required"}
	}
	if req.JobUUID == "" {
		return ScraperResponse{Error: "jobUuid is required"}
	}
	if req.ResumeName == "" {
		return ScraperResponse{Error: "resumeName is required"}
	}

	client := newFHClient()
	if err := client.setAuth(req.Token, req.Phaveloc); err != nil {
		return ScraperResponse{Error: fmt.Sprintf("set auth: %v", err)}
	}

	jobIDInt := 0
	if req.JobID != nil {
		switch v := req.JobID.(type) {
		case float64:
			jobIDInt = int(v)
		case string:
			if parsed, err := strconv.Atoi(v); err == nil {
				jobIDInt = parsed
			}
		}
	}

	raw, status, err := applyForJob(client, req.JobUUID, jobIDInt, req.ApplyAnswers, req.ResumeName)
	if err != nil {
		errMsg := fmt.Sprintf("apply failed: %v", err)
		if status == 400 || status == 409 {
			if raw != nil {
				var errBody struct {
					Message string `json:"message"`
					Error   string `json:"error"`
				}
				if jsonErr := json.Unmarshal(*raw, &errBody); jsonErr == nil && (errBody.Message != "" || errBody.Error != "") {
					errMsg = errBody.Message + " " + errBody.Error
					errMsg = strings.TrimSpace(errMsg)
				}
			}
		}
		return ScraperResponse{Error: errMsg}
	}

	return ScraperResponse{
		Success: true,
		Data:    raw,
	}
}

func writeResponse(resp ScraperResponse) {
	data, _ := json.Marshal(resp)
	fmt.Fprint(os.Stdout, string(data))
}

func escapeJSON(s string) string {
	b, _ := json.Marshal(s)
	return string(b[1 : len(b)-1])
}

func parseURL(rawURL string) *url.URL {
	u, err := url.Parse(rawURL)
	if err != nil {
		return &url.URL{}
	}
	return u
}
