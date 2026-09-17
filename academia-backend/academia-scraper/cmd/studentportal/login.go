package main

import (
	"encoding/base64"
	"fmt"
	"net/url"
	"os"
	"regexp"
	"strings"
	"time"

	"github.com/PuerkitoBio/goquery"
)

const (
	spLoginURL      = spBaseURL + "/srmiststudentportal/students/loginManager/youLogin.jsp"
	spLoginPostURL  = spBaseURL + "/srmiststudentportal/LoginServlet"
	spAttendanceURL = spBaseURL + "/srmiststudentportal/students/report/studentAttendanceDetails.jsp"
	spDashboardURL  = spBaseURL + "/srmiststudentportal/students/template/HRDSystem.jsp"
)

// ---------------------------------------------------------------------------
// Login flow
// ---------------------------------------------------------------------------

// spSecureConfig holds the dynamic values extracted from the login page's
// window.SECURE_CONFIG JavaScript object.
type spSecureConfig struct {
	CaptchaText      string
	CaptchaFieldName string // gets btoa(timeElapsed + delimiter + interactCount)
	DomainFieldName  string // gets btoa(reversedHostname)
	RandomDelimiter  string
	ChallengeID      string
	FpNonce          string
	Nonce            string
}

var (
	reCaptchaText  = regexp.MustCompile(`SECURE_CONFIG\.captchaText\s*=\s*'([^']+)'`)
	reCaptchaField = regexp.MustCompile(`SECURE_CONFIG\.captchaFieldName\s*=\s*'([^']+)'`)
	reDomainField  = regexp.MustCompile(`SECURE_CONFIG\.domainFieldName\s*=\s*'([^']+)'`)
	reDelimiter    = regexp.MustCompile(`SECURE_CONFIG\.randomDelimiter\s*=\s*'([^']+)'`)
	reChallengeID  = regexp.MustCompile(`id="challengeId"\s+value="([^"]+)"`)
	reFpNonce      = regexp.MustCompile(`id="fpNonce"\s+value="([^"]+)"`)
	reNonce        = regexp.MustCompile(`nonce\s*:\s*'([^']+)'`)
)

// spLoginContext carries everything needed to submit the login form: the
// parsed SECURE_CONFIG, honeypot field names, when the page was fetched, and
// the raw captcha image. It is what gets returned to the backend (as
// SPPendingLogin) when the user has to solve the captcha manually.
type spLoginContext struct {
	Config        spSecureConfig
	HoneypotNames []string
	PageLoadMs    int64
	CaptchaImage  []byte
}

func (c *spLoginContext) pending() *SPPendingLogin {
	return &SPPendingLogin{
		CaptchaFieldName: c.Config.CaptchaFieldName,
		DomainFieldName:  c.Config.DomainFieldName,
		RandomDelimiter:  c.Config.RandomDelimiter,
		PageLoadMs:       c.PageLoadMs,
		HoneypotNames:    c.HoneypotNames,
	}
}

// spLogin runs the automatic login flow. When the captcha image is fetched but
// cannot be solved automatically, it returns the context so the caller can
// surface a captcha_needed response for manual solving.
func spLogin(client *SPClient, email, password, captchaAPIKey, captchaAPIURL string) (SPRequestSnapshot, *spLoginContext, error) {
	ctx, err := spPrepareLogin(client)
	if err != nil {
		return SPRequestSnapshot{}, nil, err
	}

	solvedCaptcha, err := solveCaptcha2Captcha(captchaAPIKey, captchaAPIURL, ctx.CaptchaImage)
	if err != nil {
		return SPRequestSnapshot{}, ctx, fmt.Errorf("captcha solve failed: %w", err)
	}
	fmt.Fprintf(os.Stderr, "[spLogin] captcha solved: %s\n", solvedCaptcha)

	snap, err := spSubmitLogin(client, ctx, email, password, solvedCaptcha)
	return snap, nil, err
}

// spPrepareLogin fetches the login page, parses SECURE_CONFIG + honeypot
// fields, and downloads the captcha image. No form POST is made, so this
// does not consume a login attempt.
func spPrepareLogin(client *SPClient) (*spLoginContext, error) {
	// Step 1: GET login page to establish session cookies
	loginPageResp, err := client.DoRequest("GET", spLoginURL, nil, "", nil, true)
	if err != nil {
		return nil, fmt.Errorf("could not fetch login page: %w", err)
	}

	html := string(loginPageResp.Body)
	pageLoadTime := time.Now()

	// Step 2: Extract SECURE_CONFIG values from the HTML
	config := parseSPSecureConfig(html)
	if config.CaptchaText == "" {
		return nil, fmt.Errorf("could not extract captchaText from login page")
	}

	fmt.Fprintf(os.Stderr, "[spLogin] captchaText=%s captchaField=%s domainField=%s delimiter=%s\n",
		config.CaptchaText, config.CaptchaFieldName, config.DomainFieldName, config.RandomDelimiter)

	// Step 2.5: Parse HTML with goquery for honeypot fields and captcha image src
	doc, err := goquery.NewDocumentFromReader(strings.NewReader(html))
	if err != nil {
		return nil, fmt.Errorf("could not parse login page HTML: %w", err)
	}

	var honeypotNames []string
	doc.Find("input[name^=ph_]").Each(func(_ int, s *goquery.Selection) {
		if name, ok := s.Attr("name"); ok {
			honeypotNames = append(honeypotNames, name)
		}
	})

	// Step 2.6: Fetch captcha image from SCaptchaServlet with X-Domain-Proof header.
	// captchaText in SECURE_CONFIG is a DECOY — only used when domain is unsafe (phishing).
	// When domain is safe, guardlogin.js fetches the real captcha from SCaptchaServlet.
	// The user must read the image and type the answer. We solve it via 2Captcha or manual fallback.
	captchaImgSrc, _ := doc.Find("img#secure_captcha").Attr("data-src")
	if captchaImgSrc == "" {
		return nil, fmt.Errorf("no captcha image data-src found on login page")
	}

	captchaImgURL := captchaImgSrc
	if strings.HasPrefix(captchaImgSrc, "/") {
		captchaImgURL = spBaseURL + captchaImgSrc
	}
	domainProof := base64.StdEncoding.EncodeToString([]byte(config.Nonce + ":sp.srmist.edu.in"))
	fmt.Fprintf(os.Stderr, "[spLogin] fetching captcha image from %s (nonce=%s)\n", captchaImgURL, config.Nonce)
	captchaImgResp, err := client.DoRequest("GET", captchaImgURL, nil, "", map[string]string{
		"Referer":        spLoginURL,
		"Accept":         "image/png, image/jpeg, image/svg+xml, image/*",
		"X-Domain-Proof": domainProof,
	}, false)
	if err != nil {
		return nil, fmt.Errorf("captcha image fetch failed: %w", err)
	}
	fmt.Fprintf(os.Stderr, "[spLogin] captcha image fetched: status=%d bytes=%d\n",
		captchaImgResp.StatusCode, len(captchaImgResp.Body))
	_ = os.WriteFile("sp_captcha.png", captchaImgResp.Body, 0644)

	return &spLoginContext{
		Config:        config,
		HoneypotNames: honeypotNames,
		PageLoadMs:    pageLoadTime.UnixMilli(),
		CaptchaImage:  captchaImgResp.Body,
	}, nil
}

// spSubmitLogin POSTs the login form with a known captcha answer. This is the
// only step that consumes a login attempt.
func spSubmitLogin(client *SPClient, ctx *spLoginContext, email, password, solvedCaptcha string) (SPRequestSnapshot, error) {
	config := ctx.Config
	pageLoadTime := time.UnixMilli(ctx.PageLoadMs)

	// Step 4: Build form payload
	netID := strings.TrimSpace(email)
	if strings.Contains(netID, "@") {
		netID = strings.Split(netID, "@")[0]
	}

	// fpPayload and fpToken are empty hidden inputs — no JS populates them.
	// secure2.js only adds telemetryPayload. guardlogin.js/guardloginbottom.js
	// only add cptoken_*/dtoken_* fields. So these must be empty.
	fpPayload := ""
	fpToken := ""

	// telemetryPayload = base64(JSON.stringify(telemetry)) from secure2.js
	// The telemetry object has full field names, NOT short keys.
	// safeBase64Encode in JS = btoa(UTF8 bytes) = standard base64 in Go.
	now := time.Now()
	startTime := now.Add(-5 * time.Second).UnixMilli()
	submitTime := now.UnixMilli()
	telemetryJSON := fmt.Sprintf(`{"startTime":%d,"currentDomain":"sp.srmist.edu.in","timezoneOffset":-330,"screenWidth":1920,"screenHeight":1080,"colorDepth":24,"devicePixelRatio":1,"platform":"Win32","userAgent":"%s","language":"en-US","hardwareConcurrency":8,"deviceMemory":8,"touchSupport":false,"webdriver":false,"mouseClicks":1,"mouseMovements":5,"keystrokeCount":10,"typingSpeedMs":5000,"canvasHash":"a1b2c3d4e5f6","submitTime":%d,"timeOnPageMs":5000}`,
		startTime, spUserAgent, submitTime)
	telemetryPayload := base64.StdEncoding.EncodeToString([]byte(telemetryJSON))

	// Build form body in DOM order (NOT alphabetical) to match browser exactly:
	// username, password, ph_*, captcha, fpPayload, fpToken, telemetryPayload, dtoken, cptoken, dtoken
	var formParts []string
	formParts = append(formParts, "username="+url.QueryEscape(netID))
	formParts = append(formParts, "password="+url.QueryEscape(password))

	// Honeypot fields — must be empty
	for _, name := range ctx.HoneypotNames {
		formParts = append(formParts, url.QueryEscape(name)+"=")
	}

	formParts = append(formParts, "captcha="+url.QueryEscape(solvedCaptcha))
	formParts = append(formParts, "fpPayload="+url.QueryEscape(fpPayload))
	formParts = append(formParts, "fpToken="+url.QueryEscape(fpToken))
	formParts = append(formParts, "telemetryPayload="+url.QueryEscape(telemetryPayload))

	// Dynamic security tokens added by guardlogin.js + guardloginbottom.js on form submit:
	// dtoken_* (domainFieldName) → btoa(reversedHostname)  [added by BOTH scripts, so duplicate]
	// cptoken_* (captchaFieldName) → btoa(timeElapsed + randomDelimiter + interactCount)
	if config.DomainFieldName != "" {
		reversedHost := reverseString("sp.srmist.edu.in")
		encodedHost := base64.StdEncoding.EncodeToString([]byte(reversedHost))
		formParts = append(formParts, url.QueryEscape(config.DomainFieldName)+"="+url.QueryEscape(encodedHost)) // guardloginbottom.js
	}
	if config.CaptchaFieldName != "" {
		timeElapsed := int(time.Since(pageLoadTime).Seconds())
		if timeElapsed < 3 {
			timeElapsed = 3 + int(config.RandomDelimiter[0])%10
		}
		interactCount := 5 + timeElapsed%10
		trapPayload := fmt.Sprintf("%d%s%d", timeElapsed, config.RandomDelimiter, interactCount)
		formParts = append(formParts, url.QueryEscape(config.CaptchaFieldName)+"="+url.QueryEscape(base64.StdEncoding.EncodeToString([]byte(trapPayload))))
	}
	if config.DomainFieldName != "" {
		reversedHost := reverseString("sp.srmist.edu.in")
		encodedHost := base64.StdEncoding.EncodeToString([]byte(reversedHost))
		formParts = append(formParts, url.QueryEscape(config.DomainFieldName)+"="+url.QueryEscape(encodedHost)) // guardlogin.js (duplicate)
	}

	body := []byte(strings.Join(formParts, "&"))

	fmt.Fprintf(os.Stderr, "[spLogin] form body: %s\n", string(body))
	fmt.Fprintf(os.Stderr, "[spLogin] posting to %s with %d fields\n", spLoginPostURL, len(formParts))
	fmt.Fprintf(os.Stderr, "[spLogin] cookies: %s\n", client.jar.CookieHeader())

	loginResp, err := client.DoRequest("POST", spLoginPostURL, body, "application/x-www-form-urlencoded", map[string]string{
		"Referer":                   spLoginURL,
		"Origin":                    spBaseURL,
		"Accept":                    "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7",
		"Accept-Language":           "en-US,en;q=0.9",
		"Upgrade-Insecure-Requests": "1",
		"Sec-Fetch-Dest":            "document",
		"Sec-Fetch-Mode":            "navigate",
		"Sec-Fetch-Site":            "same-origin",
		"Sec-Fetch-User":            "?1",
	}, true)
	if err != nil {
		return loginResp, fmt.Errorf("login form submission failed: %w", err)
	}

	fmt.Fprintf(os.Stderr, "[spLogin] post-login URL=%s status=%d hasJSESSIONID=%v bodyLen=%d\n",
		loginResp.URL, loginResp.StatusCode, client.jar.HasCookie("JSESSIONID"), len(loginResp.Body))

	// Debug: log first 500 chars of response body to diagnose failure
	bodyPreview := string(loginResp.Body)
	if len(bodyPreview) > 500 {
		bodyPreview = bodyPreview[:500]
	}
	fmt.Fprintf(os.Stderr, "[spLogin] response preview: %s\n", bodyPreview)
	_ = os.WriteFile("sp_login_response.html", loginResp.Body, 0644)

	if isSPLoginFailed(loginResp.Body, loginResp.URL) {
		return loginResp, fmt.Errorf("login failed: invalid credentials or captcha")
	}

	return loginResp, nil
}

func parseSPSecureConfig(html string) spSecureConfig {
	config := spSecureConfig{}
	if m := reCaptchaText.FindStringSubmatch(html); len(m) > 1 {
		config.CaptchaText = m[1]
	}
	if m := reCaptchaField.FindStringSubmatch(html); len(m) > 1 {
		config.CaptchaFieldName = m[1]
	}
	if m := reDomainField.FindStringSubmatch(html); len(m) > 1 {
		config.DomainFieldName = m[1]
	}
	if m := reDelimiter.FindStringSubmatch(html); len(m) > 1 {
		config.RandomDelimiter = m[1]
	}
	if m := reNonce.FindStringSubmatch(html); len(m) > 1 {
		config.Nonce = m[1]
	}
	if m := reChallengeID.FindStringSubmatch(html); len(m) > 1 {
		config.ChallengeID = m[1]
	}
	if m := reFpNonce.FindStringSubmatch(html); len(m) > 1 {
		config.FpNonce = m[1]
	}
	return config
}

func reverseString(s string) string {
	runes := []rune(s)
	for i, j := 0, len(runes)-1; i < j; i, j = i+1, j-1 {
		runes[i], runes[j] = runes[j], runes[i]
	}
	return string(runes)
}

// ---------------------------------------------------------------------------
// Login validation
// ---------------------------------------------------------------------------

func isSPLoginFailed(body []byte, finalURL string) bool {
	lower := strings.ToLower(string(body))
	location := strings.ToLower(finalURL)

	// Check for explicit error alert div — server returns login page on both success and failure,
	// but only includes the alert-danger div when credentials/captcha are wrong
	if strings.Contains(lower, "alert-danger") &&
		(strings.Contains(lower, "invalid credentials") ||
			strings.Contains(lower, "invalid captcha") ||
			strings.Contains(lower, "enter valid captcha") ||
			strings.Contains(lower, "login failed") ||
			strings.Contains(lower, "incorrect password") ||
			strings.Contains(lower, "account locked")) {
		return true
	}

	// Check if redirected to login page explicitly (not just login page content in response)
	if strings.Contains(location, "youlogin.jsp") &&
		strings.Contains(lower, "alert-danger") {
		return true
	}

	return false
}

// ---------------------------------------------------------------------------
// Post-login: fetch attendance and student info
// ---------------------------------------------------------------------------

// spFetchAttendance fetches attendance directly from the known attendance URL.
// No discovery, no frames, no funSetFormId — just one POST request.
func spFetchAttendance(client *SPClient, postLoginURL string) ([]SPAttendanceRecord, SPStudentInfo, error) {
	// Step 1: GET dashboard to establish authenticated session context
	// The SP server requires visiting the dashboard before accessing attendance
	_, err := client.DoRequest("GET", spDashboardURL, nil, "", map[string]string{
		"Referer": spLoginURL,
	}, true)
	if err != nil {
		fmt.Fprintf(os.Stderr, "[spFetchAttendance] dashboard GET error: %v\n", err)
	} else {
		fmt.Fprintf(os.Stderr, "[spFetchAttendance] dashboard GET ok\n")
	}

	// Debug: save dashboard response
	dashResp, err := client.DoRequest("GET", spDashboardURL, nil, "", map[string]string{
		"Referer": spLoginURL,
	}, true)
	if err == nil {
		_ = os.WriteFile("sp_dashboard_response.html", dashResp.Body, 0644)
		fmt.Fprintf(os.Stderr, "[spFetchAttendance] dashboard URL=%s status=%d bodyLen=%d\n",
			dashResp.URL, dashResp.StatusCode, len(dashResp.Body))
	}

	// Step 2: POST attendance request with ClassPro form body
	attBody := []byte("iden=9&filter=&hdnFormDetails=1&csrfPreventionSalt=")
	attResp, err := client.DoRequest("POST", spAttendanceURL, attBody, "application/x-www-form-urlencoded", map[string]string{
		"Referer":          spDashboardURL,
		"X-Requested-With": "XMLHttpRequest",
	}, true)
	if err != nil {
		return nil, SPStudentInfo{}, fmt.Errorf("attendance page request failed: %w", err)
	}

	fmt.Fprintf(os.Stderr, "[spFetchAttendance] URL=%s status=%d body_len=%d\n",
		attResp.URL, attResp.StatusCode, len(attResp.Body))
	_ = os.WriteFile("sp_attendance_response.html", attResp.Body, 0644)

	records := parseSPAttendance(attResp.Body)
	studentInfo := parseSPStudentInfo(attResp.Body)

	if len(records) == 0 {
		return nil, studentInfo, fmt.Errorf("no attendance records found")
	}

	fmt.Fprintf(os.Stderr, "[spFetchAttendance] parsed %d records, student=%s\n", len(records), studentInfo.Name)
	return records, studentInfo, nil
}
